"""Dibuja las texturas de los procs del cazador.

- wind_glow.tga y wind_core.tga: 16 fotogramas (4x4 de 64x256) de ráfagas de viento que suben, para
  una animación FlipBook que se repite sin corte: en una vuelta cada ráfaga sube una o dos alturas
  enteras. Quick Shots y Quick Strikes (Deadly Aspects). El brillo y el núcleo van aparte para teñir
  el brillo con tu color y dejar el núcleo casi blanco.
- ring_glow.tga y ring_core.tga: 16 fotogramas (4x4 de 256x128) de un anillo de trazos visto en el
  suelo, girando un octavo de vuelta: con ocho trazos iguales, la vuelta empalma. Rapid Killing.
- ring_base.tga: la mira quieta en el suelo: un círculo fino y cuatro marcas.
- proc_aura.tga: un brillo alargado detrás de cada columna de viento.
- proc_spot.tga: un brillo redondo para el destello del anillo.

Todo en blanco: el color lo pone el juego (SetVertexColor) y la transparencia es la intensidad.
Uso: python -I make_procs.py <carpeta media del addon>
Necesita: pip install pillow
"""
import math
import random
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

SS = 4  # se dibuja grande y se reduce para suavizar bordes
COLS, ROWS = 4, 4
FRAMES = COLS * ROWS

WFW, WFH = 64, 256  # un fotograma del viento: estrecho, las ráfagas juntas
RFW, RFH = 256, 128  # un fotograma del anillo
SQUASH = 0.38  # un círculo en el suelo, visto desde la cámara: más ancho que alto
RX = 106  # radio del anillo en píxeles finales, a lo ancho


def stretch(img, gain):
    """Sube la intensidad sin pasar de 255"""
    return img.point(lambda v: min(255, int(v * gain)))


def white(alpha):
    img = Image.new("RGBA", alpha.size, (255, 255, 255, 0))
    img.putalpha(alpha)
    return img


def brush(d, pts, widths, power):
    """Una línea de grosor variable: tramos cortos con las puntas redondas"""
    fill = int(255 * power)
    for (ax, ay), (bx, by), w in zip(pts, pts[1:], widths):
        if w <= 0.2:
            continue
        d.line((ax, ay, bx, by), fill=fill, width=max(1, round(w)))
        r = w / 2
        d.ellipse((bx - r, by - r, bx + r, by + r), fill=fill)


# ---------------------------------------------------------------- Viento

def gusts(seed):
    """Las ráfagas de una columna: dónde, lo largas, lo gruesas y lo rápidas que van"""
    rng = random.Random(seed)
    out = []
    for i in range(7):
        out.append(dict(
            x=rng.uniform(-13, 13),
            length=rng.uniform(64, 132),
            width=rng.uniform(1.8, 3.4),
            laps=1 if i % 3 else 2,  # alturas enteras por vuelta: la animación empalma
            phase=rng.uniform(0, 1),
            sway=rng.uniform(2.5, 5.0),
            wobble=rng.uniform(0, math.tau),
            power=rng.uniform(0.55, 1.0),
        ))
    return out


def wind_layer(gs, t, scale, power=1.0):
    """Las ráfagas en el momento t (0 a 1 de la vuelta), con el grosor por scale"""
    w, h = WFW * SS, WFH * SS
    img = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(img)
    for g in gs:
        head = ((g["phase"] - g["laps"] * t) % 1.0) * h  # sube: la y baja con el tiempo
        length = g["length"] * SS
        for shift in (-h, 0, h):  # la que sale por arriba entra por abajo
            top = head + shift
            if top > h or top + length < 0:
                continue
            n = 28
            pts, widths = [], []
            for k in range(n + 1):
                s = k / n
                y = top + s * length
                x = w / 2 + g["x"] * SS + g["sway"] * SS * math.sin(math.tau * 1.5 * y / h + g["wobble"])
                pts.append((x, y))
                # Más gruesa cerca de la cabeza, afilada en la cola
                profile = (math.sin(math.pi * min(1.0, s * 1.15)) ** 0.7) * (1 - 0.55 * s)
                widths.append(g["width"] * scale * SS * profile)
            brush(d, pts, widths[1:], g["power"] * power)
    return img


def fade_ends(img, fh, edge=0.2):
    """Se apaga suave arriba y abajo, para que las ráfagas aparezcan y se vayan sin corte"""
    mask = Image.new("L", (1, img.size[1]))
    for y in range(img.size[1]):
        t = y / (img.size[1] - 1)
        e = min(t, 1 - t) / edge
        mask.putpixel((0, y), int(255 * min(1.0, e) ** 1.6))
    return ImageChops.multiply(img, mask.resize(img.size))


def wind_frame(gs, t):
    glow = ImageChops.add(stretch(wind_layer(gs, t, 4.0).filter(ImageFilter.GaussianBlur(4 * SS)), 2.4),
                          stretch(wind_layer(gs, t, 2.2).filter(ImageFilter.GaussianBlur(1.8 * SS)), 1.4))
    core = ImageChops.add(wind_layer(gs, t, 1.0).filter(ImageFilter.GaussianBlur(0.3 * SS)),
                          wind_layer(gs, t, 1.9, 0.45).filter(ImageFilter.GaussianBlur(0.8 * SS)))
    return [fade_ends(layer, WFH).resize((WFW, WFH), Image.LANCZOS) for layer in (glow, core)]


