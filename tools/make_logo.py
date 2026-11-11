"""Dibuja el logo de HunterGod: el de CurseForge (512x512 PNG) y el icono del minimapa (64x64 TGA).

Uso: python -I make_logo.py <logo.png> <icono.tga>
Necesita: pip install pillow
"""
import math
import sys

from PIL import Image, ImageDraw, ImageFilter

S = 2048  # se dibuja grande y se reduce para suavizar bordes
C = S / 2

GOLD = (240, 192, 80, 255)
GOLD_DARK = (150, 100, 25, 255)
WOOD = (122, 74, 34, 255)
WOOD_LIGHT = (182, 124, 62, 255)
STRING = (236, 228, 205, 255)
SHAFT = (216, 192, 138, 255)
STEEL = (232, 234, 242, 255)
GREEN = (171, 212, 115, 255)
OUTLINE = (20, 26, 14, 255)


def rot(points, ang, ox, oy):
    c, s = math.cos(ang), math.sin(ang)
    return [(ox + x * c - y * s, oy + x * s + y * c) for x, y in points]


def background():
    # Cuadrado redondeado verde con un brillo en el centro
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    glow = Image.new("RGBA", (S, S), (20, 32, 16, 255))
    g = ImageDraw.Draw(glow)
    for i in range(60, 0, -1):
        r = C * 1.45 * i / 60
        t = 1 - i / 60
        col = (int(20 + 44 * t), int(32 + 62 * t), int(16 + 28 * t), 255)
        g.ellipse((C - r, C - r, C + r, C + r), fill=col)
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, S - 1, S - 1), radius=380, fill=255)
    img.paste(glow, (0, 0), mask)
    return img


def rays(img):
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    n = 24
    for i in range(n):
        a = 2 * math.pi * i / n
        long = i % 2 == 0
        r0, r1 = 560, 1000 if long else 860
        half = math.radians(3.2 if long else 2.2)
        d.polygon([(C + r0 * math.cos(a - half), C + r0 * math.sin(a - half)),
                   (C + r1 * math.cos(a), C + r1 * math.sin(a)),
                   (C + r0 * math.cos(a + half), C + r0 * math.sin(a + half))],
                  fill=(240, 192, 80, 120 if long else 80))
    img.alpha_composite(layer.filter(ImageFilter.GaussianBlur(3)))


def halo(img):
    d = ImageDraw.Draw(img)
    r = 600
    d.ellipse((C - r - 22, C - r - 22, C + r + 22, C + r + 22), outline=OUTLINE, width=100)
    d.ellipse((C - r, C - r, C + r, C + r), outline=GOLD_DARK, width=56)
    d.ellipse((C - r + 8, C - r + 8, C + r - 8, C + r - 8), outline=GOLD, width=34)


def bow_and_arrow(img):
    d = ImageDraw.Draw(img)
    ang = -math.pi / 4  # la flecha apunta arriba a la derecha
    ox, oy = C - 40, C + 40
    L, G, P = 720, 300, 250  # media altura del arco, curva del arco, cuánto se tensa la cuerda

    def limb_x(s):
        x = G * (1 - s * s) ** 0.85
        a = abs(s)
        if a > 0.82:  # las puntas se curvan hacia delante
            x += 150 * ((a - 0.82) / 0.18) ** 2
        return x

    # Cuerda tensada hasta el culatín de la flecha
    tip_top, tip_bottom = (limb_x(-1), -L), (limb_x(1), L)
    for col, w in ((OUTLINE, 44), (STRING, 22)):
        d.line(rot([tip_top, (-P, 0), tip_bottom], ang, ox, oy), fill=col, width=w, joint="curve")

    # Palas del arco: más gruesas en la empuñadura
    steps = 160
    left, right = [], []
    for i in range(steps + 1):
        s = -1 + 2 * i / steps
        x, y = limb_x(s), s * L
        dx = (limb_x(min(s + 0.01, 1)) - limb_x(max(s - 0.01, -1))) / 0.02
        n = math.hypot(dx, L)
        nx, ny = L / n, -dx / n
        w = 112 * (1 - 0.55 * abs(s))
        left.append((x + nx * w / 2, y + ny * w / 2))
        right.append((x - nx * w / 2, y - ny * w / 2))
    d.polygon(rot(left + right[::-1], ang, ox, oy), fill=WOOD, outline=OUTLINE, width=20)
    d.line(rot([(x + 10, y) for x, y in left[20:141]], ang, ox, oy), fill=WOOD_LIGHT, width=18)
    # Empuñadura
    grip = [(G - 60, -120), (G + 60, -120), (G + 60, 120), (G - 60, 120)]
    d.polygon(rot(grip, ang, ox, oy), fill=GREEN, outline=OUTLINE, width=14)

    # Flecha
    shaft = [(-P - 60, -26), (G + 300, -26), (G + 300, 26), (-P - 60, 26)]
    d.polygon(rot(shaft, ang, ox, oy), fill=SHAFT, outline=OUTLINE, width=12)
    head = [(G + 250, -105), (G + 500, 0), (G + 250, 105), (G + 300, 0)]
    d.polygon(rot(head, ang, ox, oy), fill=STEEL, outline=OUTLINE, width=14)
    for sign in (-1, 1):
        fletch = [(-P - 40, sign * 26), (-P + 150, sign * 26), (-P + 60, sign * 140), (-P - 120, sign * 140)]
        d.polygon(rot(fletch, ang, ox, oy), fill=GREEN, outline=OUTLINE, width=12)


img = background()
rays(img)
halo(img)
bow_and_arrow(img)
img.resize((512, 512), Image.LANCZOS).save(sys.argv[1])

# Icono del minimapa: el centro del logo en un círculo, para el botón redondo
icon = img.crop((int(C - 760), int(C - 760), int(C + 760), int(C + 760))).resize((64, 64), Image.LANCZOS)
mask = Image.new("L", (256, 256), 0)
ImageDraw.Draw(mask).ellipse((2, 2, 253, 253), fill=255)
alpha = Image.composite(icon.getchannel("A"), Image.new("L", (64, 64), 0), mask.resize((64, 64), Image.LANCZOS))
icon.putalpha(alpha)
icon.save(sys.argv[2])
print("logo ->", sys.argv[1], "| icono ->", sys.argv[2])
