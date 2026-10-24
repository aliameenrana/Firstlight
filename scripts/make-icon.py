# Renders the app icon: a light-blue gradient with a faint aurora band and clock hands at 10:10.
import math
import sys
import numpy as np
from PIL import Image

N = 1024
y, x = np.mgrid[0:N, 0:N] / N

top, mid, bot = np.array([0.55, 0.88, 1.0]), np.array([0.22, 0.62, 0.95]), np.array([0.06, 0.30, 0.70])
t = np.clip(y * 0.8 + x * 0.2, 0, 1)[..., None]
col = np.where(t < 0.5, top + (mid - top) * (t / 0.5), mid + (bot - mid) * ((t - 0.5) / 0.5))

dy = y - (0.27 + 0.05 * np.sin(x * 5.0 + 1.0))
band = np.where(dy < 0, np.exp(-dy * dy * 1200), np.exp(-dy * 6))
band *= 0.8 + 0.2 * np.sin(x * 9 + 1.5)
col = 1 - (1 - col) * (1 - band[..., None] * 0.5 * np.array([0.85, 1.0, 0.95]))

def segment(ax, ay, angle, length, width):
    bx, by = ax + math.sin(angle) * length, ay - math.cos(angle) * length
    px, py, vx, vy = x - ax, y - ay, bx - ax, by - ay
    h = np.clip((px * vx + py * vy) / (vx * vx + vy * vy), 0, 1)
    dist = np.sqrt((px - vx * h) ** 2 + (py - vy * h) ** 2)
    return np.clip(1 - (dist - width) / 0.0025, 0, 1)

hands = np.maximum(segment(0.5, 0.5, math.radians(305), 0.19, 0.012), segment(0.5, 0.5, math.radians(60), 0.29, 0.008))
hands = np.maximum(hands, np.clip(1 - (np.sqrt((x - 0.5) ** 2 + (y - 0.5) ** 2) - 0.02) / 0.0025, 0, 1))
col = col * (1 - hands[..., None] * 0.96) + hands[..., None] * 0.96

col += (np.random.default_rng(1).random((N, N, 1)) - 0.5) * 0.015
Image.fromarray((np.clip(col, 0, 1) * 255).astype(np.uint8), "RGB").save(sys.argv[1])
