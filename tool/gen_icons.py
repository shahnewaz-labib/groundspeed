#!/usr/bin/env python3
"""Generates Groundspeed launcher icons (Android all densities + adaptive
foreground + iOS single-size) from one vector-ish composition."""
import math
import os
from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(__file__), "..")
RES = os.path.join(ROOT, "android", "app", "src", "main", "res")
IOS = os.path.join(
    ROOT, "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset"
)

BG = (10, 12, 15, 255)          # #0A0C0F
TEAL = (70, 230, 195)           # #46E6C3
PALE = (234, 255, 250)
INK = (242, 244, 246)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(4))


def draw_glyph(img, scale=1.0, offset=(0, 0)):
    """Draws gauge arc + needle + hub on a 1024 canvas, scaled about center."""
    d = ImageDraw.Draw(img)
    cx = cy = 512
    cx += offset[0]
    cy += offset[1]

    def pt(angle_deg, r):
        rad = math.radians(angle_deg - 90)
        return (cx + r * math.cos(rad), cy + r * math.sin(rad))

    R = int(340 * scale)

    # Gradient gauge arc: 135° -> 405° (compass), drawn as 90 segments.
    segs = 90
    start, sweep = 135, 270
    w = max(2, int(52 * scale))
    for i in range(segs):
        a0 = start + sweep * i / segs
        a1 = start + sweep * (i + 1) / segs + 0.6
        t = i / (segs - 1)
        col = lerp((43, 169, 143, 255), PALE + (255,), t ** 1.25)
        d.arc(
            [cx - R, cy - R, cx + R, cy + R],
            start=a0 - 90, end=a1 - 90, fill=col, width=w,
        )

    # Ticks every 45° inside the arc.
    for deg in range(135, 406, 45):
        p_in = pt(deg, R - int(46 * scale))
        p_out = pt(deg, R - int(20 * scale))
        d.line([p_in, p_out], fill=INK + (70,), width=max(2, int(7 * scale)))

    # Needle pointing at ~62° compass.
    ndeg = 62
    tip = pt(ndeg, R - int(64 * scale))
    tail_a = pt(ndeg + 180 + 5, int(56 * scale))
    tail_b = pt(ndeg + 180 - 5, int(56 * scale))
    side_a = pt(ndeg + 6, R - int(120 * scale))
    side_b = pt(ndeg - 6, R - int(120 * scale))
    d.polygon(
        [tip, side_a, tail_a, tail_b, side_b],
        fill=PALE + (255,),
    )

    # Hub.
    hub = int(46 * scale)
    d.ellipse(
        [cx - hub, cy - hub, cx + hub, cy + hub],
        fill=BG,
        outline=TEAL + (255,),
        width=max(2, int(10 * scale)),
    )
    dot = int(10 * scale)
    d.ellipse([cx - dot, cy - dot, cx + dot, cy + dot], fill=TEAL + (255,))
    return img


def master_background(size=1024):
    img = Image.new("RGBA", (size, size), BG)
    # Faint radial teal glow behind glyph.
    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    steps = 60
    for i in range(steps, 0, -1):
        r = int(size * 0.62 * i / steps)
        alpha = int(26 * (1 - i / steps) ** 1.6)
        gd.ellipse(
            [512 - r, 512 - r + int(size * 0.06),
             512 + r, 512 + r + int(size * 0.06)],
            fill=(70, 230, 195, alpha),
        )
    img.alpha_composite(glow)
    return img


def make_icon():
    img = master_background()
    draw_glyph(img)
    return img.convert("RGB")


def make_foreground():
    img = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    # Glyph occupies ~55% of canvas so it survives adaptive-icon masking.
    small = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    draw_glyph(small, scale=0.55)
    img.alpha_composite(small)
    return img


def save_resized(img, path, size):
    out = img.resize((size, size), Image.LANCZOS)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if path.endswith(".png"):
        out.save(path, "PNG")
    else:
        out.save(path)


def main():
    icon = make_icon()
    fg = make_foreground()

    densities = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    for folder, size in densities.items():
        save_resized(icon, f"{RES}/{folder}/ic_launcher.png", size)
        save_resized(icon, f"{RES}/{folder}/ic_launcher_round.png", size)

    fg_sizes = {
        "mipmap-mdpi": 108,
        "mipmap-hdpi": 162,
        "mipmap-xhdpi": 216,
        "mipmap-xxhdpi": 324,
        "mipmap-xxxhdpi": 432,
    }
    for folder, size in fg_sizes.items():
        save_resized(fg, f"{RES}/{folder}/ic_launcher_foreground.png", size)

    os.makedirs(IOS, exist_ok=True)
    save_resized(icon, f"{IOS}/icon_1024.png", 1024)

    print("icons written")


if __name__ == "__main__":
    main()
