import sys
import os
from PIL import Image

def fix_icon_opaque():
    source_path = "Maccy/Assets.xcassets/AppIcon.appiconset/AppIcon (Big Sur)-1024w.png"
    temp_save_path = "FlowClipOpaqueMaster.png"
    
    if not os.path.exists(source_path):
        print(f"Error: Source file not found at {source_path}")
        return

    try:
        img = Image.open(source_path).convert("RGBA")
        print(f"Original size: {img.size}")
        
        # Sample color from the top center edge (assuming it represents the general background/rim)
        # We take a pixel slightly inside to avoid anti-aliasing artifacts
        sample_coords = (512, 10) 
        bg_color = img.getpixel(sample_coords)
        print(f"Sampled background color at {sample_coords}: {bg_color}")
        
        # If the sample is transparent, try searching for the first opaque pixel
        if bg_color[3] < 255:
            print("Sampled pixel has transparency, searching for opaque pixel...")
            # Fallback to center if edge is transparent (which would be weird for a full-width icon)
            bg_color = img.getpixel((512, 512))
            print(f"Fallback sample at center: {bg_color}")
            
        # Create pure opaque color (ignore alpha from sample if any, assume full opacity needed)
        # Note: bg_color is (R, G, B, A). We want (R, G, B, 255).
        opaque_color = (bg_color[0], bg_color[1], bg_color[2], 255)
        
        # Create a new background image
        bg = Image.new("RGBA", (1024, 1024), opaque_color)
        
        # Composite the icon over the background
        # usage: Image.alpha_composite(im1, im2) expects both to be RGBA
        final_img = Image.alpha_composite(bg, img)
        
        # Save as PNG (opaque)
        # Removing alpha channel to ensure no transparency flags remain
        final_img = final_img.convert("RGB")
        final_img.save(temp_save_path, "PNG")
        print(f"Saved opaque master to {temp_save_path}")
        
    except Exception as e:
        print(f"An error occurred: {e}")

if __name__ == "__main__":
    fix_icon_opaque()
