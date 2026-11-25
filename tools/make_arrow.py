"""Dibuja la flechita del aviso de rastreo: un triángulo blanco que apunta a la derecha, con
borde negro, sobre fondo transparente (32x32 TGA). El juego lo tiñe de verde; el negro se queda.

Uso: python -I make_arrow.py <arrow.tga>
"""
import struct
import sys

W = H = 32
TRI = ((9.0, 5.5), (9.0, 26.5), (25.5, 16.0))  # x, y con y hacia abajo
EDGE = 2.2  # grosor del borde negro, en píxeles
SAMPLES = 4  # submuestras por lado, para suavizar los bordes


def edges():
    out = []
    n = len(TRI)
    for i in range(n):
        (x1, y1), (x2, y2) = TRI[i], TRI[(i + 1) % n]
        dx, dy = x2 - x1, y2 - y1
        length = (dx * dx + dy * dy) ** 0.5
        # Normal hacia fuera (con estos vértices y la y hacia abajo, el interior queda a la derecha)
        out.append((x1, y1, -dy / length, dx / length))
    return out


EDGES = edges()


def outside(px, py):
    # Lo lejos que queda el punto del triángulo, por su arista más cercana: negativo dentro
    return max((px - x) * nx + (py - y) * ny for x, y, nx, ny in EDGES)


def pixel(x, y):
    white = black = 0
    for sy in range(SAMPLES):
        for sx in range(SAMPLES):
            d = outside(x + (sx + 0.5) / SAMPLES, y + (sy + 0.5) / SAMPLES)
            if d <= 0:
                white += 1
            elif d <= EDGE:
                black += 1
    total = SAMPLES * SAMPLES
    a = (white + black) / total
    grey = round(255 * white / (white + black)) if white + black else 0
    return grey, round(255 * a)


def main(path):
    # TGA sin comprimir, 32 bits, origen arriba a la izquierda (descriptor 0x28)
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, W, H, 32, 0x28)
    pixels = bytearray()
    for y in range(H):
        for x in range(W):
            grey, a = pixel(x, y)
            pixels += bytes((grey, grey, grey, a))  # BGRA
    with open(path, "wb") as f:
        f.write(header + pixels)


if __name__ == "__main__":
    main(sys.argv[1])
