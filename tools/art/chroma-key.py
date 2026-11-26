"""Key out flat green to transparency, crop to the object, pad and resize to 256 px."""
import sys
from PIL import Image

src, dst = sys.argv[1], sys.argv[2]
im = Image.open(src).convert("RGB")
out = []
for r, g, b in im.getdata():
    excess = g - max(r, b)
    a = min(1.0, max(0.0, (90 - excess) / 50))
    if a < 1: g = min(g, max(r, b))  # remove green spill on soft edges
    out.append((r, g, b, int(a * 255)))
img = Image.new("RGBA", im.size); img.putdata(out)
box = img.getchannel("A").point(lambda v: 255 if v > 24 else 0).getbbox()
img = img.crop(box)
side = int(max(img.size) / 0.9)
canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
canvas.paste(img, ((side - img.width) // 2, (side - img.height) // 2))
canvas.resize((256, 256), Image.LANCZOS).save(dst)
