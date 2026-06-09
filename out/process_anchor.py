import os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

BRAIN_DIR = "/Users/titane0/.gemini/antigravity/brain/25e36d7c-4383-48d2-9754-df5a2c334a27"
VAULT_OUT_DIR = "/Users/titane0/Library/Mobile Documents/iCloud~md~obsidian/Documents/Mission_Control/out"

def main():
    print("Loading uploaded anchor image...")
    img_path = os.path.join(BRAIN_DIR, "media__1781022098509.jpg")
    img = Image.open(img_path).convert("RGBA")
    
    # 1. Scale to 1080x1920
    print("Resizing base image to 1080x1920...")
    base_img = img.resize((1080, 1920), Image.Resampling.LANCZOS)
    
    # 2. Patch the Gemini watermark at the bottom-right corner
    # The watermark (four-point star) is roughly at x=940 to 1040, y=1750 to 1850.
    # Let's copy a patch from slightly above it (y=1630 to 1730) which is the same dark blurry sleeve.
    print("Removing Gemini watermark...")
    patch = base_img.crop((940, 1630, 1040, 1730))
    # Soften patch edges slightly to blend
    mask = Image.new("L", (100, 100), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.ellipse([5, 5, 95, 95], fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(5))
    
    # Paste the patch over the watermark
    base_img.paste(patch, (940, 1750), mask=mask)
    
    # 3. Detect the magenta screen area on the upscaled base image
    print("Scanning for magenta screen coordinates...")
    pixels = base_img.load()
    w, h = base_img.size
    
    magenta_pts = []
    for y in range(h):
        for x in range(w):
            r, g, b, a = pixels[x, y]
            # Match vibrant magenta (high R, low G, high B)
            if r > 220 and g < 60 and b > 220:
                # Limit scan to central phone area
                if 450 <= y <= 1400 and 300 <= x <= 800:
                    magenta_pts.append((x, y))
                    
    print(f"Upscaled magenta pixels found: {len(magenta_pts)}")
    if not magenta_pts:
        print("Error: Magenta screen not found!")
        return
        
    # Find exact corners
    tl = min(magenta_pts, key=lambda p: p[0] + p[1])
    tr = max(magenta_pts, key=lambda p: p[0] - p[1])
    br = max(magenta_pts, key=lambda p: p[0] + p[1])
    bl = min(magenta_pts, key=lambda p: p[0] - p[1])
    
    # Inward padding by 2 pixels to avoid magenta borders showing at edges
    quad = [
        (tl[0] + 2, tl[1] + 2),
        (tr[0] - 2, tr[1] + 2),
        (br[0] - 2, br[1] - 2),
        (bl[0] + 2, bl[1] - 2)
    ]
    print("Detected screen quad:", quad)
    
    # 4. Load the Remotion screenshot of Slide 2
    remotion_path = os.path.join(VAULT_OUT_DIR, "slide_2.png")
    if not os.path.exists(remotion_path):
        print(f"Error: Remotion slide_2.png not found at {remotion_path}!")
        return
    remotion_img = Image.open(remotion_path).convert("RGBA")
    
    # Crop the raw iMessage UI (leaving out the caption at the bottom)
    ui_crop = remotion_img.crop((0, 0, 1080, 1600))
    ui_w, ui_h = ui_crop.size
    
    # 5. Warp the iMessage UI onto the detected quad
    src_pts = [(0, 0), (ui_w, 0), (ui_w, ui_h), (0, ui_h)]
    dst_pts = quad
    
    coeffs = get_perspective_transform(dst_pts, src_pts)
    print("Perspective warping iMessage UI...")
    warped_ui = ui_crop.transform(base_img.size, Image.PERSPECTIVE, coeffs, Image.BICUBIC)
    
    # 6. Composite the warped UI onto the base image
    final_composite = Image.alpha_composite(base_img, warped_ui)
    
    # 7. Paste the caption overlay from the bottom of Slide 2
    caption_crop = remotion_img.crop((0, 1500, 1080, 1920))
    final_composite.paste(caption_crop, (0, 1500), caption_crop)
    
    # 8. Save the final slide
    final_output_path = os.path.join(VAULT_OUT_DIR, "slide_2.png")
    final_composite.save(final_output_path, "PNG")
    print(f"Anchor slide composite complete. Saved to {final_output_path}")
    
    # Copy to brain folder for display
    brain_output_path = os.path.join(BRAIN_DIR, "slide_2.png")
    final_composite.save(brain_output_path, "PNG")

def get_perspective_transform(src_pts, dst_pts):
    matrix = []
    for i in range(4):
        x, y = src_pts[i]
        u, v = dst_pts[i]
        matrix.append([x, y, 1, 0, 0, 0, -x*u, -y*u])
        matrix.append([0, 0, 0, x, y, 1, -x*v, -y*v])
    
    A = np.array(matrix)
    B = np.array([dst_pts[0][0], dst_pts[0][1], dst_pts[1][0], dst_pts[1][1],
                  dst_pts[2][0], dst_pts[2][1], dst_pts[3][0], dst_pts[3][1]])
    
    h = np.linalg.solve(A, B)
    return h

if __name__ == "__main__":
    main()
