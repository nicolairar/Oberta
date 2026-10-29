"""Contact sheets of the skins walk screenshots, for review.

    python3 tool/audit/walk_sheets.py build/audit/walk/nadia

writes <dir>/sheets/<group>_<n>.png: the shop steps cropped to the part of
the phone that changes (the hero, the price tag and the dial), the barber
steps to the mirror and the options, each labelled with its step.
"""
import os
import sys

from PIL import Image, ImageDraw

src = sys.argv[1]
out = os.path.join(src, 'sheets')
os.makedirs(out, exist_ok=True)
names = sorted(n for n in os.listdir(src) if n.endswith('.png'))

# In logical points of the 393x852 phone (the shots are at dpr 3).
crops = {
    'shop': (0, 150, 393, 760),
    'barber': (0, 90, 393, 852),
    'full': (0, 0, 393, 852),
}


def kind(name):
    step = name.split('_', 1)[1]
    if step.startswith(('hats_', 'face_', 'buy_', 'worn_')):
        return 'shop'
    if step.startswith('barber_'):
        return 'barber'
    return 'full'


groups = {}
for n in names:
    k = kind(n)
    step = n.split('_', 1)[1]
    g = step.split('_')[0] + ('_' + step.split('_')[1] if step.startswith(('hats_', 'face_')) else '')
    groups.setdefault((k, g), []).append(n)

for (k, g), files in groups.items():
    box = crops[k]
    scale = 0.55 if k != 'full' else 0.42
    cw, ch = int((box[2] - box[0]) * 3 * scale), int((box[3] - box[1]) * 3 * scale)
    cols = 6 if k != 'full' else 4
    per = cols * (2 if k != 'barber' else 2)
    for start in range(0, len(files), per):
        chunk = files[start:start + per]
        rows = (len(chunk) + cols - 1) // cols
        sheet = Image.new('RGB', (cols * (cw + 6) + 6, rows * (ch + 26) + 6), (20, 17, 15))
        d = ImageDraw.Draw(sheet)
        for i, f in enumerate(chunk):
            im = Image.open(os.path.join(src, f)).convert('RGB')
            im = im.crop(tuple(v * 3 for v in box)).resize((cw, ch), Image.LANCZOS)
            x, y = 6 + (i % cols) * (cw + 6), 6 + (i // cols) * (ch + 26)
            sheet.paste(im, (x, y + 20))
            d.text((x, y + 4), f[:-4][:48], fill=(242, 213, 138))
        sheet.save(os.path.join(out, '%s_%02d.png' % (g, start // per + 1)))
print(len(os.listdir(out)), 'sheets in', out)
