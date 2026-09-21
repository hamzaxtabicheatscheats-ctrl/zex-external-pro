import string
import random
#!/usr/bin/env python3
"""
╔══════════════════════════════════════════════════════╗
║     ZEX INJECTION — VPS Server + Telegram Bot        ║
║   Flask API + Bot — sab kuch VPS pe, no GitHub       ║
╚══════════════════════════════════════════════════════╝
Run: python3 server.py
"""

import os, sys, json, shutil, threading, logging
from pathlib import Path
from flask import Flask, jsonify, send_from_directory, abort, request
from dotenv import load_dotenv
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import (
    Application, CommandHandler, CallbackQueryHandler,
    MessageHandler, ConversationHandler, ContextTypes, filters
)

load_dotenv()
logging.basicConfig(format="%(asctime)s %(levelname)s %(message)s", level=logging.INFO)
log = logging.getLogger(__name__)

# ── Settings ──────────────────────────────────────────────────────
PORT      = int(os.getenv("PORT", "9001"))
BOT_TOKEN = os.getenv("BOT_TOKEN", "")
ADMIN_IDS = {6433997955, 8046060095}
VPS_URL   = os.getenv("VPS_URL","http://localhost:8888").rstrip("/")

# ── Paths ─────────────────────────────────────────────────────────
BASE  = Path(__file__).parent
SLOTS = BASE / "slot_files"
CFGF  = BASE / "config.json"
KEYSF = BASE / "keys.json"

# ── Init folders ──────────────────────────────────────────────────
SLOTS.mkdir(exist_ok=True)
for i in range(1,5): (SLOTS / f"option{i}").mkdir(parents=True, exist_ok=True)

def init_files():
    if not CFGF.exists():
        CFGF.write_text(json.dumps({
            "version": "1.0",
            "telegram": "https://t.me/zexinjector",
            "typeA": {"name": "Type A", "mcmFolder": "[MHA-C2] App Data"},
            "typeB": {"name": "Type B", "mcmFolder": "[MHA-C12] System Data"},
            "option1Name": "OPTION 1",
            "option2Name": "OPTION 2",
            "option3Name": "OPTION 3",
            "option4Name": "EXTRA",
            "option1Slots": [],
            "option2Slots": [],
            "option3Slots": [],
            "option4Slots": []
        }, indent=2))
    if not KEYSF.exists():
        KEYSF.write_text(json.dumps({"keys": ["ZEX-MASTER-9999-ROOT"]}, indent=2))

init_files()

# ── Config helpers ────────────────────────────────────────────────
def lcfg():
    c = json.loads(CFGF.read_text())
    if "option4Slots" not in c: c["option4Slots"] = []
    if "option4Name" not in c: c["option4Name"] = "EXTRA"
    return c
def scfg(c): CFGF.write_text(json.dumps(c, indent=2, ensure_ascii=False))
def gen_key():
    c=string.ascii_uppercase+string.digits
    return "ZEX-"+"".join(random.choices(c,k=4))+"-"+"".join(random.choices(c,k=4))+"-"+"".join(random.choices(c,k=4))

DURATIONS={"1h":("1 Hour",3600),"30d":("30 Days",30*86400),"60d":("60 Days",60*86400),"90d":("90 Days",90*86400),"perm":("Permanent",0)}

def lkeys(): return json.loads(KEYSF.read_text())
def skeys(k): KEYSF.write_text(json.dumps(k, indent=2))

def slot_dir(opt, sid):
    p = SLOTS / f"option{opt}" / str(sid)
    p.mkdir(parents=True, exist_ok=True)
    return p

def file_url(opt, sid, fname):
    return f"{VPS_URL}/slots/option{opt}/{sid}/{fname}"

def next_id(slots):
    return max((s["id"] for s in slots), default=0) + 1

def slot_info_text(slot, opt):
    folder = SLOTS / f"option{opt}" / str(slot["id"])
    files  = list(folder.glob("*")) if folder.exists() else []
    names  = ", ".join(f.name for f in files) if files else "_(empty)_"
    return (f"`[{slot['id']}]` *{slot['name']}*\n"
            f"Desc: `{slot.get('description','')}`\n"
            f"Type: `{slot.get('type','A')}`\n"
            f"Files: `{names}`")

# ══════════════════════════════════════════════════════════════════
# FLASK API
# ══════════════════════════════════════════════════════════════════
web = Flask(__name__)
logging.getLogger("werkzeug").setLevel(logging.WARNING)

@web.route("/config")
def api_config():
    return web.response_class(
        response=CFGF.read_text(),
        status=200, mimetype="application/json")

@web.route("/keys")
def api_keys():
    return web.response_class(
        response=KEYSF.read_text(),
        status=200, mimetype="application/json")



@web.route("/health")
def health(): return jsonify({"status":"ok","url":VPS_URL,"port":PORT})

@web.route("/restore/<int:num>")
def serve_restore(num):
    """Serve original/restore file for remove button"""
    folder = RESTORE / f"restore{num}"
    if not folder.exists(): abort(404)
    files = [f for f in folder.iterdir() if f.is_file()]
    if not files: abort(404)
    f = files[0]
    resp = send_from_directory(str(folder), f.name, mimetype="application/octet-stream")
    resp.headers["X-File-Name"] = f.name
    return resp

@web.route("/slot-file/<int:opt>/<int:sid>")
def auto_pickup(opt, sid):
    """Auto pickup — first file from slot folder, no URL needed!"""
    folder = SLOTS / opt / str(sid)
    if not folder.exists(): abort(404)
    files = [f for f in folder.iterdir() if f.is_file()]
    if not files: abort(404)
    pick = files[0]
    resp = send_from_directory(str(folder), pick.name, mimetype="application/octet-stream")
    resp.headers["X-File-Name"] = pick.name
    return resp


@web.route("/slots/<opt>/<sid>/<path:filename>")
@web.route("/get/<opt>/<sid>/<path:filename>")
def serve_file(opt, sid, filename):
    """Serve slot file — exact binary, no modification"""
    folder = SLOTS / opt / str(sid)
    if not folder.exists(): abort(404)
    return send_from_directory(str(folder), filename,
                               mimetype="application/octet-stream")

