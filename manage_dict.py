# -*- coding: utf-8 -*-
"""
五笔86·拼音 词库手动管理工具

用法（本机 Python 3）：
  python manage_dict.py                 交互菜单
  python manage_dict.py add 词 --wubi 码 [--pinyin 全拼] [--fr 法语] [--pos 词性]
  python manage_dict.py del 词
  python manage_dict.py query 词
  python manage_dict.py deploy          重新部署（编译生效）
  python manage_dict.py status          词库统计

说明：
- add：至少提供 --wubi（五笔码）或 --pinyin（全拼）之一；--fr 法语注释、--pos 词性可选。
  已存在的词不会覆盖，先 del 再加。
- del：三层同步删除。
- 改动默认同步到运行时词库（%APPDATA%\\Rime）与项目根副本，改完执行 deploy 生效。
"""
import argparse
import io
import os
import re
import shutil
import subprocess
import sys

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

RIME = os.path.join(os.environ["APPDATA"], "Rime")
PROJECT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # 五笔86拼音输入法/

WEIGHT = 1_000_000  # 自造词权重（高于默认词，低于原术语最高档）

FILES = {
    "wubi": ("wubi86py.dict.yaml", "五笔码表"),
    "term": ("wubi86py.term.dict.yaml", "拼音词表"),
    "fr": ("fr_data.lua", "法语注释"),
    "pos": ("fr_pos.lua", "词性表"),
}


def paths():
    return {k: (os.path.join(RIME, "lua", fn) if k in ("fr", "pos") else os.path.join(RIME, fn))
            for k, (fn, _) in FILES.items()}


def read(fn):
    with open(fn, encoding="utf-8") as f:
        return f.read()


def write(fn, text):
    with open(fn, "w", encoding="utf-8") as f:
        f.write(text)


def sync_to_project():
    """运行时词库改动后同步项目根副本"""
    for k, (fn, _) in FILES.items():
        src = paths()[k]
        dst = os.path.join(PROJECT, fn)
        if os.path.exists(src):
            shutil.copy2(src, dst)


def line_has_word(line, word):
    """yaml 词条行（词\\t码\\t权重）或 lua 词条行（["词"] = ...）"""
    return line.lstrip().startswith(word + "\t") or line.lstrip().startswith(f'["{word}"]')


def add(word, wubi=None, pinyin=None, fr=None, pos=None):
    if not (wubi or pinyin):
        print("错误：至少提供 --wubi 或 --pinyin 之一")
        return False
    p = paths()
    existed = []
    if wubi and f"{word}\t{wubi}\t" in read(p["wubi"]):
        existed.append("五笔码表")
    if pinyin and f"{word}\t{pinyin}\t" in read(p["term"]):
        existed.append("拼音词表")
    if fr and f'["{word}"]' in read(p["fr"]):
        existed.append("法语注释(已存在,未覆盖)")
    if pos and f'["{word}"]' in read(p["pos"]):
        existed.append("词性(已存在,未覆盖)")
    if existed:
        print(f"跳过：{word} 已存在于 " + "/".join(existed))
        return False

    lines = {}
    if wubi:
        t = read(p["wubi"])
        lines["wubi"] = t.rstrip("\n") + f"\n{word}\t{wubi}\t{WEIGHT}\n"
    if pinyin:
        t = read(p["term"])
        lines["term"] = t.rstrip("\n") + f"\n{word}\t{pinyin}\t{WEIGHT}\n"
    if fr or pos:
        for k, val in (("fr", fr), ("pos", pos)):
            if val:
                t = read(p[k])
                # 插到 Lua 表最后一个 "}" 之前，避免破坏语法
                idx = t.rstrip("\n").rfind("\n}")
                if idx == -1:
                    print(f"错误：{FILES[k][0]} 格式异常，无法写入")
                    return False
                lines[k] = t[:idx] + f'\n  ["{word}"] = "{val}",' + t[idx:]
    for k, text in lines.items():
        write(p[k], text)
    sync_to_project()
    print(f"已添加 {word}：" + "、".join(
        [f"五笔[{wubi}]" if wubi else ""] + [f"拼音[{pinyin}]" if pinyin else ""]
        + [f"法语[{fr}]" if fr else ""] + [f"词性[{pos}]" if pos else ""]))
    print("请执行 deploy 使改动生效")
    return True


