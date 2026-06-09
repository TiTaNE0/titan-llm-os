import os
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont

# Path configuration
BASE_DIR = "/Users/titane0/Library/Mobile Documents/iCloud~md~obsidian/Documents/Mission_Control/out"
FONT_PATH = "/System/Library/Fonts/Supplemental/Arial.ttf"
FONT_BOLD_PATH = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"

if not os.path.exists(FONT_PATH):
    FONT_PATH = "/Library/Fonts/Arial.ttf"
if not os.path.exists(FONT_BOLD_PATH):
    FONT_BOLD_PATH = "/Library/Fonts/Arial Bold.ttf"

def prepare_base_image(img_path):
    # Load and crop/scale to 1080x1920 (9:16)
    img = Image.open(img_path).convert("RGBA")
    w, h = img.size
    
    # If it's square, crop the width to 9:16
    if w == h:
        new_w = int(h * 9 / 16) # 576 for 1024
        left = (w - new_w) // 2
        right = left + new_w
        img = img.crop((left, 0, right, h))
        
    # Resize to 1080x1920
    img = img.resize((1080, 1920), Image.Resampling.LANCZOS)
    return img

def find_screen_box_slide2(img):
    w, h = img.size
    pixels = img.load()
    
    # We focus on the center region (x between 30% and 70%, y between 20% and 80%)
    x_min, x_max = int(w * 0.3), int(w * 0.7)
    y_min, y_max = int(h * 0.2), int(h * 0.8)
    
    dark_pixels = []
    for y in range(y_min, y_max):
        for x in range(x_min, x_max):
            r, g, b = pixels[x, y][:3]
            # Detect dark/black screen pixels
            if r < 35 and g < 35 and b < 35:
                dark_pixels.append((x, y))
                
    if not dark_pixels:
        # Fallback to hardcoded coordinates for 1080x1920
        return int(w * 0.35), int(h * 0.21), int(w * 0.64), int(h * 0.78)
        
    xs = [p[0] for p in dark_pixels]
    ys = [p[1] for p in dark_pixels]
    
    x1, x2 = min(xs), max(xs)
    y1, y2 = min(ys), max(ys)
    
    # Pad slightly inward to avoid drawing on the bezel
    return x1 + 6, y1 + 6, x2 - 6, y2 - 6

def find_screen_quad_slide6(img):
    w, h = img.size
    pixels = img.load()
    
    dark_pixels = []
    # Scan a broad region in the lower-left to middle
    for y in range(int(h * 0.3), int(h * 0.8)):
        for x in range(int(w * 0.25), int(w * 0.75)):
            r, g, b = pixels[x, y][:3]
            if r < 40 and g < 40 and b < 40:
                dark_pixels.append((x, y))
                
    if not dark_pixels:
        # Fallback to standard perspective quad for 1080x1920
        return [
            (int(w * 0.27), int(h * 0.38)),
            (int(w * 0.53), int(h * 0.33)),
            (int(w * 0.73), int(h * 0.68)),
            (int(w * 0.44), int(h * 0.76))
        ]
        
    tl = min(dark_pixels, key=lambda p: p[0] + p[1])
    tr = max(dark_pixels, key=lambda p: p[0] - p[1])
    br = max(dark_pixels, key=lambda p: p[0] + p[1])
    bl = min(dark_pixels, key=lambda p: p[0] - p[1])
    
    return [
        (tl[0] + 5, tl[1] + 5),
        (tr[0] - 5, tr[1] + 5),
        (br[0] - 5, br[1] - 5),
        (bl[0] + 5, bl[1] - 5)
    ]