@web.route("/verify")
def verify_key():
    import time as _time
    key    = request.args.get("key","").upper().strip()
    device = request.args.get("device","unknown").strip()
    kd = lkeys()
    keys = kd.get("keys",{})
    # Master key always valid
    if key == "ZEX-MASTER-9999-ROOT":
        return jsonify({"valid":True,"expires_in":-1})
    if key not in keys:
        return jsonify({"valid":False,"reason":"Invalid key"})
    kdata = keys[key]
    # Check expiry
    expires = kdata.get("expires",0)
    if expires and _time.time() > expires:
        return jsonify({"valid":False,"reason":"Key expired"})
    # Check device binding
    bound = kdata.get("device","")
    if bound and bound != device:
        return jsonify({"valid":False,"reason":"Key already in use on another device"})
    # Bind device
    if not bound:
        kdata["device"] = device
        skeys(kd)
    expires_in = max(0, expires - _time.time()) if expires else -1
    return jsonify({"valid":True,"expires_in":int(expires_in)})

@web.route("/unbind")
def unbind_key():
    key = request.args.get("key","").upper()
    kd  = lkeys()
    if key in kd.get("keys",{}):
        kd["keys"][key]["device"] = ""
        skeys(kd)
    return jsonify({"ok":True})

def run_web():
    web.run(host="0.0.0.0", port=PORT, debug=False, use_reloader=False)

# ══════════════════════════════════════════════════════════════════
# TELEGRAM BOT
# ══════════════════════════════════════════════════════════════════
def IK(t, d): return InlineKeyboardButton(t, callback_data=d)
def KM(rows): return InlineKeyboardMarkup(rows)
def kb_back(to="back"): return KM([[IK("🔙 Back", to)]])

def is_admin(uid): return not ADMIN_IDS or uid in ADMIN_IDS

# States
(MAIN, KEY_ADD, SL_TYPE, SL_NAME, SL_DESC,
 EDIT_NAME, EDIT_DESC, EDIT_URL, EDIT_TYPE, EDIT_PATH,
 FILE_UP, PHOTO_UP, CFG_VAL) = range(13)

# ── Keyboards ─────────────────────────────────────────────────────
def kb_main():
    return KM([
        [IK("🔑 Keys",      "keys"),   IK("📦 Option 1", "sl:1")],
        [IK("📦 Option 2",  "sl:2"),   IK("📦 Option 3", "sl:3")],
        [IK("📦 Option 4 (EXTRA)", "sl:4"), IK("⚙️ Config", "cfg")],
        [IK("📊 Status",   "status")],
    ])

def kb_keys():
    return KM([
        [IK("🔑 Generate Key","key:gen"),  IK("🗑 Remove Key","key:del")],
        [IK("List Keys",  "key:list"),  IK("🔓 Unbind Key","key:unbind")],
        [IK("🔙 Back","back")],
    ])

def kb_duration():
    return KM([
        [IK("1 Hour","dur:1h"),    IK("30 Days","dur:30d")],
        [IK("60 Days","dur:60d"),  IK("90 Days","dur:90d")],
        [IK("Permanent","dur:perm")],
        [IK("Back","keys")],
    ])

def kb_opt(opt):
    return KM([
        [IK("➕ New Slot",   f"sl:new:{opt}"),    IK("📋 List Slots", f"sl:list:{opt}")],
        [IK("✏️ Edit Slot",  f"sl:edit:{opt}"),   IK("🗑 Del Slot",   f"sl:del:{opt}")],
        [IK("📤 Upload File",f"sl:upload:{opt}"),  IK("🖼 Upload Photo",f"sl:photo:{opt}")],
        [IK("🔙 Back",       "back")],
    ])

def kb_slot_list(opt, action):
    cfg = lcfg(); slots = cfg.get(f"option{opt}Slots", [])
    rows = []
    for i in range(0, len(slots), 2):
        row = [IK(f"[{s['id']}] {s['name'][:14]}", f"{action}:{opt}:{s['id']}")
               for s in slots[i:i+2]]
        rows.append(row)
    rows.append([IK("🔙 Back", f"sl:{opt}")])
    return KM(rows)

def kb_edit(opt, sid):
    return KM([
        [IK("Name",      f"e:name:{opt}:{sid}"),  IK("Desc",     f"e:desc:{opt}:{sid}")],
        [IK("FFTH Path", f"e:ffth:{opt}:{sid}"),  IK("FFMAX Path",f"e:ffmax:{opt}:{sid}")],
        [IK("Upload File",f"e:file:{opt}:{sid}"), IK("Photo",    f"e:photo:{opt}:{sid}")],
        [IK("🔄 Rotate Photo", f"e:rot:{opt}:{sid}"), IK("Rename", f"e:rename:{opt}:{sid}")],
        [IK("Delete",    f"e:del:{opt}:{sid}"),   IK("Back",      f"sl:{opt}")],
    ])

def kb_type():
    return KM([[IK("🅰️ Type A","type:A"), IK("🅱️ Type B","type:B"), IK("🔀 Both A+B","type:AB")],
               [IK("❌ Cancel","back")]])

def kb_cfg():
    return KM([
        [IK("🔖 Version",      "cfg:version"),   IK("📢 Channel",       "cfg:tg")],
        [IK("📝 Opt 1 Name","cfg:opt1name"), IK("📝 Opt 2 Name","cfg:opt2name")],
        [IK("📝 Opt 3 Name","cfg:opt3name"), IK("📝 Opt 4 Name","cfg:opt4name")],
        [IK("🗑 Remove 1",     "cfg:rm1"),         IK("🗑 Remove 2",      "cfg:rm2")],
        [IK("🅰️ Type A",      "cfg:typeA"),      IK("🅱️ Type B",       "cfg:typeB")],
        [IK("🔙 Back",         "back")],
    ])

def kb_rm(num):
    return KM([
        [IK(f"Name",f"cfg:rm{num}name"),IK(f"FFTH Path",f"cfg:rm{num}ffth")],
        [IK(f"FFMAX Path",f"cfg:rm{num}ffmax"),IK(f"Upload",f"cfg:rm{num}file")],
        [IK("Back","cfg")],
    ])

