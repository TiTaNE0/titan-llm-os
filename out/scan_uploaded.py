import os
from PIL import Image

BRAIN_DIR = "/Users/titane0/.gemini/antigravity/brain/25e36d7c-4383-48d2-9754-df5a2c334a27"

def main():
    img_path = os.path.join(BRAIN_DIR, "media__1781022098509.jpg")
    img = Image.open(img_path).convert("RGB")
    w, h = img.size
    print(f"Image size: {w}x{h}")
    
    # Let's find all magenta pixels: R > 200, G < 50, B > 200
    magenta_pixels = []
    pixels = img.load()
    for y in range(h):
        for x in range(w):
            r, g, b = pixels[x, y]
            if r > 200 and g < 50 and b > 200:
                magenta_pixels.append((x, y))
                
    print(f"Magenta pixels found: {len(magenta_pixels)}")
    if magenta_pixels:
        tl = min(magenta_pixels, key=lambda p: p[0] + p[1])
        tr = max(magenta_pixels, key=lambda p: p[0] - p[1])
        br = max(magenta_pixels, key=lambda p: p[0] + p[1])
        bl = min(magenta_pixels, key=lambda p: p[0] - p[1])
        print("Magenta corners:")
        print(f"  TL: {tl}")
        print(f"  TR: {tr}")
        print(f"  BR: {br}")
        print(f"  BL: {bl}")

if __name__ == "__main__":
    main()