def delete(word):
    p = paths()
    removed = []
    for k, (fn, label) in FILES.items():
        t = read(p[k])
        out = [ln for ln in t.splitlines(keepends=True) if not line_has_word(ln, word)]
        if len(out) != len(t.splitlines(keepends=True)):
            write(p[k], "".join(out))
            removed.append(label)
    sync_to_project()
    if removed:
        print(f"已从 {len(removed)} 处删除 {word}：" + "、".join(removed))
        print("请执行 deploy 使改动生效")
    else:
        print(f"{word} 在词库中未找到")
    return bool(removed)


def query(word):
    p = paths()
    found = False
    for k, fn in FILES.items():
        t = read(p[k])
        hits = [ln.rstrip("\n") for ln in t.splitlines() if line_has_word(ln, word)]
        if hits:
            found = True
            print(f"--- {fn} ---")
            for h in hits[:10]:
                print("  " + h)
    if not found:
        print(f"{word} 未在词库中找到")
    return found


def deploy():
    weasel = os.path.join(os.environ.get("ProgramFiles", r"C:\Program Files"), "Rime")
    deployer = None
    for root, dirs, _ in os.walk(weasel):
        cand = os.path.join(root, "WeaselDeployer.exe")
        if os.path.exists(cand):
            deployer = cand
            break
    if not deployer:
        print("未找到小狼毫 WeaselDeployer.exe，请手动：右键托盘小狼毫图标 → 重新部署")
        return False
    print("正在编译部署（首次或大词库需 1-2 分钟）...")
    subprocess.run([deployer, "/deploy"], check=False)
    t1 = os.path.join(RIME, "build", "wubi86py.table.bin")
    t2 = os.path.join(RIME, "build", "wubi86py.term.table.bin")
    import time
    deadline = time.time() + 120
    while (not (os.path.exists(t1) and os.path.exists(t2))) and time.time() < deadline:
        time.sleep(3)
    if os.path.exists(t1) and os.path.exists(t2):
        subprocess.run(["taskkill", "/f", "/im", "WeaselServer.exe"], capture_output=True)
        subprocess.Popen([os.path.join(os.path.dirname(deployer), "WeaselServer.exe")])
        print("部署完成，服务已重启，改动已生效")
        return True
    print("编译产物未生成，请右键托盘小狼毫图标 → 重新部署")
    return False


def status():
    p = paths()
    for k, fn in FILES.items():
        t = read(p[k])
        if k in ("fr", "pos"):
            n = len(re.findall(r'\[".*?"\]\s*=', t))
        else:
            n = len([l for l in t.splitlines() if "\t" in l and not l.startswith("#")])
        print(f"  {fn}: {n:,} 条")


MENU = """
========== 五笔86·拼音 词库管理 ==========
  1. 添加词
  2. 删除词
  3. 查询词
  4. 重新部署（使改动生效）
  5. 词库统计
  0. 退出
===========================================
"""


def menu():
    while True:
        print(MENU)
        c = input("请选择: ").strip()
        if c == "1":
            word = input("  中文词: ").strip()
            wubi = input("  五笔码（可留空）: ").strip() or None
            pinyin = input("  全拼（可留空）: ").strip() or None
            fr = input("  法语注释（可留空）: ").strip() or None
            pos = input("  词性（可留空，如 n./v./n.m.）: ").strip() or None
            add(word, wubi, pinyin, fr, pos)
        elif c == "2":
            word = input("  要删除的中文词: ").strip()
            delete(word)
        elif c == "3":
            word = input("  查询的中文词: ").strip()
            query(word)
        elif c == "4":
            deploy()
        elif c == "5":
            status()
        elif c == "0":
            print("退出")
            break
        else:
            print("无效选择")


def main():
    if len(sys.argv) == 1:
        menu()
        return
    ap = argparse.ArgumentParser(description="五笔86·拼音 词库管理")
    sub = ap.add_subparsers(dest="cmd")
    a = sub.add_parser("add")
    a.add_argument("word")
    a.add_argument("--wubi")
    a.add_argument("--pinyin")
    a.add_argument("--fr")
    a.add_argument("--pos")
    d = sub.add_parser("del")
    d.add_argument("word")
    q = sub.add_parser("query")
    q.add_argument("word")
    sub.add_parser("deploy")
    sub.add_parser("status")
    args = ap.parse_args()
    if args.cmd == "add":
        add(args.word, args.wubi, args.pinyin, args.fr, args.pos)
    elif args.cmd == "del":
        delete(args.word)
    elif args.cmd == "query":
        query(args.word)
    elif args.cmd == "deploy":
        deploy()
    elif args.cmd == "status":
        status()


if __name__ == "__main__":
    main()