def wind_sheets():
    gs = gusts(4242)
    glow_sheet = Image.new("L", (WFW * COLS, WFH * ROWS), 0)
    core_sheet = Image.new("L", (WFW * COLS, WFH * ROWS), 0)
    for n in range(FRAMES):
        glow, core = wind_frame(gs, n / FRAMES)
        x, y = (n % COLS) * WFW, (n // COLS) * WFH
        glow_sheet.paste(glow, (x, y))
        core_sheet.paste(core, (x, y))
    return white(glow_sheet), white(core_sheet)


# ---------------------------------------------------------------- Anillo

def ground(angle, radius):
    """Un punto del círculo del suelo, visto desde la cámara (y hacia abajo)"""
    return (RFW / 2 + RX * radius * math.cos(angle)) * SS, (RFH / 2 + RX * SQUASH * radius * math.sin(angle)) * SS


def depth(angle):
    """Lo de delante (abajo) un poco más grueso y fuerte que lo de detrás"""
    return 0.78 + 0.22 * (1 + math.sin(angle))


def arc(d, a0, a1, radius, width, power, steps=24):
    pts = [ground(a0 + (a1 - a0) * k / steps, radius) for k in range(steps + 1)]
    mids = [a0 + (a1 - a0) * (k + 0.5) / steps for k in range(steps)]
    widths = [width * SS * depth(a) for a in mids]
    fill_power = power * sum(depth(a) for a in mids) / len(mids) / 1.22
    brush(d, pts, widths, min(1.0, fill_power))


def dashes_layer(turn, scale, power=1.0):
    """Ocho trazos en el borde, girados turn (0 a 1 de un octavo de vuelta)"""
    img = Image.new("L", (RFW * SS, RFH * SS), 0)
    d = ImageDraw.Draw(img)
    step = math.tau / 8
    for i in range(8):
        a0 = i * step + turn * step
        arc(d, a0, a0 + step * 0.55, 1.0, 2.6 * scale, power)
        # Una punta fina detrás de cada trazo, como una estela
        arc(d, a0 - step * 0.16, a0 - step * 0.02, 1.0, 1.1 * scale, power * 0.6, 8)
    return img


def ring_frame(turn):
    glow = ImageChops.add(stretch(dashes_layer(turn, 3.2).filter(ImageFilter.GaussianBlur(4 * SS)), 2.2),
                          stretch(dashes_layer(turn, 1.8).filter(ImageFilter.GaussianBlur(1.4 * SS)), 1.3))
    core = ImageChops.add(dashes_layer(turn, 1.0).filter(ImageFilter.GaussianBlur(0.3 * SS)),
                          dashes_layer(turn, 1.7, 0.4).filter(ImageFilter.GaussianBlur(0.8 * SS)))
    return [layer.resize((RFW, RFH), Image.LANCZOS) for layer in (glow, core)]


def ring_sheets():
    glow_sheet = Image.new("L", (RFW * COLS, RFH * ROWS), 0)
    core_sheet = Image.new("L", (RFW * COLS, RFH * ROWS), 0)
    for n in range(FRAMES):
        glow, core = ring_frame(n / FRAMES)
        x, y = (n % COLS) * RFW, (n // COLS) * RFH
        glow_sheet.paste(glow, (x, y))
        core_sheet.paste(core, (x, y))
    return white(glow_sheet), white(core_sheet)


def ring_base():
    """La mira quieta: un círculo fino por dentro y cuatro marcas que apuntan al centro"""
    def layer(scale, power=1.0):
        img = Image.new("L", (RFW * SS, RFH * SS), 0)
        d = ImageDraw.Draw(img)
        arc(d, 0, math.tau, 0.56, 1.1 * scale, power * 0.8, 120)
        for i in range(4):
            a = i * math.tau / 4
            (ax, ay), (bx, by) = ground(a, 0.66), ground(a, 0.88)
            w = 2.4 * scale * SS * depth(a)
            d.line((ax, ay, bx, by), fill=int(255 * power), width=max(1, round(w)))
            for x, y in ((ax, ay), (bx, by)):
                d.ellipse((x - w / 2, y - w / 2, x + w / 2, y + w / 2), fill=int(255 * power))
        return img
    glow = stretch(layer(3.0).filter(ImageFilter.GaussianBlur(3.5 * SS)), 1.6)
    core = layer(1.0).filter(ImageFilter.GaussianBlur(0.3 * SS))
    return white(ImageChops.add(glow, core).resize((RFW, RFH), Image.LANCZOS))


# ---------------------------------------------------------------- Brillos

def soft(w, h, sx, sy):
    """Una campana suave que llega a cero en los bordes"""
    alpha = Image.new("L", (w, h))
    for y in range(h):
        for x in range(w):
            dx, dy = (x + 0.5) / w * 2 - 1, (y + 0.5) / h * 2 - 1
            bell = math.exp(-(dx * dx) / sx - (dy * dy) / sy)
            edge = max(0.0, 1 - dx * dx) * max(0.0, 1 - dy * dy)
            alpha.putpixel((x, y), int(255 * bell * edge))
    return white(alpha)


if __name__ == "__main__":
    media = Path(sys.argv[1])
    glow, core = wind_sheets()
    glow.save(media / "wind_glow.tga")
    core.save(media / "wind_core.tga")
    glow, core = ring_sheets()
    glow.save(media / "ring_glow.tga")
    core.save(media / "ring_core.tga")
    ring_base().save(media / "ring_base.tga")
    soft(64, 256, 0.16, 0.3).save(media / "proc_aura.tga")
    soft(128, 128, 0.22, 0.22).save(media / "proc_spot.tga")
    print("wind_glow, wind_core, ring_glow, ring_core, ring_base, proc_aura, proc_spot")