async def go_main(q):
    await safe_edit(q,"🔐 *ZEX INJECTION VPS*\n\nWhat would you like to do?",kb_main())

async def safe_edit(q, t, kb=None):
    try: await q.edit_message_text(t, reply_markup=kb, parse_mode="Markdown")
    except Exception as e: log.debug(f"edit: {e}")

# ── /start ────────────────────────────────────────────────────────
async def cmd_start(u: Update, c: ContextTypes.DEFAULT_TYPE):
    if not is_admin(u.effective_user.id):
        await u.message.reply_text("❌ Unauthorized."); return ConversationHandler.END
    await u.message.reply_text("🔐 *ZEX INJECTION VPS*\n\nWhat would you like to do?",
                                reply_markup=kb_main(), parse_mode="Markdown")
    return MAIN

# ── Main callback ──────────────────────────────────────────────────
async def cb_main(u: Update, c: ContextTypes.DEFAULT_TYPE):
    q = u.callback_query; await q.answer()
    if not is_admin(u.effective_user.id): return MAIN
    d = q.data

    if d == "back":
        c.user_data.clear(); await go_main(q); return MAIN

    # ── Status ──────────────────────────────────────────────────
    if d == "status":
        cfg = lcfg(); keys = lkeys()
        tA = cfg.get("typeA",{}); tB = cfg.get("typeB",{})
        msg = (f"📊 *ZEX VPS Status*\n\n"
               f"🌐 URL: `{VPS_URL}`\n"
               f"🔖 Ver: `{cfg.get('version','?')}`\n"
               f"📢 TG: `{cfg.get('telegram','?')}`\n\n"
               f"🅰️ Type A: `{tA.get('name','?')}` → `{tA.get('iosPath','') or tA.get('mcmFolder','?')}`\n"
               f"🅱️ Type B: `{tB.get('name','?')}` → `{tB.get('iosPath','') or tB.get('mcmFolder','?')}`\n\n"
               f"🔑 Keys: *{len(keys.get('keys',[]))}*\n"
               f"📦 Opt1: *{len(cfg.get('option1Slots',[]))}* slots\n"
               f"📦 Opt2: *{len(cfg.get('option2Slots',[]))}* slots\n"
               f"📦 Opt3: *{len(cfg.get('option3Slots',[]))}* slots\n"
               f"📦 Opt4 (EXTRA): *{len(cfg.get('option4Slots',[]))}* slots")
        await safe_edit(q, msg, kb_back()); return MAIN

    # ── Option menus ─────────────────────────────────────────────
    if d.startswith("sl:") and len(d) == 4:
        opt = d[-1]; await safe_edit(q,f"📦 *Option {opt}*",kb_opt(opt)); return MAIN

    if d.startswith("sl:list:"):
        opt = d[-1]; cfg = lcfg()
        slots = cfg.get(f"option{opt}Slots",[])
        if not slots:
            await safe_edit(q,f"📭 Option {opt} empty.",kb_opt(opt)); return MAIN
        msg = f"📦 *Option {opt} — {len(slots)} Slots:*\n\n"
        for s in slots: msg += slot_info_text(s, opt) + "\n\n"
        if len(msg) > 4000: msg = msg[:3990] + "..."
        await safe_edit(q, msg, kb_opt(opt)); return MAIN

    if d.startswith("sl:new:"):
        opt = d[-1]; c.user_data["opt"] = opt
        await safe_edit(q, f"📦 *New Slot in Option {opt}*\n\nType choose karo:", kb_type())
        return SL_TYPE

    if d.startswith("sl:edit:"):
        opt = d[-1]; c.user_data["opt"] = opt
        await safe_edit(q, f"✏️ *Option {opt}* — Kaunsa slot edit karna hai?",
                        kb_slot_list(opt, "pick")); return MAIN

    if d.startswith("sl:del:"):
        opt = d[-1]; c.user_data["opt"] = opt
        await safe_edit(q, f"🗑 *Option {opt}* — Kaunsa slot delete karna hai?",
                        kb_slot_list(opt, "del")); return MAIN

    if d.startswith("sl:upload:"):
        opt = d[-1]; c.user_data["opt"] = opt
        await safe_edit(q, f"📤 *Option {opt}* — Kaunse slot mein file dalni hai?",
                        kb_slot_list(opt, "up")); return MAIN

    if d.startswith("sl:photo:"):
        opt = d[-1]; c.user_data["opt"] = opt
        await safe_edit(q, f"🖼 *Option {opt}* — Kaunse slot ki photo set karni hai?",
                        kb_slot_list(opt, "ph")); return MAIN

    # ── Slot pick actions ─────────────────────────────────────────
    if d.startswith("pick:"):
        _, opt, sid = d.split(":"); sid = int(sid)
        c.user_data.update({"opt":opt,"sid":sid})
        cfg = lcfg()
        slot = next((s for s in cfg.get(f"option{opt}Slots",[]) if s["id"]==sid), None)
        if not slot: await safe_edit(q,"❌ Slot not found",kb_back()); return MAIN
        await safe_edit(q,
            f"✏️ *[{sid}] {slot['name']}*\n\n"
            f"Desc: `{slot.get('description','')}`\n"
            f"Type: `{slot.get('type','A')}`\n"
            f"File: `{slot.get('fileName','')}`\n\n"
            f"What would you like to do?", kb_edit(opt, sid))
        return MAIN

    if d.startswith("del:"):
        _, opt, sid = d.split(":"); sid = int(sid)
        cfg = lcfg(); key = f"option{opt}Slots"
        slot = next((s for s in cfg.get(key,[]) if s["id"]==sid), None)
        if slot:
            cfg[key] = [s for s in cfg[key] if s["id"] != sid]
            scfg(cfg)
            shutil.rmtree(str(slot_dir(opt,sid)), ignore_errors=True)
            await safe_edit(q, f"🗑 *[{sid}] {slot['name']}* deleted!", kb_opt(opt))
        return MAIN

    if d.startswith("up:"):
        _, opt, sid = d.split(":"); sid = int(sid)
        c.user_data.update({"opt":opt,"sid":sid})
        cfg = lcfg()
        slot = next((s for s in cfg.get(f"option{opt}Slots",[]) if s["id"]==sid), None)
        await safe_edit(q, f"📤 *Send file for [{sid}] {slot['name'] if slot else '?'}*\n\nSend document:", kb_back())
        return FILE_UP

    if d.startswith("ph:"):
        _, opt, sid = d.split(":"); sid = int(sid)
        c.user_data.update({"opt":opt,"sid":sid})
        cfg = lcfg()
        slot = next((s for s in cfg.get(f"option{opt}Slots",[]) if s["id"]==sid), None)
        await safe_edit(q, f"🖼 *Photo bhejo for [{sid}] {slot['name'] if slot else '?'}*\n\nPhoto send karo:", kb_back())
        return PHOTO_UP

    # ── Edit field actions ────────────────────────────────────────
    if d.startswith("e:"):
        parts = d.split(":"); action, opt, sid = parts[1], parts[2], int(parts[3])
        c.user_data.update({"opt":opt,"sid":sid,"action":action})
        prompts = {
            "name":   "📝 *Naya naam bhejo:*",
            "rename": "📝 *Naya naam bhejo:*",
            "desc":   "📄 *Naya description bhejo:*",
            "url":    "🔗 *Naya file URL bhejo:*",
        }
        if action in prompts:
            await safe_edit(q, prompts[action], kb_back()); 
            return {"name":EDIT_NAME,"rename":EDIT_NAME,"desc":EDIT_DESC,"url":EDIT_URL}[action]
        if action == "type":
            await safe_edit(q, "🏷 *Type choose karo:*", kb_type()); return EDIT_TYPE
        if action == "fixed":
            cfg = lcfg()
            slot_obj = next((s for s in cfg.get(f"option{opt}Slots",[]) if s["id"]==int(parts[3])), {})
            cur_fixed = slot_obj.get("fixedType", False)
            new_fixed = not cur_fixed
            slot_obj["fixedType"] = new_fixed
            scfg(cfg)
            status = "🔒 LOCKED" if new_fixed else "🔓 UNLOCKED"
            await safe_edit(q, f"✅ Slot type *{status}*!\nUser ab type change {'nahi kar sakta' if new_fixed else 'kar sakta hai'}.", kb_edit(opt, int(parts[3])))
            return MAIN
        if action == "urlB":
            c.user_data.update({"opt":opt,"sid":int(parts[3]),"action":"urlB"})
            slot_obj = next((s for s in lcfg().get(f"option{opt}Slots",[]) if s["id"]==int(parts[3])), {})
            await safe_edit(q, f"🔗 *Type B URL bhejo for:*\n`[{parts[3]}] {slot_obj.get('name','?')}`\n\nType B file URL:", kb_back())
            return SL_EDIT_URL
        if action == "direct":
            slot_o = next((s for s in lcfg().get(f"option{opt}Slots",[]) if s["id"]==int(parts[3])),{})
            cur = slot_o.get("directPath","Not set")
            await safe_edit(q,
                f"📍 *Direct Inject Path:*\n\nCurrent: `{cur}`\n\n"
                f"Filza se exact path copy karo aur paste karo:\n"
                f"Example:\n`/var/mobile/Containers/Data/Application/81E2DE97-2366-4E62-BE38-FFACC8C00307/Documents/contentcache/Compulsory/ios/gameassetbundles`\n\n"
                f"UUID wala pura path daalo:", kb_back())
            return EDIT_NAME
        if action == "ffth":
            slot_o=next((s for s in lcfg().get(f"option{opt}Slots",[]) if s["id"]==int(parts[3])),{})
            cur=slot_o.get("ffthPath","Not set")
            await safe_edit(q,f"FFTH Path:\n`{cur}`\n\nEnter sub path for Free Fire TH:\nExample: `com.dts.freefireth/Documents/contentcache/Compulsory/ios/gameassetbundles`",kb_back())
            c.user_data.update({"opt":opt,"sid":int(parts[3]),"action":"ffth"})
            return EDIT_NAME
        if action == "ffmax":
            slot_o=next((s for s in lcfg().get(f"option{opt}Slots",[]) if s["id"]==int(parts[3])),{})
            cur=slot_o.get("ffmaxPath","Not set")
            await safe_edit(q,f"FFMAX Path:\n`{cur}`\n\nEnter sub path for Free Fire MAX:\nExample: `com.dts.freefiremax/Documents/contentcache/Compulsory/ios/gameassetbundles`",kb_back())
            c.user_data.update({"opt":opt,"sid":int(parts[3]),"action":"ffmax"})
            return EDIT_NAME
        if action == "bundleid":
            slot_o = next((s for s in lcfg().get(f"option{opt}Slots",[]) if s["id"]==int(parts[3])),{})
            cur = slot_o.get("bundleId","Not set")
            await safe_edit(q, f"📦 *Bundle ID set karo:*\n\nCurrent: `{cur}`\n\nExample:\n`com.tencent.ig`\n`com.vng.pubgmobile`\n`com.ea.gp.fifamobile`\n\nBundle ID bhejo:", kb_back())
            return EDIT_NAME  # reuse edit name state for text input
        if action == "subpath":
            slot_o = next((s for s in lcfg().get(f"option{opt}Slots",[]) if s["id"]==int(parts[3])),{})
            cur = slot_o.get("subPath","Not set")
            await safe_edit(q, f"📂 *Sub Path set karo:*\n\nCurrent: `{cur}`\n\nExample:\n`Documents/contentcache/Compulsory/ios`\n`Documents/`\n\nSub path bhejo:", kb_back())
            return EDIT_NAME  # reuse edit name state
        if action == "path":
            slot_obj = next((s for s in lcfg().get(f"option{opt}Slots",[]) if s["id"]==int(parts[3])), {})
            cur = slot_obj.get("iosPath","Not set")
            await safe_edit(q, f"📁 *iOS Injection Path:*\n\nCurrent: `{cur}`\n\nEnter new path:\nExample:\n`/var/mobile/Containers/Data/Application/UUID/Documents`\nYa MCM:\n`[MHA-C2] App Data`\n`[MHA-C12] System Data`", kb_back())
            return EDIT_PATH
        if action == "file":
            await safe_edit(q, "📤 *File bhejo:*\nDocument/file send karo:", kb_back()); return FILE_UP
        if action == "photo":
            await safe_edit(q, "🖼 *Photo bhejo:*\nImage send karo:", kb_back()); return PHOTO_UP
        if action == "rot":
            folder = slot_dir(opt, sid)
            cover = folder / "cover.jpg"
            if cover.exists():
                try:
                    from PIL import Image
                    with Image.open(str(cover)) as im:
                        rotated = im.transpose(Image.ROTATE_270)
                        rotated.save(str(cover), format="JPEG", quality=95)
                    await safe_edit(q, f"✅ *Photo rotated 90° clockwise!*", kb_edit(opt, sid))
                except Exception as ex:
                    await safe_edit(q, f"❌ Error rotating photo: {ex}", kb_edit(opt, sid))
            else:
                await safe_edit(q, "❌ Koi photo upload nahi hai.", kb_edit(opt, sid))
            return MAIN
        if action == "del":
            cfg = lcfg(); key = f"option{opt}Slots"
            slot = next((s for s in cfg.get(key,[]) if s["id"]==sid), None)
            if slot:
                cfg[key] = [s for s in cfg[key] if s["id"] != sid]
                scfg(cfg)
                shutil.rmtree(str(slot_dir(opt,sid)), ignore_errors=True)
                await safe_edit(q, f"🗑 *[{sid}] {slot['name']}* deleted!", kb_opt(opt))
            return MAIN

    # ── Keys ─────────────────────────────────────────────────────
    if d == "keys": await safe_edit(q,"🔑 *Keys*",kb_keys()); return MAIN
    if d == "key:list":
        k = lkeys()["keys"]
        body = "\n".join(f"`{x}`" for x in k) if k else "_(none)_"
        await safe_edit(q,f"🔑 *Keys ({len(k)}):*\n{body}",kb_back("keys")); return MAIN
    if d == "key:gen":
        await safe_edit(q,"Select key duration:",kb_duration()); return MAIN
    if d.startswith("dur:"):
        dur=d[4:]; dur_name,dur_secs=DURATIONS.get(dur,("30 Days",30*86400))
        new_key=gen_key()
        kd=lkeys(); keys=kd.get("keys",{})
        if isinstance(keys,list): keys={k:{"device":"","expires":0} for k in keys}
        import time as _t
        keys[new_key]={"device":"","created":int(_t.time()),"expires":int(_t.time()+dur_secs) if dur_secs else 0,"duration":dur}
        kd["keys"]=keys; skeys(kd)
        exp_str="Never" if not dur_secs else dur_name
        await safe_edit(q,f"*Key Generated!*\n\n`{new_key}`\n\nDuration: {dur_name}\nExpires: {exp_str}",kb_keys()); return MAIN
    if d == "key:add":
        await safe_edit(q,"🔑 Send key:\n`ZEX-XXXX-XXXX`",kb_back("keys")); return KEY_ADD
    # Remove button settings
    if d in ("cfg:rm1","cfg:rm2"):
        num=d[-1]
        cfg=lcfg()
        rm=cfg.get(f"remove{num}",{})
        try:
            import pathlib
            rp=pathlib.Path("/root/IOS INJECTION/restore_files")/f"restore{num}"
            rp.mkdir(parents=True,exist_ok=True)
            rf_list=[f.name for f in rp.iterdir() if f.is_file()]
            rf=rf_list[0] if rf_list else "Not uploaded"
        except Exception as ex:
            rf=f"Error: {ex}"
        msg=(
            f"Restore Button {num}\n\n"
            f"Name: `{rm.get('name',f'RESTORE {num}')}`\n"
            f"FFTH Path: `{rm.get('ffthPath','Not set')}`\n"
            f"FFMAX Path: `{rm.get('ffmaxPath','Not set')}`\n"
            f"Original File: `{rf}`"
        )
        await safe_edit(q,msg,kb_rm(num))
        return MAIN
    for num in ["1","2"]:
        for field in ["name","ffth","ffmax"]:
            if d == f"cfg:rm{num}{field}":
                prompts={
                    "name":f"Enter button name for Restore {num}:",
                    "ffth":f"FFTH path to restore original:\n`com.dts.freefireth/Documents/contentcache/Compulsory/ios/gameassetbundles`",
                    "ffmax":f"FFMAX path to restore original:\n`com.dts.freefiremax/Documents/contentcache/Compulsory/ios/gameassetbundles`"
                }
                c.user_data.update({"cfg_key":f"rm{num}{field}"})
                await safe_edit(q,prompts[field],kb_back(f"cfg:rm{num}"))
                return CFG_VAL
        if d == f"cfg:rm{num}file":
            c.user_data.update({"rm_upload":num})
            await safe_edit(q,f"Send the ORIGINAL file for Restore {num}:\n(This will replace the modded file when Restore is pressed)",kb_back(f"cfg:rm{num}"))
            return FILE_UP
    if d == "key:unbind":
        kd=lkeys(); keys=kd.get("keys",{})
        bound = {k:v["device"] for k,v in keys.items() if v.get("device")}
        if not bound:
            await safe_edit(q,"📭 Koi bound key nahi.",kb_back("keys")); return MAIN
        rows=[[IK(f"Unbind {key[:20]}",f"kunbind:{key}")] for key,dev in bound.items()]
        rows.append([IK("🔙 Back","keys")]); await safe_edit(q,"🔓 *Key Unbind — device se hatao:*",KM(rows)); return MAIN
    if d.startswith("kunbind:"):
        key=d[8:]; kd=lkeys()
        if key in kd.get("keys",{}): kd["keys"][key]["device"]=""
        skeys(kd)
        await safe_edit(q,f"✅ Key `{key}` unbound! User phir bind kar sakta hai.",kb_keys()); return MAIN
    if d == "key:del":
        k = list(lkeys().get("keys",{}).keys())
        if not k: await safe_edit(q,"📭 Keys nahi.",kb_back("keys")); return MAIN
        rows=[[IK(f"🗑 {x}",f"kd:{x}")] for x in k]+[[IK("🔙 Back","keys")]]
        await safe_edit(q,"🗑 *Kaunsi key remove?*",KM(rows)); return MAIN
    if d.startswith("kd:"):
        key=d[3:]; kd=lkeys(); kd["keys"]=[x for x in kd["keys"] if x!=key]; skeys(kd)
        await safe_edit(q,f"✅ Removed: `{key}`",kb_keys()); return MAIN

    # ── Config ────────────────────────────────────────────────────
    if d == "cfg": await safe_edit(q,"⚙️ *Config*",kb_cfg()); return MAIN
    if d.startswith("cfg:") and d not in ("cfg:rm1","cfg:rm2"):
        key = d[4:]
        c.user_data["cfg_key"] = key
        prompts = {
            "version": "🔖 Naya version: (e.g. 2.8.0)",
            "tg":      "📢 Naya Telegram URL:\n(e.g. https://t.me/channel)",
            "typeA":   '🅰️ *Type A — iOS Path:*\n\nFormat: `"Display Naam" "/var/mobile/Containers/Data/Application/UUID/Documents"`\n\nExample:\n`"Game" "/var/mobile/Containers/Data/Application/ABC-123/Documents"`\n\nYa MCM:\n`"Type A" "[MHA-C2] App Data"`',
            "typeB":   '🅱️ *Type B — iOS Path:*\n\nFormat: `"Display Naam" "/var/mobile/Containers/Data/Application/UUID/Library"`\n\nExample:\n`"System" "/var/mobile/Containers/Data/Application/XYZ-456/Library"`',
            "opt1name":"Enter new name for Option 1:","opt2name":"Enter new name for Option 2:","opt3name":"Enter new name for Option 3:","opt4name":"Enter new name for Option 4 (EXTRA):","opts":'Option Names: `"Opt1" "Opt2" "Opt3" "EXTRA"`',
            "rems":    '📝 *Remove Button Names:*\nFormat: `"Remove 1" "Remove 2"`\nExample: `"Clear Active" "Clear Inactive"`',
            "rm1path": '🗑 *Remove 1 — iOS Path:\nFormat: "Button Name" "MCM Folder" "sub/path" "filename"\nExample: "REMOVE ACT" "[MHA-C2] App Data" "com.dts.freefiremax/Documents/cache" "file.bundle"',
            "rm2path": '🗑 *Remove 2 — iOS Path:\nFormat: "Button Name" "MCM Folder" "sub/path" "filename"\nExample: "REMOVE OPT2" "[MHA-C2] App Data" "com.game/Documents" "file2.bundle"',
            "rm1":     '🗑 *Remove Button 1 Settings*',
            "rm2":     '🗑 *Remove Button 2 Settings*',
        }
        await safe_edit(q, prompts.get(key,"Value bhejo:"), kb_back("cfg")); return CFG_VAL

    return MAIN

