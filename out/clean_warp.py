import os
import numpy as np
from PIL import Image, ImageDraw

BASE_DIR = "/Users/titane0/Library/Mobile Documents/iCloud~md~obsidian/Documents/Mission_Control/out"

# Mapped screen coordinates inside the bezel for 1080x1920 canvas
quad = [
    (115, 770),  # TL (Red)
    (885, 782),  # TR (Green)
    (875, 1355), # BR (Blue)
    (480, 1445)  # BL (Yellow)
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
    print("Loading scaled base and Remotion UI images...")
    base_img = Image.open(os.path.join(BASE_DIR, "slide_6_vertical_base.png")).convert("RGBA")
    # Open the original rendered screenshot
    remotion_img = Image.open(os.path.join(BASE_DIR, "slide_6.png")).convert("RGBA")
    
    # Crop the exact iMessage UI screenshot (excluding the Remotion caption overlay at the bottom)
    # The caption overlay starts around y = 1500
    ui_crop = remotion_img.crop((0, 0, 1080, 1500))
    ui_w, ui_h = ui_crop.size
    
    # Warp parameters
    src_pts = [(0, 0), (ui_w, 0), (ui_w, ui_h), (0, ui_h)]
    dst_pts = quad
    coeffs = get_perspective_transform(dst_pts, src_pts)
    
    # Perform perspective warp
    print("Perspective warping iMessage UI...")
    warped_ui = ui_crop.transform(base_img.size, Image.PERSPECTIVE, coeffs, Image.BICUBIC)
    
    # Create mask of the quad area
    mask = Image.new("L", base_img.size, 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.polygon(quad, fill=255)
    
    # Extract reflection from base image
    reflection = Image.new("RGBA", base_img.size)
    reflection.paste(base_img, mask=mask)
    
    # Composite the warped UI onto the base image
    composite_base = Image.alpha_composite(base_img, warped_ui)
    
    # Blend the reflection glare back on top using screen transparency (65%)
    reflection_gray = reflection.convert("L")
    reflection_alpha = Image.eval(reflection_gray, lambda x: int(x * 0.65))
    reflection.putalpha(reflection_alpha)
    
    final_composite = Image.alpha_composite(composite_base, reflection)
    
    # Draw the clean, flat caption overlay from Remotion at the bottom (y=1500 to 1920)
    caption_crop = remotion_img.crop((0, 1500, 1080, 1920))
    final_composite.paste(caption_crop, (0, 1500), caption_crop)
    
    # Save the clean final output
    output_path = os.path.join(BASE_DIR, "slide_6_clean_warp.png")
    final_composite.save(output_path, "PNG")
    print(f"Clean warp complete. Saved to {output_path}")

if __name__ == "__main__":
    main()
