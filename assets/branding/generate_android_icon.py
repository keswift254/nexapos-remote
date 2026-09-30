"""Generate the NexaPOS receipt launcher icon in Android density sizes."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
SIZE = 1024

background = Image.new('RGB', (SIZE, SIZE))
pixels = background.load()
for y in range(SIZE):
    for x in range(SIZE):
        t = 0.55 * x / SIZE + 0.45 * y / SIZE
        pixels[x, y] = tuple(round(a * (1 - t) + b * t) for a, b in zip((86, 77, 234), (42, 43, 130)))

art = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
shadow = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
d = ImageDraw.Draw(shadow)
receipt = [(255, 176), (769, 176), (769, 756), (724, 801),
           (680, 756), (636, 801), (592, 756), (548, 801),
           (504, 756), (460, 801), (416, 756), (372, 801),
           (328, 756), (284, 801), (255, 772)]
d.polygon([(x + 12, y + 22) for x, y in receipt], fill=(11, 15, 67, 96))
shadow = shadow.filter(ImageFilter.GaussianBlur(26))
art.alpha_composite(shadow)

page = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
d = ImageDraw.Draw(page)
d.polygon(receipt, fill=(255, 255, 255, 255))
d.rounded_rectangle((255, 176, 769, 788), radius=66, fill='white')
# Keep the zigzag receipt edge crisp after rounding the upper corners.
d.polygon(receipt[2:], fill='white')

ink = (66, 60, 177, 255)
d.line([(371, 548), (371, 315), (649, 548), (649, 315)], fill=ink, width=65, joint='curve')
for center in [(371, 315), (371, 548), (649, 548), (649, 315)]:
    r = 32
    d.ellipse((center[0]-r, center[1]-r, center[0]+r, center[1]+r), fill=ink)
d.rounded_rectangle((366, 638, 650, 665), radius=14, fill=(90, 94, 181, 255))
d.rounded_rectangle((366, 696, 559, 723), radius=14, fill=(44, 181, 218, 255))
art.alpha_composite(page)

base = background.convert('RGBA')
base.alpha_composite(art)
for density, size in [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192)]:
    target = ROOT / f'android/app/src/main/res/mipmap-{density}/ic_launcher.png'
    base.resize((size, size), Image.Resampling.LANCZOS).save(target, optimize=True)
base.resize((512, 512), Image.Resampling.LANCZOS).save(ROOT / 'assets/branding/android-icon-preview.png', optimize=True)
