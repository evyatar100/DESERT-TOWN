"""Render any non-autotile-heavy Desert Town map layers (same method as kit.render_map)."""
import os
import kit
from rx_loader import load_rxdata
from PIL import Image

def render(map_id):
    m = load_rxdata(os.path.join(kit.GF, "Data", "Map%03d.rxdata" % map_id)); a = m.attributes
    xs, ys, zs, v = kit._table(a["@data"])
    ts = load_rxdata(os.path.join(kit.GF, "Data", "Tilesets.rxdata"))[a["@tileset_id"]].attributes
    nm = ts["@tileset_name"].decode()
    pri = kit._table(ts["@priorities"])[3]
    img = Image.open(os.path.join(kit.GF, "Graphics", "Tilesets", nm + ".png")).convert("RGBA")
    c = Image.new("RGBA", (xs * 32, ys * 32), (0, 0, 0, 255))
    over = []
    for z in range(3):
        for y in range(ys):
            for x in range(xs):
                t = v[x + y * xs + z * xs * ys]
                if t >= 384:
                    c.alpha_composite(kit._tile(img, t), (x * 32, y * 32))
    return c

if __name__ == "__main__":
    import sys
    r = render(int(sys.argv[1])); r.save(sys.argv[2]); print(r.size)
