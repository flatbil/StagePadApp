"""
MD Buddy App Icon Generator
1024x1024 PNG — cartoony grid of section buttons with a music note
"""
from PIL import Image, ImageDraw
import math

SIZE = 1024
img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)

# ── Background — dark rounded square ─────────────────────────────────────────
BG = (18, 18, 24)
RADIUS = 220

def rounded_rect(draw, xy, radius, fill):
    x0, y0, x1, y1 = xy
    r = min(radius, (x1 - x0) // 2, (y1 - y0) // 2)
    if r <= 0:
        draw.rectangle([x0, y0, x1, y1], fill=fill)
        return
    draw.rectangle([x0 + r, y0, x1 - r, y1], fill=fill)
    draw.rectangle([x0, y0 + r, x1, y1 - r], fill=fill)
    draw.ellipse([x0, y0, x0 + r*2, y0 + r*2], fill=fill)
    draw.ellipse([x1 - r*2, y0, x1, y0 + r*2], fill=fill)
    draw.ellipse([x0, y1 - r*2, x0 + r*2, y1], fill=fill)
    draw.ellipse([x1 - r*2, y1 - r*2, x1, y1], fill=fill)

rounded_rect(draw, [0, 0, SIZE, SIZE], RADIUS, BG)

# ── Grid of 6 section buttons (3x2) ──────────────────────────────────────────
# Colors mirroring the app's section styles
COLORS = [
    (38, 102, 191),   # Verse — blue
    (204, 102, 13),   # Pre-Chorus — amber
    (204, 102, 13),   # Chorus — orange
    (38, 102, 191),   # Verse — blue
    (115, 38, 178),   # Bridge — purple
    (204, 51, 26),    # Outro — red
]

COLS, ROWS = 3, 2
PAD = 72          # outer padding
GAP = 28          # gap between buttons
BTN_CORNER = 36

grid_w = SIZE - PAD * 2
grid_h = int(SIZE * 0.52)
grid_y = int(SIZE * 0.22)

btn_w = (grid_w - GAP * (COLS - 1)) // COLS
btn_h = (grid_h - GAP * (ROWS - 1)) // ROWS

def rounded_btn(draw, x, y, w, h, r, fill, shadow=True):
    # Subtle shadow
    if shadow:
        rounded_rect(draw, [x+6, y+8, x+w+6, y+h+8], r, (0, 0, 0, 120))
    rounded_rect(draw, [x, y, x+w, y+h], r, fill)
    # Lighter top edge highlight
    hi = tuple(min(255, c + 40) for c in fill)
    rounded_rect(draw, [x, y, x+w, y+4], 4, hi)

for row in range(ROWS):
    for col in range(COLS):
        i = row * COLS + col
        bx = PAD + col * (btn_w + GAP)
        by = grid_y + row * (btn_h + GAP)
        color = COLORS[i]
        rounded_btn(draw, bx, by, btn_w, btn_h, BTN_CORNER, color)

# ── Music note overlaid on the grid ──────────────────────────────────────────
# Simple bold quarter note: oval head + stem, white semi-transparent
NOTE_X = SIZE // 2
NOTE_Y = SIZE // 2 + 30
NOTE_R = 78        # note head radius (oval)
NOTE_COLOR = (255, 255, 255, 200)

note_layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
nd = ImageDraw.Draw(note_layer)

# Note head — slightly tilted oval
hx, hy = NOTE_X, NOTE_Y + 20
nd.ellipse([hx - NOTE_R, hy - int(NOTE_R * 0.72),
            hx + NOTE_R, hy + int(NOTE_R * 0.72)], fill=NOTE_COLOR)

# Stem
stem_w = 18
stem_top = hy - int(NOTE_R * 0.65) - 230
nd.rectangle([hx + NOTE_R - stem_w - 4, stem_top,
              hx + NOTE_R - 4,            hy - int(NOTE_R * 0.5)],
             fill=NOTE_COLOR)

# Flag
flag_pts = [
    (hx + NOTE_R - 4,          stem_top),
    (hx + NOTE_R - 4 + 100,    stem_top + 80),
    (hx + NOTE_R - 4 + 60,     stem_top + 150),
    (hx + NOTE_R - 4,          stem_top + 110),
]
nd.polygon(flag_pts, fill=NOTE_COLOR)

# Composite note at low opacity so grid shows through
img = Image.alpha_composite(img, note_layer)

# No wordmark: text doesn't hold up at real icon sizes (App Store review /
# home screen scale it down to ~60pt), so the grid + note carry the mark alone.

# ── Save ──────────────────────────────────────────────────────────────────────
out = img.convert("RGB")
out.save("/Volumes/T7 Shield/GamesDev/StagePad/AppStore/AppIcon-1024.png", "PNG")
print("Icon saved: AppStore/AppIcon-1024.png")
