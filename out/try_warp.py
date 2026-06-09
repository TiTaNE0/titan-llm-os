import os
import numpy as np
from PIL import Image, ImageDraw

BASE_DIR = "/Users/titane0/Library/Mobile Documents/iCloud~md~obsidian/Documents/Mission_Control/out"

def find_screen_quad_slide6(img):
    # Hand-aligned pixel coordinates of the screen corners inside the bezel:
    # Top-Left, Top-Right, Bottom-Right, Bottom-Left
    return [
        (287, 420),  # TL
        (714, 437),  # TR
        (648, 706),  # BR
        (380, 721)   # BL
    ]

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

def main():
    print("Loading images...")
    base_img = Image.open(os.path.join(BASE_DIR, "slide_6_base.png")).convert("RGBA")
    remotion_img = Image.open(os.path.join(BASE_DIR, "slide_6.png")).convert("RGBA")
    
    ui_crop = remotion_img.crop((0, 0, 1080, 1600))
    ui_w, ui_h = ui_crop.size
    
    quad = find_screen_quad_slide6(base_img)
    print("Using corrected screen quad:", quad)
    
    src_pts = [(0, 0), (ui_w, 0), (ui_w, ui_h), (0, ui_h)]
    dst_pts = quad
    coeffs = get_perspective_transform(dst_pts, src_pts)
    
    # Warp the UI
    warped_ui = ui_crop.transform(base_img.size, Image.PERSPECTIVE, coeffs, Image.BICUBIC)
    
    # Create mask of the quad area
    mask = Image.new("L", base_img.size, 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.polygon(quad, fill=255)
    
    # Get reflection
    reflection = Image.new("RGBA", base_img.size)
    reflection.paste(base_img, mask=mask)
    
    # Composite UI
    composite_base = Image.alpha_composite(base_img, warped_ui)
    
    # Blend reflection
    reflection_gray = reflection.convert("L")
    reflection_alpha = Image.eval(reflection_gray, lambda x: int(x * 0.70))
    reflection.putalpha(reflection_alpha)
    
    final_composite = Image.alpha_composite(composite_base, reflection)
    
    # Paste caption
    caption_crop = remotion_img.crop((0, 1500, 1080, 1920))
    final_composite.paste(caption_crop, (0, 1500), caption_crop)
    
    output_path = os.path.join(BASE_DIR, "slide_6_test_warp.png")
    final_composite.save(output_path, "PNG")
    print(f"Warp complete. Saved to {output_path}")

if __name__ == "__main__":
    main()