# ── Type select ───────────────────────────────────────────────────
async def cb_type(u: Update, c: ContextTypes.DEFAULT_TYPE):
    q = u.callback_query; await q.answer(); d = q.data
    if d == "back": await go_main(q); c.user_data.clear(); return MAIN
    typ = d.split(":")[1]; c.user_data["type"] = typ
    action = c.user_data.get("action","")
    opt = c.user_data.get("opt","1"); sid = c.user_data.get("sid",0)

    if action == "type" and sid:
        cfg = lcfg()
        slot = next((s for s in cfg.get(f"option{opt}Slots",[]) if s["id"]==sid), None)
        if slot: slot["type"] = typ; scfg(cfg)
        await safe_edit(q,f"✅ Type → `{typ}`!",kb_opt(opt)); c.user_data.clear(); return MAIN

    await safe_edit(q,f"Type: *{typ}* ✅\n\n📝 *Enter slot name:*",kb_back()); return SL_NAME

# ── New slot ──────────────────────────────────────────────────────
async def msg_sl_name(u: Update, c: ContextTypes.DEFAULT_TYPE):
    c.user_data["name"] = u.message.text.strip()
    await u.message.reply_text("📄 *Enter description:*",reply_markup=kb_back(),parse_mode="Markdown")
    return SL_DESC

