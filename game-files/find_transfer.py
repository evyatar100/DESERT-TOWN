import zlib
from rubymarshal.reader import load

with open("Data/Scripts.rxdata", "rb") as f:
    scripts = load(f)

for idx, s in enumerate(scripts):
    name = s[1].decode('utf-8', errors='ignore') if isinstance(s[1], bytes) else s[1]
    code = zlib.decompress(s[2]).decode('utf-8', errors='ignore')
    if 'def pbTransferPlayer' in code:
        print(f"[{name}] Found def pbTransferPlayer:")
        for line in code.splitlines():
            if 'def pbTransferPlayer' in line:
                print("  ", line.strip())
        pos = code.find("def pbTransferPlayer")
        print(code[pos:pos+400])
