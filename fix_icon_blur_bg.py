import sys
import os
from PIL import Image, ImageFilter

def fix_icon_blur():
    source_path = "Maccy/Assets.xcassets/AppIcon.appiconset/AppIcon (Big Sur)-1024w.png"
    temp_save_path = "FlowClipBlurMaster.png"
    
    if not os.path.exists(source_path):
        print(f"Error: Source file not found at {source_path}")
        return

    try:
        # Open source and convert to RGBA
        img = Image.open(source_path).convert("RGBA")
        print(f"Original size: {img.size}")
        
        # 1. Create the Background
        # Resize the image to be slightly larger or just fill the square?
        # We want the background to be a washed-out version of the logo colors.
        # Let's resize it to fill 1024x1024 (ignoring aspect ratio slightly if needed, or cropping)
        # Actually, just resizing the whole RGBA image to 1024x1024 is fine for the background source.
        
        bg_source = img.resize((1024, 1024), Image.LANCZOS)
        
        # Now create an opaque background color layer to put behind the blurred transparency?
        # If we blur a transparent image, the edges fade to transparent. 
        # When we flatten, transparent becomes black/white?
        # We want to fill transparency with the edge colors.
        
        # Better heuristic:
        # Create a solid color background based on the average color of the image?
        # Or...
        # Resize to 1 pixel to get average color.
        avg_color_img = img.resize((1, 1), Image.LANCZOS)
        avg_color = avg_color_img.getpixel((0, 0))
        print(f"Average Color: {avg_color}")
        
        # Create a base solid layer of this average color
        solid_bg = Image.new("RGBA", (1024, 1024), avg_color)
        
        # Now create a "Zoomed" version of the icon to act as texture
        # We assume the icon is centered. We crop the center 50% and resize to 100%.
        w, h = img.size
        crop_box = (int(w*0.25), int(h*0.25), int(w*0.75), int(h*0.75))
        zoomed = img.crop(crop_box).resize((1024, 1024), Image.LANCZOS)
        
        # Apply heavy blur to the zoomed image
        blurred_texture = zoomed.filter(ImageFilter.GaussianBlur(50))
        
        # Composite Blurred Texture over Solid BG (to fill any transparency in texture)
        bg = Image.alpha_composite(solid_bg, blurred_texture)
        
        # 2. Composite the Real Icon on top
        # We need to center the original icon on this background.
        # If original is 1024x1024, just composite.
        final_img = Image.alpha_composite(bg, img)
        
        # 3. Flatten to RGB (Opaque)
        final_img = final_img.convert("RGB")
        
        final_img.save(temp_save_path, "PNG")
        print(f"Saved blurred background master to {temp_save_path}")
        
    except Exception as e:
        print(f"An error occurred: {e}")

if __name__ == "__main__":
    fix_icon_blur()
