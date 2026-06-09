import os
from PIL import Image, ImageDraw

BASE_DIR = "/Users/titane0/Library/Mobile Documents/iCloud~md~obsidian/Documents/Mission_Control/out"

# Direct scan candidates:
# TL: (103, 754)
# TR: (900, 766)
# BR: (894, 1371)
# BL: (465, 1463)

# Let's apply a small bezel padding inward to fit the screen display area:
quad = [
    (115, 770),  # TL (inward from 103, 754)
    (885, 782),  # TR (inward from 900, 766)
    (875, 1355), # BR (inward from 894, 1371)
    (480, 1445)  # BL (inward from 465, 1463)
]

def main():
    img = Image.open(os.path.join(BASE_DIR, "slide_6_vertical_base.png")).convert("RGBA")
    draw = ImageDraw.Draw(img)
    
    colors = [(255, 0, 0), (0, 255, 0), (0, 0, 255), (255, 255, 0)] # TL=Red, TR=Green, BR=Blue, BL=Yellow
    for pt, color in zip(quad, colors):
        draw.ellipse([pt[0] - 15, pt[1] - 15, pt[0] + 15, pt[1] + 15], fill=color)
        
    img.save(os.path.join(BASE_DIR, "slide_6_vertical_corners_check_v2.png"))
    print("Saved check image v2.")

if __name__ == "__main__":
    main()
