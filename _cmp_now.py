import hashlib
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path("game-files").resolve()))
from tests.event_catalog import extract_map
from tests.rx_loader import load_rxdata

GIT = r"C:\Users\shira\AppData\Local\GitHubDesktop\app-3.6.7\resources\app\git\cmd\git.exe"

remote = subprocess.check_output(
    [GIT, "show", "origin/main:game-files/Graphics/Characters/dt_931c4ae6.png"]
)
local = Path("game-files/Graphics/Characters/dt_931c4ae6.png").read_bytes()
print("png local", len(local), hashlib.sha256(local).hexdigest())
print("png remote", len(remote), hashlib.sha256(remote).hexdigest())
print("png same", local == remote)

head = subprocess.check_output([GIT, "show", "HEAD:game-files/Data/Map089.rxdata"])
tmp = Path("_tmp_map089_head.rxdata")
tmp.write_bytes(head)
head_map = extract_map(load_rxdata(tmp), 89)
work_map = extract_map(load_rxdata(Path("game-files/Data/Map089.rxdata")), 89)
tmp.unlink(missing_ok=True)


def index(extracted):
    return {e["id"]: e for e in extracted["events"]}


h = index(head_map)
w = index(work_map)
print("head", len(h), "work", len(w))
for eid in sorted(set(h) | set(w)):
    a = h.get(eid)
    b = w.get(eid)
    if a is None:
        print("add", eid, b["name"], b["x"], b["y"])
    elif b is None:
        print("del", eid, a["name"], a["x"], a["y"])
    elif (a["name"], a["x"], a["y"], a["pages"]) != (b["name"], b["x"], b["y"], b["pages"]):
        print("chg", eid, a["name"], (a["x"], a["y"]), "->", b["name"], (b["x"], b["y"]))
