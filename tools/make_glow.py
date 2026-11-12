"""Dibuja el brillo del medidor de yardas al límite de tu alcance: un óvalo blanco que se
difumina hasta transparente (128x64 TGA). El juego lo tiñe de azul claro.

Uso: python -I make_glow.py <glow.tga>
"""
import struct
import sys

W, H = 128, 64


def alpha(x, y):
    # Distancia al centro en un óvalo que llena la imagen: 0 en el centro, 1 en el borde
    dx = (x + 0.5 - W / 2) / (W / 2)
    dy = (y + 0.5 - H / 2) / (H / 2)
    d = (dx * dx + dy * dy) ** 0.5
    if d >= 1:
        return 0
    # Caída suave, sin borde que se note
    t = 1 - d
    return round(255 * t * t * (3 - 2 * t))


def main(path):
    # TGA sin comprimir, 32 bits, origen arriba a la izquierda (descriptor 0x28)
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, W, H, 32, 0x28)
    pixels = bytearray()
    for y in range(H):
        for x in range(W):
            pixels += bytes((255, 255, 255, alpha(x, y)))  # BGRA
    with open(path, "wb") as f:
        f.write(header + pixels)


if __name__ == "__main__":
    main(sys.argv[1])
