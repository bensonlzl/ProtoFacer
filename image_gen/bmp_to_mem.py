from PIL import Image
import sys

def convert_to_rgb444(r, g, b):
    """
    Converts 8-bit RGB values to 4-bit RGB values (RGB444 format).
    """
    r4 = (r >> 4) & 0xF  # Take the upper 4 bits
    g4 = (g >> 4) & 0xF
    b4 = (b >> 4) & 0xF
    rgb444 = (r4 << 8) | (g4 << 4) | b4  # Combine into 12-bit RGB444 format
    return rgb444

def process_image(image_name):
    """
    Processes a 32x128 bitmap image and outputs two .mem files in RGB444 format.
    """
    image_path = image_name + ".bmp" 

    img = Image.open(image_path)
    img = img.convert("RGB") 

    if img.size != (128, 32):
        print(img.size)
        raise ValueError("The image must be 32 pixels tall and 128 pixels wide.")

    # Split the image into top and bottom 16 rows
    top_half = img.crop((0, 0, 128, 16))
    bottom_half = img.crop((0, 16, 128, 32))

    # Create .mem files
    for half, filename in [(top_half, image_name + "_upper.mem"), (bottom_half, image_name + "_lower.mem")]:
        with open(filename, 'w') as mem_file:
            for y in range(half.height):
                for x in range(half.width):
                    r, g, b = half.getpixel((x, y))
                    rgb444 = convert_to_rgb444(r, g, b)

                    # Write 12-bit value as a 3-digit hex with a newline
                    mem_file.write(f"{rgb444:03x}\n")

        print(f".mem file '{filename}' generated.")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <bmp image to convert without extension> ")

    else:
        image_name = sys.argv[1]
        process_image(image_name)