async def msg_sl_desc(u: Update, c: ContextTypes.DEFAULT_TYPE):
    ud = c.user_data; opt = ud.get("opt","1")
    desc = u.message.text.strip()
    cfg = lcfg(); key = f"option{opt}Slots"; slots = cfg.setdefault(key,[])
    sid = next_id(slots)
    slot = {"id":sid,"name":ud["name"],"description":desc,
            "type":ud.get("type","A"),"fileName":"","fileUrl":""}
    if opt == "3": slot["imageUrl"] = ""
    slots.append(slot); scfg(cfg); slot_dir(opt, sid)  # create folder
    await u.message.reply_text(
        f"✅ *Slot Created!*\nOption `{opt}` | ID `{sid}`\n"
        f"Name: `{ud['name']}`\nType: `{ud.get('type','A')}`\n\n"
        f"Upload your file now 📤",
        reply_markup=KM([[IK(f"📤 File Upload [{sid}]",f"up:{opt}:{sid}")],
                         [IK(f"🔙 Option {opt}",f"sl:{opt}")]]),
        parse_mode="Markdown")
    c.user_data.clear(); return MAIN

# ── Edit messages ──────────────────────────────────────────────────
async def msg_edit_name(u: Update, c: ContextTypes.DEFAULT_TYPE):
    ud = c.user_data; opt=ud.get("opt","1"); sid=ud.get("sid",1)
    txt = u.message.text.strip()
    cfg = lcfg()
    slot = next((s for s in cfg.get(f"option{opt}Slots",[]) if s["id"]==sid), None)
    action = ud.get("action","")
    if action == "ffth":
        if slot: slot["ffthPath"]=txt; scfg(cfg)
        await u.message.reply_text(f"✅ FFTH Path set:\n`{txt[:80]}`",reply_markup=kb_opt(opt),parse_mode="Markdown")
    elif action == "ffmax":
        if slot: slot["ffmaxPath"]=txt; scfg(cfg)
        await u.message.reply_text(f"✅ FFMAX Path set:\n`{txt[:80]}`",reply_markup=kb_opt(opt),parse_mode="Markdown")
    elif action == "direct":
        if slot: slot["directPath"]=txt; scfg(cfg)
        await u.message.reply_text(f"✅ Direct Path → `{txt[:80]}`",reply_markup=kb_opt(opt),parse_mode="Markdown")
    else:
        if slot: slot["name"]=txt; scfg(cfg)
        await u.message.reply_text(f"✅ Name → `{txt}`",reply_markup=kb_opt(opt),parse_mode="Markdown")
    c.user_data.clear(); return MAIN

