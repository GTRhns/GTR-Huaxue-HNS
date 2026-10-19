# -*- coding: utf-8 -*-
import re
import os
from collections import OrderedDict

ROOT = r"c:\Users\Administrator\Desktop\gtr\正在使用的本服sma\addons\amxmodx"
OUT = os.path.join(ROOT, "_lang_audit_out.txt")

files = [
    os.path.join(ROOT, "configs", "hns_language.txt"),
    os.path.join(ROOT, "data", "lang", "HnsSkin.txt"),
    os.path.join(ROOT, "data", "lang", "mixsystem.txt"),
    os.path.join(ROOT, "data", "lang", "match_additons.txt"),
    os.path.join(ROOT, "data", "lang", "SemiclipSystem.txt"),
    os.path.join(ROOT, "data", "lang", "KnifeModels.txt"),
]

cjk = re.compile(r"[\u4e00-\u9fff]")
sec_re = re.compile(r"^\[([^\]]+)\]")
kv_re = re.compile(r"^([A-Za-z0-9_]+)\s*=\s*(.*)$")


def parse(path):
    sections = OrderedDict()
    cur = None
    dups = []
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        for i, line in enumerate(f, 1):
            s = line.rstrip("\n").rstrip("\r").strip()
            if not s or s.startswith(";") or s.startswith("//"):
                continue
            m = sec_re.match(s)
            if m and "=" not in s:
                cur = m.group(1).split()[0].strip()
                sections.setdefault(cur, OrderedDict())
                continue
            m = kv_re.match(s)
            if m and cur:
                k, v = m.group(1), m.group(2).strip()
                if k in sections[cur]:
                    dups.append((cur, k, i))
                sections[cur][k] = (v, i)
    return sections, dups


def specs(v):
    return re.findall(r"%[!0-9\.\-\+ #]*[a-zA-Z%]", v)


lines = []


def p(s=""):
    lines.append(s)


for path in files:
    p("=" * 80)
    p(os.path.basename(path))
    sections, dups = parse(path)
    p("sections: " + str({k: len(v) for k, v in sections.items()}))
    if dups:
        p("DUPS count %d" % len(dups))
        for item in dups[:40]:
            p("  DUP %s %s line %d" % item)

    en_name = None
    for n in sections:
        if n.lower() in ("en", "english"):
            en_name = n
            break
    if not en_name:
        p("NO EN")
        continue
    en = sections[en_name]
    all_keys = set()
    for s in sections.values():
        all_keys |= set(s.keys())
    miss_en = sorted(all_keys - set(en.keys()))
    p("MISSING IN EN: %d" % len(miss_en))
    for k in miss_en:
        owners = [n for n in sections if k in sections[n]]
        sample = sections[owners[0]][k][0][:120]
        p("  %s from %s :: %s" % (k, ",".join(owners), sample))

    p("CJK IN EN:")
    n_cjk = 0
    for k, (v, i) in en.items():
        if cjk.search(v):
            n_cjk += 1
            p("  L%d %s = %s" % (i, k, v[:140]))
    p("  count %d" % n_cjk)

    cn_names = [n for n in sections if n.lower() in ("cn", "zh", "schinese")]
    for cn in cn_names:
        miss = sorted(set(en.keys()) - set(sections[cn].keys()))
        extra = sorted(set(sections[cn].keys()) - set(en.keys()))
        p("EN not in %s: %d" % (cn, len(miss)))
        for k in miss:
            p("  %s = %s" % (k, en[k][0][:100]))
        p("%s not in EN: %d" % (cn, len(extra)))

        bad = []
        for k in set(en) & set(sections[cn]):
            a = specs(sections[cn][k][0])
            b = specs(en[k][0])
            if sorted(a) != sorted(b):
                bad.append((k, a, b))
        p("SPEC MISMATCH %s vs en: %d" % (cn, len(bad)))
        for k, a, b in bad:
            p("  %s cn=%s en=%s" % (k, a, b))
            p("    CN %s" % sections[cn][k][0][:100])
            p("    EN %s" % en[k][0][:100])

        same = []
        for k in set(en) & set(sections[cn]):
            cv, ev = sections[cn][k][0], en[k][0]
            if cv == ev and (cjk.search(cv) or (len(cv) > 18 and re.search(r"[A-Za-z]{5}", cv))):
                same.append(k)
        p("IDENTICAL %s==en: %d" % (cn, len(same)))
        for k in same:
            p("  %s = %s" % (k, en[k][0][:100]))

    # tw vs cn: traditional section still simplified, or missing
    tw_names = [n for n in sections if n.lower() in ("tw", "zh-tw", "zh_tw")]
    for tw in tw_names:
        miss = sorted((set(en.keys()) | set(sections.get(cn_names[0], {}).keys()) if cn_names else set(en.keys())) - set(sections[tw].keys()))
        p("missing in %s vs union: %d" % (tw, len(miss)))
        for k in miss[:80]:
            p("  %s" % k)
        # tw value equals cn and contains chars that should differ? just list if tw == cn and has CJK and length>8
        if cn_names:
            cn = cn_names[0]
            eq = []
            for k in set(sections[tw]) & set(sections[cn]):
                if sections[tw][k][0] == sections[cn][k][0] and cjk.search(sections[cn][k][0]) and len(sections[cn][k][0]) > 6:
                    eq.append(k)
            p("TW identical to CN (maybe not converted): %d" % len(eq))
            for k in eq[:50]:
                p("  %s = %s" % (k, sections[cn][k][0][:80]))

    # ru missing
    ru_names = [n for n in sections if n.lower() == "ru"]
    for ru in ru_names:
        base = set(en.keys())
        miss = sorted(base - set(sections[ru].keys()))
        p("EN not in ru: %d" % len(miss))
        for k in miss[:40]:
            p("  %s" % k)

with open(OUT, "w", encoding="utf-8") as f:
    f.write("\n".join(lines))
print("wrote", OUT, "lines", len(lines))
