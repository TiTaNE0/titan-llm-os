import os
from PIL import Image, ImageDraw

BASE_DIR = "/Users/titane0/Library/Mobile Documents/iCloud~md~obsidian/Documents/Mission_Control/out"

# Approximate coordinates based on scaling factor (1024 -> 1920 vertical)
# Width was cropped from 1024 to 576, then scaled by 1.875
# Coordinate math: x_scaled = (x_orig - 224) * 1.875, y_scaled = y_orig * 1.875
# Let's test these aligned coordinates:
quad = [
    (118, 788),  # TL (287 in original width) -> (287-224)*1.875 = 118
    (919, 819),  # TR (714 in original width) -> (714-224)*1.875 = 919
    (795, 1324), # BR (648 in original width) -> (648-224)*1.875 = 795
    (293, 1352)  # BL (380 in original width) -> (380-224)*1.875 = 293
]

def main():
    img = Image.open(os.path.join(BASE_DIR, "slide_6_vertical_base.png")).convert("RGBA")
    draw = ImageDraw.Draw(img)
    
    colors = [(255, 0, 0), (0, 255, 0), (0, 0, 255), (255, 255, 0)]
    for pt, color in zip(quad, colors):
        draw.ellipse([pt[0] - 15, pt[1] - 15, pt[0] + 15, pt[1] + 15], fill=color)
        
    img.save(os.path.join(BASE_DIR, "slide_6_vertical_corners_check.png"))
    print("Saved check image.")

if __name__ == "__main__":
    main()
