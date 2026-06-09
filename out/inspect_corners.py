import os
from PIL import Image, ImageDraw

BASE_DIR = "/Users/titane0/Library/Mobile Documents/iCloud~md~obsidian/Documents/Mission_Control/out"

def find_screen_quad_slide6(img):
    w, h = img.size
    pixels = img.load()
    
    dark_pixels = []
    # Scan a broad region in the lower-left to middle where the phone screen lies
    for y in range(int(h * 0.3), int(h * 0.8)):
        for x in range(int(w * 0.25), int(w * 0.75)):
            r, g, b = pixels[x, y][:3]
            if r < 40 and g < 40 and b < 40:
                dark_pixels.append((x, y))
                
    if not dark_pixels:
        return [
            (316, 765),
            (597, 641),
            (813, 1293),
            (491, 1453)
        ]
        
    tl = min(dark_pixels, key=lambda p: p[0] + p[1])
    tr = max(dark_pixels, key=lambda p: p[0] - p[1])
    br = max(dark_pixels, key=lambda p: p[0] + p[1])
    bl = min(dark_pixels, key=lambda p: p[0] - p[1])
    
    return [tl, tr, br, bl]

def main():
    img = Image.open(os.path.join(BASE_DIR, "slide_6_base.png")).convert("RGBA")
    draw = ImageDraw.Draw(img)
    
    quad = find_screen_quad_slide6(img)
    print("Detected corners:", quad)
    
    colors = [(255, 0, 0), (0, 255, 0), (0, 0, 255), (255, 255, 0)] # TL=Red, TR=Green, BR=Blue, BL=Yellow
    for pt, color in zip(quad, colors):
        # Draw a circle around the corner
        draw.ellipse([pt[0] - 10, pt[1] - 10, pt[0] + 10, pt[1] + 10], fill=color)
        
    img.save(os.path.join(BASE_DIR, "slide_6_corners_check.png"))
    print("Saved check image to slide_6_corners_check.png")

if __name__ == "__main__":
    main()
