#!/usr/bin/env python3
"""Draws the app icon and splash mark for Spenn/TAUT (no text, so it reads
in both languages): a jelly ring hanging from a steel rail on a taut
string, its eye on the gold ball rising toward it. Rendered 4x and
downsampled for clean edges. Writes Android adaptive layers, the legacy
192 px icon, the project icon and the boot splash image into icons/.

    python3 tools/make_icons.py
"""

import os

from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "icons")
BG = (14, 16, 21)
LIFT = (30, 34, 44)
BLUE = (79, 139, 255)
BLUE_DARK = (40, 76, 150)
GOLD = (212, 169, 79)
GOLD_LIGHT = (240, 206, 140)
GOLD_DARK = (143, 107, 44)
METAL = (105, 113, 126)
EYE = (228, 231, 236)
PUPIL = (18, 20, 26)


def background(n):
    """Dark wall, lifted toward the upper left like the game's lamp."""
    im = Image.new("RGB", (n, n), BG)
    glow = Image.new("L", (n, n), 0)
    ImageDraw.Draw(glow).ellipse((-n * 0.3, -n * 0.45, n * 0.9, n * 0.75), fill=255)
    glow = glow.filter(ImageFilter.GaussianBlur(n * 0.18))
    lift = Image.new("RGB", (n, n), LIFT)
    return Image.composite(lift, im, glow)


def mark(n, scale=1.0):
    """The emblem on a transparent layer, centred, `scale` of the canvas."""
    im = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    s = n * scale
    cx = n / 2
    top = n / 2 - s * 0.42
    # Rail.
    d.rounded_rectangle((cx - s * 0.36, top - s * 0.03, cx + s * 0.36, top + s * 0.03), s * 0.02, fill=METAL)
    # String and ring.
    ry = n / 2 - s * 0.02
    r = s * 0.2
    d.line((cx, top + s * 0.02, cx, ry - r), fill=(120, 160, 230), width=max(2, int(s * 0.018)))
    shadow = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).ellipse((cx - r + s * 0.03, ry - r + s * 0.04, cx + r + s * 0.03, ry + r + s * 0.04), fill=(0, 0, 0, 120))
    im = Image.alpha_composite(im, shadow.filter(ImageFilter.GaussianBlur(s * 0.02)))
    d = ImageDraw.Draw(im)
    tube = s * 0.075
    d.ellipse((cx - r, ry - r, cx + r, ry + r), fill=BLUE)
    d.ellipse((cx - r + tube, ry - r + tube, cx + r - tube, ry + r - tube), fill=BLUE_DARK)
    # Rim light on the upper left of the tube.
    d.arc((cx - r + tube * 0.25, ry - r + tube * 0.25, cx + r - tube * 0.25, ry + r - tube * 0.25), 190, 260, fill=(170, 200, 255), width=max(2, int(tube * 0.35)))
    # Eye, looking down-right at the ball.
    er = s * 0.075
    d.ellipse((cx - er, ry - er, cx + er, ry + er), fill=EYE)
    pr = er * 0.5
    px, py = cx + er * 0.32, ry + er * 0.32
    d.ellipse((px - pr, py - pr, px + pr, py + pr), fill=PUPIL)
    # The gold ball, rising in from the lower right, with a short trail.
    bx, by, br = cx + s * 0.2, n / 2 + s * 0.33, s * 0.085
    trail = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    td = ImageDraw.Draw(trail)
    for i in range(5, 0, -1):
        tr = br * (1 - 0.14 * i)
        tx, ty = bx + s * 0.04 * i, by + s * 0.055 * i
        td.ellipse((tx - tr, ty - tr, tx + tr, ty + tr), fill=GOLD + (int(70 * (1 - i / 6)),))
    im = Image.alpha_composite(im, trail.filter(ImageFilter.GaussianBlur(s * 0.01)))
    d = ImageDraw.Draw(im)
    d.ellipse((bx - br, by - br, bx + br, by + br), fill=GOLD_DARK)
    d.ellipse((bx - br * 0.9 - br * 0.1, by - br * 0.9 - br * 0.1, bx + br * 0.8, by + br * 0.8), fill=GOLD)
    hr = br * 0.32
    d.ellipse((bx - br * 0.45 - hr, by - br * 0.45 - hr, bx - br * 0.45 + hr, by - br * 0.45 + hr), fill=GOLD_LIGHT)
    return im


def save(img, name, size):
    img.resize((size, size), Image.LANCZOS).save(os.path.join(OUT, name), optimize=True)


def main():
    os.makedirs(OUT, exist_ok=True)
    big = 1728  # 4x of 432
    # Adaptive: the foreground keeps inside the central 66 % safe zone.
    save(mark(big, 0.62), "icon_foreground.png", 432)
    save(background(big), "icon_background.png", 432)
    full = background(big).convert("RGBA")
    full = Image.alpha_composite(full, mark(big, 0.8))
    save(full, "icon.png", 512)
    save(full, "icon_192.png", 192)
    # Splash: the mark alone, on the boot colour.
    splash = Image.new("RGBA", (big, big), BG + (255,))
    splash = Image.alpha_composite(splash, mark(big, 0.5))
    save(splash, "splash.png", 512)


if __name__ == "__main__":
    main()
