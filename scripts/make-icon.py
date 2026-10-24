# Renders the app icon: amber-to-crimson gradient, an aurora band and a glass bubble holding clock hands at 10:10.
import math
import sys
import numpy as np
from PIL import Image

N = 1024
y, x = np.mgrid[0:N, 0:N] / N

top, mid, bot = np.array([1.0, 0.72, 0.14]), np.array([0.98, 0.38, 0.20]), np.array([0.58, 0.05, 0.12])
t = np.clip(y * 0.8 + x * 0.2, 0, 1)[..., None]
col = np.where(t < 0.5, top + (mid - top) * (t / 0.5), mid + (bot - mid) * ((t - 0.5) / 0.5))

dy = y - (0.27 + 0.05 * np.sin(x * 5.0 + 1.0))
band = np.where(dy < 0, np.exp(-dy * dy * 1200), np.exp(-dy * 6))
band *= 0.8 + 0.2 * np.sin(x * 9 + 1.5)
col = 1 - (1 - col) * (1 - band[..., None] * 0.5 * np.array([1.0, 0.95, 0.75]))

def bubble(cx, cy, r, strength):
    dx, dy = (x - cx) / r, (y - cy) / r
    d = np.sqrt(dx ** 2 + dy ** 2)
    body = np.clip((1.0 - d) / 0.012, 0, 1)
    rim = np.clip((d - 0.55) / 0.45, 0, 1) ** 2.5 * body
    spec = np.exp(-((dx + 0.38) ** 2 + (dy + 0.42) ** 2) * 28) + 0.4 * np.exp(-((dx - 0.42) ** 2 + (dy - 0.46) ** 2) * 80)
    return (0.06 * body + 0.6 * rim + 0.9 * spec * body) * strength

glass = bubble(0.5, 0.56, 0.31, 0.8) + bubble(0.20, 0.82, 0.07, 0.5) + bubble(0.84, 0.30, 0.05, 0.45)
col = col + glass[..., None] * 0.75

def segment(ax, ay, angle, length, width):
    bx, by = ax + math.sin(angle) * length, ay - math.cos(angle) * length
    px, py, vx, vy = x - ax, y - ay, bx - ax, by - ay
    h = np.clip((px * vx + py * vy) / (vx * vx + vy * vy), 0, 1)
    dist = np.sqrt((px - vx * h) ** 2 + (py - vy * h) ** 2)
    return np.clip(1 - (dist - width) / 0.0025, 0, 1)

hands = np.maximum(segment(0.5, 0.56, math.radians(305), 0.13, 0.006), segment(0.5, 0.56, math.radians(60), 0.20, 0.004))
hands = np.maximum(hands, np.clip(1 - (np.sqrt((x - 0.5) ** 2 + (y - 0.56) ** 2) - 0.012) / 0.0025, 0, 1))
col = col * (1 - hands[..., None] * 0.92) + hands[..., None] * 0.92

col += (np.random.default_rng(1).random((N, N, 1)) - 0.5) * 0.015
Image.fromarray((np.clip(col, 0, 1) * 255).astype(np.uint8), "RGB").save(sys.argv[1])
