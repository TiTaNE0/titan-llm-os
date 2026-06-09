import os
from PIL import Image, ImageDraw

BASE_DIR = "/Users/titane0/Library/Mobile Documents/iCloud~md~obsidian/Documents/Mission_Control/out"

def main():
    img = Image.open(os.path.join(BASE_DIR, "slide_6_vertical_base.png")).convert("RGBA")
    draw = ImageDraw.Draw(img)
    w, h = img.size
    
    # Draw a 50px grid
    for x in range(0, w, 50):
        draw.line([(x, 0), (x, h)], fill=(200, 200, 200, 100), width=1)
        if x % 100 == 0:
            draw.text((x, 10), str(x), fill=(255, 0, 0, 180))
            
    for y in range(0, h, 50):
        draw.line([(0, y), (w, y)], fill=(200, 200, 200, 100), width=1)
        if y % 100 == 0:
            draw.text((10, y), str(y), fill=(255, 0, 0, 180))
            
    img.save(os.path.join(BASE_DIR, "slide_6_grid_check.png"))
    print("Saved slide_6_grid_check.png")

if __name__ == "__main__":
    main()