async def msg_edit_desc(u: Update, c: ContextTypes.DEFAULT_TYPE):
    ud = c.user_data; opt=ud.get("opt","1"); sid=ud.get("sid",1)
    txt = u.message.text.strip()
    cfg = lcfg()
    slot = next((s for s in cfg.get(f"option{opt}Slots",[]) if s["id"]==sid), None)
    if slot: slot["description"] = txt; scfg(cfg)
    await u.message.reply_text(f"✅ Description updated!",reply_markup=kb_opt(opt),parse_mode="Markdown")
    c.user_data.clear(); return MAIN

async def msg_edit_url(u: Update, c: ContextTypes.DEFAULT_TYPE):
    ud = c.user_data; opt=ud.get("opt","1"); sid=ud.get("sid",1)
    url = u.message.text.strip()
    cfg = lcfg()
    slot = next((s for s in cfg.get(f"option{opt}Slots",[]) if s["id"]==sid), None)
    if slot:
        if ud.get("action") == "urlB":
            slot["fileUrlB"] = url
            fname = url.split("/")[-1].split("?")[0]
            if fname: slot["fileNameB"] = fname
        else:
            slot["fileUrl"] = url
            fname = url.split("/")[-1].split("?")[0]
            if fname: slot["fileName"] = fname
        scfg(cfg)
    await u.message.reply_text(f"✅ URL → `{url}`",reply_markup=kb_opt(opt),parse_mode="Markdown")
    c.user_data.clear(); return MAIN

