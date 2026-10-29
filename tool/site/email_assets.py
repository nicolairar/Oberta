"""Images for the waitlist email (site/oberta/email/), from the repo's own art.

    python3 tool/site/email_assets.py

- oberta-neon.jpg: the Steam neon logo, glow feathered, on the card's colour.
- brick.jpg: a dark brick wall, tileable, for the background behind the card.
- deco-*.png: brass art-deco corners for the card (transparent).
- role-*.png: four role medallions, 112 px (shown at 56).
Needs Pillow.
"""
import pathlib
import random

from PIL import Image, ImageChops, ImageDraw, ImageFilter

root = pathlib.Path(__file__).resolve().parents[2]
out = root / 'site/oberta/email'
out.mkdir(parents=True, exist_ok=True)
INK = (12, 9, 7)
CARD = (19, 14, 11)  # the card's #130e0b, so the sign has no box around it


def neon():
    im = Image.open(root / 'steam/store/art/library_logo_1280x720.png').convert('RGBA').crop((0, 91, 1280, 703))
    W, H = 1440, 700
    canvas = Image.new('RGBA', (W, H), CARD + (255,))
    mask = Image.new('L', im.size, 0)
    mask.paste(Image.new('L', (im.width - 120, im.height - 80), 255), (60, 40))
    mask = mask.filter(ImageFilter.GaussianBlur(40))
    im.putalpha(ImageChops.multiply(im.split()[3], mask))
    canvas.alpha_composite(im, ((W - im.width) // 2, (H - im.height) // 2))
    canvas.convert('RGB').resize((1040, round(H * 1040 / W)), Image.LANCZOS).save(
        out / 'oberta-neon.jpg', quality=82, optimize=True, progressive=True)


def brick():
    rnd = random.Random(7)
    S, bw, bh, gap = 480, 120, 40, 4
    im = Image.new('RGB', (S, S), (16, 11, 9))
    d = ImageDraw.Draw(im)
    for row in range(S // bh):
        off = (bw // 2) * (row % 2)
        for col in range(-1, S // bw + 1):
            x = col * bw + off
            base = rnd.randint(40, 56)
            colour = (base + rnd.randint(6, 14), base // 2 + rnd.randint(2, 6), base // 3)
            for dx in (0, S, -S):  # wrap so the tile repeats
                d.rectangle((x + dx + gap // 2, row * bh + gap // 2, x + dx + bw - gap // 2, row * bh + bh - gap // 2), fill=colour)
    noise = Image.effect_noise((S, S), 22).convert('RGB')
    im = ImageChops.add(im, noise, scale=2.0, offset=-64)
    im = im.filter(ImageFilter.GaussianBlur(0.6))
    im.save(out / 'brick.jpg', quality=70, optimize=True, progressive=True)


def deco():
    S = 96
    im = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    gold, dim = (217, 180, 90, 255), (156, 116, 36, 255)
    # Stepped art-deco corner: two L rules and a small diamond.
    d.line([(6, S - 6), (6, 6), (S - 6, 6)], fill=gold, width=4)
    d.line([(18, S - 18), (18, 18), (S - 18, 18)], fill=dim, width=2)
    d.line([(18, 34), (34, 34), (34, 18)], fill=gold, width=2)
    d.polygon([(26, 44), (30, 48), (26, 52), (22, 48)], fill=gold)
    d.polygon([(44, 26), (48, 30), (52, 26), (48, 22)], fill=gold)
    for name, t in (('tl', None), ('tr', Image.FLIP_LEFT_RIGHT), ('bl', Image.FLIP_TOP_BOTTOM), ('br', Image.ROTATE_180)):
        (im if t is None else im.transpose(t)).save(out / f'deco-{name}.png', optimize=True)


def roles():
    for role in ('padrino', 'detective', 'medico', 'mafioso'):
        im = Image.open(root / f'site/oberta/img/roles/{role}.png').convert('RGBA').resize((112, 112), Image.LANCZOS)
        im.save(out / f'role-{role}.png', optimize=True)


if __name__ == '__main__':
    neon()
    brick()
    deco()
    roles()
