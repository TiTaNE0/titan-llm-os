import os
import numpy as np
from PIL import Image

BASE_DIR = "/Users/titane0/Library/Mobile Documents/iCloud~md~obsidian/Documents/Mission_Control/out"

def main():
    img = Image.open(os.path.join(BASE_DIR, "slide_6_vertical_base.png")).convert("RGB")
    w, h = img.size
    pixels = img.load()
    
    # We want to find the dark pixels of the phone screen.
    # The table is wood (light brown/orange), and the phone screen is very dark (almost black).
    # Let's collect all dark pixels where R < 35, G < 35, B < 35.
    dark_pts = []
    for y in range(h):
        for x in range(w):
            r, g, b = pixels[x, y]
            if r < 35 and g < 35 and b < 35:
                # Filter out bottom area (captions/safe zone padding)
                # The phone is roughly in the middle vertical third (y between 500 and 1500)
                if 500 <= y <= 1500 and 100 <= x <= 900:
                    dark_pts.append((x, y))
                    
    print(f"Total dark pixels found: {len(dark_pts)}")
    if not dark_pts:
        return
        
    # We want to find the 4 corners of the dark screen quadrilateral.
    # The screen is tilted. Let's find the corners by:
    # Top-Left: minimizes x + y
    # Top-Right: maximizes x - y
    # Bottom-Right: maximizes x + y
    # Bottom-Left: minimizes x - y
    tl = min(dark_pts, key=lambda p: p[0] + p[1])
    tr = max(dark_pts, key=lambda p: p[0] - p[1])
    br = max(dark_pts, key=lambda p: p[0] + p[1])
    bl = min(dark_pts, key=lambda p: p[0] - p[1])
    
    print(f"Candidate TL (min x+y): {tl}, Color: {pixels[tl[0], tl[1]]}")
    print(f"Candidate TR (max x-y): {tr}, Color: {pixels[tr[0], tr[1]]}")
    print(f"Candidate BR (max x+y): {br}, Color: {pixels[br[0], br[1]]}")
    print(f"Candidate BL (min x-y): {bl}, Color: {pixels[bl[0], bl[1]]}")
    
    # Let's inspect coordinates around these candidates to confirm they are the actual corners
    # (i.e. where the transition from dark to light table happens)
    
if __name__ == "__main__":
    main()