def draw_caption(draw, text, img_width, img_height, font):
    # Position in the lower third
    y_pos = int(img_height * 0.80)
    
    # Wrap text to fit screen width with padding
    max_width = int(img_width * 0.85)
    words = text.split()
    lines = []
    current_line = []
    
    for word in words:
        current_line.append(word)
        line_str = " ".join(current_line)
        w = draw.textlength(line_str, font=font)
        if w > max_width:
            current_line.pop()
            lines.append(" ".join(current_line))
            current_line = [word]
    if current_line:
        lines.append(" ".join(current_line))
        
    line_height = int(draw.textbbox((0, 0), "gM", font=font)[3] * 1.3)
    total_height = line_height * len(lines)
    
    box_padding_x = 35
    box_padding_y = 25
    
    # Draw background capsule for each line
    for i, line in enumerate(lines):
        line_w = draw.textlength(line, font=font)
        line_x = (img_width - line_w) // 2
        line_y = y_pos + i * line_height
        
        draw.rounded_rectangle(
            [line_x - box_padding_x, line_y - 8, line_x + line_w + box_padding_x, line_y + line_height + 4],
            radius=20,
            fill=(0, 0, 0, 180)
        )
        
        # Draw white text
        draw.text((line_x, line_y), line, font=font, fill=(255, 255, 255, 255))

def draw_imessage_bubble(draw, text, x, y, width, is_incoming, font):
    words = text.split()
    lines = []
    current_line = []
    max_text_width = width - 60
    
    for word in words:
        current_line.append(word)
        line_str = " ".join(current_line)
        w = draw.textlength(line_str, font=font)
        if w > max_text_width:
            current_line.pop()
            lines.append(" ".join(current_line))
            current_line = [word]
    if current_line:
        lines.append(" ".join(current_line))
        
    line_height = int(draw.textbbox((0, 0), "gM", font=font)[3] * 1.3)
    text_width = max([int(draw.textlength(line, font=font)) for line in lines])
    text_height = line_height * len(lines)
    
    bubble_width = text_width + 48
    bubble_height = text_height + 32
    
    if is_incoming:
        bubble_x1 = x
        bubble_x2 = x + bubble_width
        bg_color = (233, 233, 235, 255) # #E9E9EB
        text_color = (0, 0, 0, 255)
    else:
        bubble_x1 = x - bubble_width
        bubble_x2 = x
        bg_color = (0, 122, 255, 255) # #007AFF
        text_color = (255, 255, 255, 255)
        
    bubble_y1 = y
    bubble_y2 = y + bubble_height
    
    draw.rounded_rectangle(
        [bubble_x1, bubble_y1, bubble_x2, bubble_y2],
        radius=25,
        fill=bg_color
    )
    
    # Draw text
    for i, line in enumerate(lines):
        line_y = bubble_y1 + 16 + i * line_height
        draw.text((bubble_x1 + 24, line_y), line, font=font, fill=text_color)
        
    return bubble_height

