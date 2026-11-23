# Draws the Blobby app icon (1024x1024, opaque) — a happy water-blob mascot on a sunny background.
import math
from PIL import Image, ImageDraw, ImageFilter

S = 2048                      # supersample, downscale at the end for smooth edges
INK = (34, 34, 51)
img = Image.new("RGB", (S, S))
d = ImageDraw.Draw(img)

# Background: vertical warm gradient
top, bot = (255, 214, 92), (255, 168, 72)
for y in range(S):
    k = y / S
    d.line([(0, y), (S, y)], fill=tuple(int(top[i] * (1 - k) + bot[i] * k) for i in range(3)))

# Soft background circles
glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
g = ImageDraw.Draw(glow)
for (cx, cy, r, a) in [(330, 360, 260, 70), (1750, 520, 200, 60), (1650, 1750, 330, 55), (260, 1700, 180, 60)]:
    g.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(255, 245, 220, a))
img.paste(glow, (0, 0), glow)

def blob_points(cx, cy, rx, ry, n=360):
    pts = []
    for i in range(n):
        a = i / n * 2 * math.pi
        w = 1 + 0.03 * math.sin(a * 3 + 0.8) + 0.02 * math.sin(a * 2 - 0.4)
        s = math.sin(a)
        ys = (s ** 0.75) if s > 0 else s
        pts.append((cx + math.cos(a) * w * rx, cy + ys * w * ry))
    return pts

cx, cy, rx, ry = S * 0.5, S * 0.55, S * 0.36, S * 0.33
body = blob_points(cx, cy, rx, ry)

# Ground shadow
sh = Image.new("RGBA", (S, S), (0, 0, 0, 0))
ImageDraw.Draw(sh).ellipse([cx - rx * 0.85, cy + ry * 1.02, cx + rx * 0.85, cy + ry * 1.18], fill=(120, 60, 0, 70))
sh = sh.filter(ImageFilter.GaussianBlur(18))
img.paste(sh, (0, 0), sh)

# Body mask
mask = Image.new("L", (S, S), 0)
ImageDraw.Draw(mask).polygon(body, fill=255)

# Fill layers: light body + water with wave + bubbles
layer = Image.new("RGB", (S, S), (224, 238, 255))
ld = ImageDraw.Draw(layer)
level = cy - ry * 0.05
def wave(y0, amp, phase):
    pts = [(0, S)]
    for x in range(0, S + 1, 8):
        pts.append((x, y0 + amp * math.sin(x / S * 2 * math.pi * 1.6 + phase)))
    pts.append((S, S))
    return pts
ld.polygon(wave(level - 30, 34, 1.7), fill=(150, 196, 250))
# deep water gradient
water = Image.new("RGB", (S, S))
wd = ImageDraw.Draw(water)
c1, c2 = (64, 148, 250), (26, 82, 178)
for y in range(S):
    k = min(max((y - level) / (cy + ry - level), 0), 1)
    wd.line([(0, y), (S, y)], fill=tuple(int(c1[i] * (1 - k) + c2[i] * k) for i in range(3)))
wmask = Image.new("L", (S, S), 0)
ImageDraw.Draw(wmask).polygon(wave(level, 40, 0.3), fill=255)
layer.paste(water, (0, 0), wmask)
for (bx, by, br) in [(0.36, 0.74, 26), (0.44, 0.80, 18), (0.60, 0.70, 22), (0.66, 0.78, 30), (0.52, 0.66, 14)]:
    ld.ellipse([S * bx - br, S * by - br, S * bx + br, S * by + br], outline=(235, 245, 255), width=7, fill=(110, 170, 250))
img.paste(layer, (0, 0), mask)

# Gloss highlight
gl = Image.new("RGBA", (S, S), (0, 0, 0, 0))
ImageDraw.Draw(gl).ellipse([cx - rx * 0.78, cy - ry * 0.72, cx - rx * 0.52, cy - ry * 0.18], fill=(255, 255, 255, 150))
gl = gl.rotate(28, center=(cx - rx * 0.65, cy - ry * 0.45))
img.paste(gl, (0, 0), gl)

d = ImageDraw.Draw(img)
d.line(body + [body[0]], fill=INK, width=44, joint="curve")

# Face: happy closed "^" eyes, open smile, cheeks
ey = cy - ry * 0.28
for ex in (cx - rx * 0.32, cx + rx * 0.32):
    d.arc([ex - 80, ey - 40, ex + 80, ey + 110], start=200, end=340, fill=INK, width=36)
# open mouth
my = cy + ry * 0.05
mouth = [cx - 150, my - 60, cx + 150, my + 170]
d.chord(mouth, start=0, end=180, fill=INK)
d.ellipse([cx - 70, my + 60, cx + 70, my + 150], fill=(255, 112, 130))
d.chord(mouth, start=0, end=180, outline=INK, width=10)
for chx in (cx - rx * 0.62, cx + rx * 0.62):
    d.ellipse([chx - 70, my - 40, chx + 70, my + 20], fill=(255, 150, 170))

# Little sparkle
def star(x, y, r):
    pts = []
    for i in range(8):
        a = i * math.pi / 4
        rr = r if i % 2 == 0 else r * 0.32
        pts.append((x + rr * math.sin(a), y - rr * math.cos(a)))
    d.polygon(pts, fill=(255, 255, 255), outline=INK, width=14)
star(S * 0.80, S * 0.22, 120)
star(S * 0.17, S * 0.36, 70)

out = img.resize((1024, 1024), Image.LANCZOS)
out.save("/home/claude/icon/AppIcon.png")
out.resize((256, 256), Image.LANCZOS).save("/home/claude/icon/preview.png")
print("ok")