# ── File upload ────────────────────────────────────────────────────
async def msg_file_up(u: Update, c: ContextTypes.DEFAULT_TYPE):
    # Check if this is a restore file upload
    rm_num = c.user_data.pop("rm_upload", None)
    if rm_num and u.message.document:
        doc = u.message.document; fname = doc.file_name or "original_file"
        folder = RESTORE / f"restore{rm_num}"
        folder.mkdir(parents=True, exist_ok=True)
        # Clear old restore files
        for old in folder.iterdir(): old.unlink()
        tgf = await doc.get_file()
        fpath = folder / fname
        await tgf.download_to_drive(fpath)
        await u.message.reply_text(f"✅ Restore {rm_num} original file saved!\n`{fname}`", parse_mode="Markdown")
        return MAIN
    ud = c.user_data; opt=ud.get("opt","1"); sid=ud.get("sid",1)
    doc = u.message.document
    if not doc:
        await u.message.reply_text("❌ Document/file bhejo."); return FILE_UP
    await u.message.reply_text("⏳ Uploading...")
    tg_file = await c.bot.get_file(doc.file_id)
    folder = slot_dir(opt, sid)
    # Remove old files (not cover)
    for f in folder.glob("*"):
        if not f.name.startswith("cover"): f.unlink(missing_ok=True)
    dest = folder / doc.file_name
    await tg_file.download_to_drive(str(dest))
    # Update config
    cfg = lcfg()
    slot = next((s for s in cfg.get(f"option{opt}Slots",[]) if s["id"]==sid), None)
    if slot:
        slot["fileName"] = doc.file_name
        slot["fileUrl"]  = file_url(opt, sid, doc.file_name)
        scfg(cfg)
    sz = dest.stat().st_size // 1024
    await u.message.reply_text(
        f"✅ *File Uploaded!*\n`{doc.file_name}` ({sz} KB)\n"
        f"URL: `{file_url(opt, sid, doc.file_name)}`",
        reply_markup=kb_opt(opt), parse_mode="Markdown")
    c.user_data.clear(); return MAIN

# ── Photo upload ───────────────────────────────────────────────────
async def msg_photo_up(u: Update, c: ContextTypes.DEFAULT_TYPE):
    ud = c.user_data; opt=ud.get("opt","1"); sid=ud.get("sid",1)
    if not u.message.photo:
        await u.message.reply_text("❌ Photo bhejo."); return PHOTO_UP
    await u.message.reply_text("⏳ Saving photo...")
    tg_file = await c.bot.get_file(u.message.photo[-1].file_id)
    folder = slot_dir(opt, sid)
    for f in folder.glob("cover.*"): f.unlink(missing_ok=True)
    dest = folder / "cover.jpg"
    await tg_file.download_to_drive(str(dest))
    try:
        from PIL import Image, ImageOps
        with Image.open(str(dest)) as im:
            im = ImageOps.exif_transpose(im)
            im.save(str(dest), format="JPEG", quality=95)
    except Exception as ex:
        log.warning(f"Image transpose error: {ex}")
    # Update imageUrl in config
    cfg = lcfg()
    slot = next((s for s in cfg.get(f"option{opt}Slots",[]) if s["id"]==sid), None)
    if slot:
        slot["imageUrl"] = file_url(opt, sid, "cover.jpg")
        scfg(cfg)
    await u.message.reply_text(
        f"✅ *Photo Saved!*\n`{file_url(opt, sid, 'cover.jpg')}`",
        reply_markup=kb_opt(opt), parse_mode="Markdown")
    c.user_data.clear(); return MAIN

# ── Edit iOS Path ─────────────────────────────────────────────────────────────────
async def msg_edit_path(u: Update, c: ContextTypes.DEFAULT_TYPE):
    ud = c.user_data; opt=ud.get("opt","1"); sid=ud.get("sid",1)
    path = u.message.text.strip()
    cfg = lcfg()
    slot = next((s for s in cfg.get(f"option{opt}Slots",[]) if s["id"]==sid), None)
    if slot:
        slot["iosPath"] = path
        scfg(cfg)
    await u.message.reply_text(
        f"✅ *iOS Path Set!*\n`{path}`",
        reply_markup=kb_opt(opt), parse_mode="Markdown")
    c.user_data.clear(); return MAIN

