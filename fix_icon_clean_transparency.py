import sys
import os
from PIL import Image

def fix_icon_transparency():
    source_path = "Maccy/Assets.xcassets/AppIcon.appiconset/AppIcon (Big Sur)-1024w.png"
    temp_save_path = "FlowClipCleanTransparentMaster.png"
    
    if not os.path.exists(source_path):
        print(f"Error: Source file not found at {source_path}")
        return

    try:
        img = Image.open(source_path).convert("RGBA")
        print(f"Original size: {img.size}")
        
        # Create a new image data list
        datas = img.getdata()
        
        new_data = []
        for item in datas:
            # item is (R, G, B, A)
            if item[3] == 0:
                # If transparent, make it White Transparent
                new_data.append((255, 255, 255, 0))
            else:
                new_data.append(item)
                
        img.putdata(new_data)
        
        img.save(temp_save_path, "PNG")
        print(f"Saved clean transparent master to {temp_save_path}")
        
    except Exception as e:
        print(f"An error occurred: {e}")

if __name__ == "__main__":
    fix_icon_transparency()
