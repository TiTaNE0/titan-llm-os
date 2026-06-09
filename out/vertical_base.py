import os
from PIL import Image

BASE_DIR = "/Users/titane0/Library/Mobile Documents/iCloud~md~obsidian/Documents/Mission_Control/out"

def main():
    img = Image.open(os.path.join(BASE_DIR, "slide_6_base.png")).convert("RGBA")
    w, h = img.size
    print(f"Original size: {w}x{h}")
    
    # Crop to 9:16 ratio
    new_w = int(h * 9 / 16)
    left = (w - new_w) // 2
    right = left + new_w
    img_cropped = img.crop((left, 0, right, h))
    
    # Scale to 1080x1920
    img_vertical = img_cropped.resize((1080, 1920), Image.Resampling.LANCZOS)
    img_vertical.save(os.path.join(BASE_DIR, "slide_6_vertical_base.png"), "PNG")
    print("Saved slide_6_vertical_base.png")

if __name__ == "__main__":
    main()
