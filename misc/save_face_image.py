import serial
import numpy as np
import cv2  # OpenCV for image saving and viewing

# Constants for the image dimensions and serial port
SERIAL_PORT = "/dev/ttyUSB1"
BAUD_RATE = 115200
IMAGE_HEIGHT = 320
IMAGE_WIDTH = 180
OUTPUT_IMAGE_PATH = "received_image.png"

def read_serial_image():
    """Reads an 8-bit image from the serial port."""
    try:
        # Open the serial port
        with serial.Serial(SERIAL_PORT, BAUD_RATE, timeout=10) as ser:
            print(f"Listening to {SERIAL_PORT} at {BAUD_RATE} baud...")
            
            # Create an empty numpy array to store the image
            image = np.zeros((IMAGE_HEIGHT, IMAGE_WIDTH), dtype=np.uint8)

            count_white_pixels = 0
            while True:
                pixel = ser.read(1)
                # print(pixel[0])
                print(pixel[0])
                if pixel[0] == 255:
                    count_white_pixels += 1
                elif pixel[0] == 0 and count_white_pixels >= 180: # if we find the sync region, break
                    break
                else:
                    count_white_pixels = 0

            ser.read(20 * 180 - 1)
            
            # Read the image pixel-by-pixel
            for row in range(IMAGE_HEIGHT):
                for col in range(IMAGE_WIDTH):
                    pixel = ser.read(1)  # Read one byte
                    if not pixel:  # If no byte is received within timeout
                        raise ValueError("Serial timeout: incomplete image received.")
                    image[row, col] = pixel[0]  # Store the byte as a pixel
            
            print("Image received successfully.")
            return image
    except serial.SerialException as e:
        print(f"Error with the serial connection: {e}")
    except ValueError as e:
        print(f"Error while reading image: {e}")
    return None

def save_image(image):
    """Saves the image as a PNG file."""
    if image is not None:
        cv2.imwrite(OUTPUT_IMAGE_PATH, image)
        print(f"Image saved to {OUTPUT_IMAGE_PATH}")
    else:
        print("No image to save.")

if __name__ == "__main__":
    # Read the image from the serial port
    image = read_serial_image()
    
    # Save the image as a file
    save_image(image)