def make_imessage_screen(width, height, messages, font_regular, font_bold, draft_text=None):
    screen = Image.new("RGBA", (width, height), (255, 255, 255, 255))
    draw = ImageDraw.Draw(screen)
    
    # Draw header bar (contact name at top)
    header_height = int(height * 0.15)
    draw.rectangle([0, 0, width, header_height], fill=(247, 247, 247, 255))
    draw.line([0, header_height, width, header_height], fill=(200, 200, 200, 255), width=3)
    
    # Draw back arrow and contact profile placeholder
    profile_radius = min(35, int(width * 0.08))
    profile_y = int(header_height * 0.35)
    draw.ellipse([width // 2 - profile_radius, profile_y - profile_radius, width // 2 + profile_radius, profile_y + profile_radius], fill=(180, 180, 180, 255))
    draw.text((width // 2 - 8, profile_y - 12), "F", font=font_bold, fill=(255, 255, 255, 255))
    
    # Contact name
    draw.text((width // 2 - 35, header_height - 35), "Friend", font=font_regular, fill=(0, 0, 0, 255))
    
    # Draw bubbles
    y_offset = header_height + 40
    for text, is_incoming in messages:
        if is_incoming:
            y_offset += draw_imessage_bubble(draw, text, 30, y_offset, int(width * 0.75), True, font_regular) + 25
        else:
            y_offset += draw_imessage_bubble(draw, text, width - 30, y_offset, int(width * 0.75), False, font_regular) + 25
            
    # Draw bottom input bar
    input_height = int(height * 0.10)
    input_y1 = height - input_height
    draw.rectangle([0, input_y1, width, height], fill=(247, 247, 247, 255))
    draw.line([0, input_y1, width, input_y1], fill=(200, 200, 200, 255), width=3)
    
    # Text input field
    input_box_y1 = input_y1 + 15
    input_box_y2 = height - 15
    draw.rounded_rectangle([30, input_box_y1, width - 30, input_box_y2], radius=20, fill=(255, 255, 255, 255), outline=(220, 220, 220, 255), width=3)
    
    if draft_text:
        draw.text((50, input_box_y1 + 10), draft_text, font=font_regular, fill=(0, 0, 0, 255))
    else:
        draw.text((50, input_box_y1 + 10), "iMessage", font=font_regular, fill=(180, 180, 180, 255))
        
    return screen

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
    os.makedirs(BASE_DIR, exist_ok=True)
    
    # Fonts at high resolution
    caption_font = ImageFont.truetype(FONT_BOLD_PATH, 48)
    ui_font_regular = ImageFont.truetype(FONT_PATH, 32)
    ui_font_bold = ImageFont.truetype(FONT_BOLD_PATH, 32)
    
    print("Starting compositing pipeline at 1080x1920...")
    
    # -----------------------------------------------------------------
    # Slide 1: Sidewalk + Floating iMessage Bubble + Caption
    # -----------------------------------------------------------------
    print("Processing Slide 1...")
    s1_base = prepare_base_image(os.path.join(BASE_DIR, "slide_1_base.png"))
    s1_draw = ImageDraw.Draw(s1_base)
    
    # Draw floating incoming bubble near the top
    draw_imessage_bubble(s1_draw, "it's not far!! like 2 miles 🙂", 80, 250, int(s1_base.width * 0.8), True, ui_font_bold)
    
    # Draw caption
    draw_caption(s1_draw, "this is 2 miles.", s1_base.width, s1_base.height, caption_font)
    s1_base.save(os.path.join(BASE_DIR, "slide_1.png"), "PNG")
    
    # -----------------------------------------------------------------
    # Slide 2: Hands holding Phone + iMessage screen (incoming + draft) + Caption
    # -----------------------------------------------------------------
    print("Processing Slide 2...")
    s2_base = prepare_base_image(os.path.join(BASE_DIR, "slide_2_base.png"))
    
    # Find screen bounding box on Slide 2 phone
    x1, y1, x2, y2 = find_screen_box_slide2(s2_base)
    screen_w = x2 - x1
    screen_h = y2 - y1
    
    # Generate the iMessage UI for Slide 2
    messages_s2 = [("it's not far!! like 2 miles 🙂", True)]
    s2_ui = make_imessage_screen(screen_w, screen_h, messages_s2, ui_font_regular, ui_font_bold, draft_text="k 🙂")
    
    # Overlay UI onto screen
    s2_base.paste(s2_ui, (x1, y1), s2_ui)
    
    s2_draw = ImageDraw.Draw(s2_base)
    draw_caption(s2_draw, "i didn't know if that was a yes or a mistake. so i said yes.", s2_base.width, s2_base.height, caption_font)
    s2_base.save(os.path.join(BASE_DIR, "slide_2.png"), "PNG")
    
    # -----------------------------------------------------------------
    # Slide 3: Footsteps + Caption
    # -----------------------------------------------------------------
    print("Processing Slide 3...")
    s3_base = prepare_base_image(os.path.join(BASE_DIR, "slide_3_base.png"))
    s3_draw = ImageDraw.Draw(s3_base)
    draw_caption(s3_draw, "forty minutes in i understood. 'far' just doesn't live in my body here.", s3_base.width, s3_base.height, caption_font)
    s3_base.save(os.path.join(BASE_DIR, "slide_3.png"), "PNG")
    
    # -----------------------------------------------------------------
    # Slide 4: Bus stop + Caption
    # -----------------------------------------------------------------
    print("Processing Slide 4...")
    s4_base = prepare_base_image(os.path.join(BASE_DIR, "slide_4_base.png"))
    s4_draw = ImageDraw.Draw(s4_base)
    draw_caption(s4_draw, "so now i bus four blocks. i $8-ride distances i used to walk for free. i can't feel it anymore, so i pay to be safe.", s4_base.width, s4_base.height, caption_font)
    s4_base.save(os.path.join(BASE_DIR, "slide_4.png"), "PNG")
    
    # -----------------------------------------------------------------
    # Slide 5: Front door + Caption
    # -----------------------------------------------------------------
    print("Processing Slide 5...")
    s5_base = prepare_base_image(os.path.join(BASE_DIR, "slide_5_base.png"))
    s5_draw = ImageDraw.Draw(s5_base)
    draw_caption(s5_draw, "a whole semester of standing at this door doing the maths before i'd go anywhere.", s5_base.width, s5_base.height, caption_font)
    s5_base.save(os.path.join(BASE_DIR, "slide_5.png"), "PNG")
    
    # -----------------------------------------------------------------
    # Slide 6: Phone on table + Perspective Warp iMessage Overlay + Caption
    # -----------------------------------------------------------------
    print("Processing Slide 6...")
    s6_base = prepare_base_image(os.path.join(BASE_DIR, "slide_6_base.png"))
    
    # Detect the screen quad
    quad = find_screen_quad_slide6(s6_base)
    
    # We define a source rectangle for the UI image to warp
    ui_w = 500
    ui_h = 1000
    messages_s6 = [
        ("wanna come? it's like 2 miles", True),
        ("omw. walking 🚶", False)
    ]
    s6_ui = make_imessage_screen(ui_w, ui_h, messages_s6, ui_font_regular, ui_font_bold)
    
    # Map the source corners [TL, TR, BR, BL] of the UI
    src_pts = [(0, 0), (ui_w, 0), (ui_w, ui_h), (0, ui_h)]
    dst_pts = quad
    
    # Compute perspective transform coefficients
    coeffs = get_perspective_transform(src_pts, dst_pts)
    
    # Warp the UI image
    warped_ui = s6_ui.transform(s6_base.size, Image.PERSPECTIVE, coeffs, Image.BICUBIC)
    
    # Composite the warped UI onto the base image
    s6_base = Image.alpha_composite(s6_base, warped_ui)
    
    s6_draw = ImageDraw.Draw(s6_base)
    draw_caption(s6_draw, "didn't think about it. just knew. near. — send this to someone in their first month · intuiscale, coming soon", s6_base.width, s6_base.height, caption_font)
    s6_base.save(os.path.join(BASE_DIR, "slide_6.png"), "PNG")
    
    # -----------------------------------------------------------------
    # Contact Sheet (3x2 grid of 6 slides)
    # -----------------------------------------------------------------
    print("Creating Contact Sheet...")
    slides = [Image.open(os.path.join(BASE_DIR, f"slide_{i}.png")) for i in range(1, 7)]
    
    # Grid properties (3x2 layout of 360x640 thumbnails)
    grid_w = 3 * 360
    grid_h = 2 * 640
    contact_sheet = Image.new("RGB", (grid_w, grid_h), (255, 255, 255))
    
    for idx, slide in enumerate(slides):
        thumb = slide.resize((360, 640), Image.Resampling.LANCZOS)
        x_offset = (idx % 3) * 360
        y_offset = (idx // 3) * 640
        contact_sheet.paste(thumb, (x_offset, y_offset))
        
    contact_sheet.save(os.path.join(BASE_DIR, "contact-sheet.png"), "PNG")
    print("Pipeline complete!")

if __name__ == "__main__":
    main()
