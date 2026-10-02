# -*- coding: utf-8 -*-
from pathlib import Path

p = Path(r"c:\Users\Administrator\Desktop\gtr\source\HnsAISignup.sma")
data = p.read_bytes()
print("size", len(data))
print("crlf", data.count(b"\r\n"), "lf", data.count(b"\n"))

markers = [
    b"}CLOSE",
    b"showGroups(0/",
    b"GE_WAIT",
    b"startPlacingOneByOnert",
    b"startPlacingOneByOne",
    b"shouldBlockGameMenu",
    b"beginPostGroupSetup",
    b"taskPendingResume",
    b"taskSignupHud",
]
text = data.decode("utf-8", errors="replace")
for s in markers:
    i = data.find(s)
    print(repr(s), i)

print("---- snippets ----")
for needle in ["}CLOSE", "GE_WAIT", "startPlacingOneByOnert", "换图前不拉", "showGroups(0/"]:
    i = text.find(needle)
    print("NEEDLE", needle, "at", i)
    if i >= 0:
        print(text[max(0, i-120):i+180])
        print("====")
