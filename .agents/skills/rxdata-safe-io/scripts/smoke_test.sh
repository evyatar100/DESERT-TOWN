#!/bin/sh
# Exercise every rxdata_io command on a temp copy of Map095; the real map is only read.
set -u
export PATH="/c/Ruby31-x64/bin:$PATH"
S="${TMPDIR:-/tmp}/rx_smoke_$$"
D=$(cd "$(dirname "$0")" && pwd); R="$D/rxdata_io.rb"; ROOT=$(cd "$D/../../../.." && pwd)
rm -rf "$S"; mkdir -p "$S/proj"
cp "$ROOT"/game-files/Data/Map095.rxdata "$S/m.rxdata"
M="$S/m.rxdata"
ok=0; bad=0
chk() { if [ "$1" -eq "$2" ]; then ok=$((ok+1)); echo "PASS $3"; else bad=$((bad+1)); echo "FAIL $3 (exit $1, want $2)"; fi; }

printf '%s' '[{"id":90,"name":"t90","x":1,"y":1,"graphic":"","talk":"abc123","switch1":7},{"id":91,"name":"t91","x":2,"y":1,"route":[[1,[]],[15,[6]]],"move_type":3}]' > "$S/add.json"
ruby $R add "$M" --spec "$S/add.json" --scratch-copy; chk $? 0 "add multi + switch1 + route"
ruby $R dump "$M" | grep -q '"switch1_id": 7'; chk $? 0 "switch1 persisted"
printf '%s' '{"commands":[{"code":101,"parameters":["MSG_A"]},{"code":102,"parameters":[["Yes","No"],2]}]}' > "$S/list.json"
ruby $R set-list "$M" --id 90 --page 1 --spec "$S/list.json" --dry-run --scratch-copy; chk $? 0 "set-list dry-run"
ruby $R set-list "$M" --id 90 --page 1 --spec "$S/list.json" --scratch-copy; chk $? 0 "set-list write"
ruby $R set-list "$M" --id 90 --page 2 --spec "$S/list.json" --scratch-copy 2>/dev/null; chk $? 2 "set-list missing page refused"
ruby $R set-move "$M" --id 90 --id 91 --move-type 1 --scratch-copy; chk $? 0 "set-move two ids"
ruby $R set-move "$M" --id 90 --move-type 9 --scratch-copy 2>/dev/null; chk $? 2 "set-move bad type refused"
printf '%s' '{"events":[{"id":90,"graphic":"dt_x","replace_text":{"MSG_A":"MSG_B"}}]}' > "$S/rt.json"
ruby $R retarget "$M" --spec "$S/rt.json" --scratch-copy; chk $? 0 "retarget"
ruby $R dump "$M" | grep -q 'MSG_B'; chk $? 0 "retarget text replaced"
ruby $R move "$M" --id 91 --x 1 --y 1 --scratch-copy 2>/dev/null; chk $? 2 "move onto taken tile refused"
ruby $R move "$M" --id 91 --x 3 --y 1 --scratch-copy; chk $? 0 "move"
ruby $R delete "$M" --id 91 --scratch-copy; chk $? 0 "delete"
ruby $R add "$M" --spec "$S/add.json" --scratch-copy 2>/dev/null; chk $? 2 "duplicate id refused"
ls "$S"/m.rxdata.bak* >/dev/null 2>&1; chk $? 0 "backups written"
ruby $R verify "$M"; chk $? 0 "verify scratch"
cp "$M" "$S/proj/m.rxdata"; : > "$S/proj/Game.ini"
ruby $R delete "$S/proj/m.rxdata" --id 90 --scratch-copy 2>/dev/null; chk $? 2 "scratch-copy next to Game.ini refused"
echo "rx_smoke: $ok passed, $bad failed"
rm -rf "$S"
[ "$bad" -eq 0 ]
