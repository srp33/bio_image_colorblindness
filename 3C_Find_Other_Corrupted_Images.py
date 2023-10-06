import glob
from struct import unpack

#Used Yasoob's script. https://yasoob.me/posts/understanding-and-writing-jpeg-decoder-in-python/

marker_mapping = {
    0xffd8: "Start of Image",
    0xffe0: "Application Default Header",
    0xffdb: "Quantization Table",
    0xffc0: "Start of Frame",
    0xffc4: "Define Huffman Table",
    0xffda: "Start of Scan",
    0xffd9: "End of Image"
}

#JPEG class was copied from https://yasoob.me/posts/understanding-and-writing-jpeg-decoder-in-python/
class JPEG:
    def __init__(self, image_file):
        with open(image_file, 'rb') as f:
            self.img_data = f.read()

    def decode(self):
        data = self.img_data

        while(True):
            #open the image_data, >H tells struct to treat the data as big-endian and as unsigned short.
            #Read first three big-endian values
            marker, = unpack(">H", data[0:2])
            #Check if marker is the start of the image
            if marker == 0xffd8:
                data = data[2:]
            #Check if marker is the end of the image, end decode
            elif marker == 0xffd9:
                return
            #Check if marker is the start of Scan, skips to end of file.
            elif marker == 0xffda:
                data = data[-2:]
            else:
                lenchunk, = unpack(">H", data[2:4])
                data = data[2+lenchunk:]
            if len(data)==0:
                break

def check_image(image_dir_path):
    print(image_dir_path)
    original_file_path = f"{image_dir_path}/original.jpg"
    deut_file_path = f"{image_dir_path}/deut.jpg"

    original_image = JPEG(original_file_path)

    try:
        original_image.decode()
    except:
        print(f"{original_file_path} is corrupted.")

    deut_image = JPEG(deut_file_path)

    try:
        deut_image.decode()
    except:
        print(f"{deut_file_path} is corrupted.")

#Iterate through all images and print path of each corrupted image.
for image_dir_path in sorted(glob.glob("/shared_dir/ImageSample1to5000/*")):
    check_image(image_dir_path)

for image_dir_path in sorted(glob.glob("/shared_dir/ImageSample5001to6000/*")):
    check_image(image_dir_path)