# ── Key add ────────────────────────────────────────────────────────
async def msg_key_add(u: Update, c: ContextTypes.DEFAULT_TYPE):
    key = u.message.text.strip().upper()
    kd = lkeys()
    if key not in kd["keys"]: kd["keys"].append(key); skeys(kd)
    await u.message.reply_text(f"✅ Key added: `{key}`",reply_markup=kb_keys(),parse_mode="Markdown")
    return MAIN

# ── Config value ───────────────────────────────────────────────────
async def msg_cfg_val(u: Update, c: ContextTypes.DEFAULT_TYPE):
    import shlex
    key = c.user_data.get("cfg_key",""); txt = u.message.text.strip()
    cfg = lcfg()
    if key == "version":  cfg["version"] = txt
    elif key == "tg":     cfg["telegram"] = txt
    elif key in ("typeA","typeB"):
        try:
            args = shlex.split(txt)
            if len(args) >= 2:
                val = args[1]
                if val.startswith("/"):
                    cfg[key] = {"name":args[0],"iosPath":val,"mcmFolder":""}
                else:
                    cfg[key] = {"name":args[0],"iosPath":"","mcmFolder":val}
        except: pass
    elif key == "opt1name":
        cfg["option1Name"]=txt; scfg(cfg)
    elif key == "opt2name":
        cfg["option2Name"]=txt; scfg(cfg)
    elif key == "opt3name":
        cfg["option3Name"]=txt; scfg(cfg)
    elif key == "opt4name":
        cfg["option4Name"]=txt; scfg(cfg)
    elif key == "opts":
        try:
            args = shlex.split(txt)
            if len(args) >= 4:
                cfg["option1Name"]=args[0]; cfg["option2Name"]=args[1]; cfg["option3Name"]=args[2]; cfg["option4Name"]=args[3]
                scfg(cfg)
            elif len(args) >= 3:
                cfg["option1Name"]=args[0]; cfg["option2Name"]=args[1]; cfg["option3Name"]=args[2]
                scfg(cfg); print(f"Saved option names: {args[:3]}")
        except: pass
    elif key == "rems":
        try:
            args = shlex.split(txt)
            if len(args) >= 2:
                cfg.setdefault("remove1",{})["name"] = args[0]
                cfg.setdefault("remove2",{})["name"] = args[1]
                cfg["remove1Name"] = args[0]  # backward compat
                cfg["remove2Name"] = args[1]
        except: pass
    elif key == "rm1path":
        cfg.setdefault("remove1",{})["path"] = txt
        scfg(cfg)
    elif key == "rm2path":
        cfg.setdefault("remove2",{})["path"] = txt
        scfg(cfg)
    elif key.startswith("rm") and key[2] in "12" and key[3:] in ["name","ffth","ffmax"]:
        num=key[2]; field=key[3:]
        rm=cfg.setdefault(f"remove{num}",{})
        field_map={"name":"name","ffth":"ffthPath","ffmax":"ffmaxPath"}
        rm[field_map[field]]=txt
        if field=="name":cfg[f"remove{num}Name"]=txt
        scfg(cfg)
    scfg(cfg)
    await u.message.reply_text(f"✅ *{key}* updated: `{txt[:60]}`",
                                reply_markup=kb_cfg(),parse_mode="Markdown")
    c.user_data.clear(); return MAIN

# ── Bot main ──────────────────────────────────────────────────────
def back_handler():
    async def _h(u,c):
        q=u.callback_query; await q.answer()
        await go_main(q); c.user_data.clear(); return MAIN
    return CallbackQueryHandler(_h)

def run_bot():
    if not BOT_TOKEN:
        log.error("BOT_TOKEN not set!"); return

    async def _run():
        app = Application.builder().token(BOT_TOKEN).build()
        conv = ConversationHandler(
            entry_points=[CommandHandler("start",cmd_start)],
            states={
                MAIN:      [CallbackQueryHandler(cb_main)],
                SL_TYPE:   [CallbackQueryHandler(cb_type)],
                SL_NAME:   [MessageHandler(filters.TEXT&~filters.COMMAND,msg_sl_name),back_handler()],
                SL_DESC:   [MessageHandler(filters.TEXT&~filters.COMMAND,msg_sl_desc),back_handler()],
                EDIT_TYPE: [CallbackQueryHandler(cb_type)],
                EDIT_NAME: [MessageHandler(filters.TEXT&~filters.COMMAND,msg_edit_name),back_handler()],
                EDIT_DESC: [MessageHandler(filters.TEXT&~filters.COMMAND,msg_edit_desc),back_handler()],
                EDIT_URL:  [MessageHandler(filters.TEXT&~filters.COMMAND,msg_edit_url),back_handler()],
                EDIT_PATH: [MessageHandler(filters.TEXT&~filters.COMMAND,msg_edit_path),back_handler()],
                FILE_UP:   [MessageHandler(filters.Document.ALL,msg_file_up),back_handler()],
                PHOTO_UP:  [MessageHandler(filters.PHOTO,msg_photo_up),back_handler()],
                KEY_ADD:   [MessageHandler(filters.TEXT&~filters.COMMAND,msg_key_add),back_handler()],
                CFG_VAL:   [MessageHandler(filters.TEXT&~filters.COMMAND,msg_cfg_val),back_handler()],
            },
            fallbacks=[CommandHandler("start",cmd_start)],
        )
        app.add_handler(conv)
        log.info("🤖 Bot started!")
        await app.initialize()
        await app.start()
        await app.updater.start_polling(allowed_updates=Update.ALL_TYPES)
        import asyncio
        while True: await asyncio.sleep(3600)

    import asyncio
    asyncio.run(_run())

# ── Entry point ───────────────────────────────────────────────────
if __name__ == "__main__":
    log.info(f"🌐 Starting web server on port {PORT}")
    log.info(f"🔗 VPS URL: {VPS_URL}")
    # Flask in background thread
    web_thread = threading.Thread(target=run_web, daemon=True)
    web_thread.start()
    # Bot in main thread
    run_bot()
