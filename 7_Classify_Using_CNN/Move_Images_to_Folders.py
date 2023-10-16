import glob
import os
import random

in_file_path = "Image_Metrics_Classification_Data.tsv"
out_file_path = "Training_Image_Assignments.tsv"

#mkdir -p ClassificationImages
#training_friendly_dir_path = "TrainingImages/friendly"
#training_unfriendly_dir_path = "TrainingImages/unfriendly"
#testing_friendly_dir_path = "TestingImages/friendly"
#testing_unfriendly_dir_path = "TestingImages/unfriendly"

metrics_file_path = "eLife_Metrics.tsv"
out_tsv_file_path = "Image_Assignments.tsv"

is_duplicated_dict = {}
with open(metrics_file_path) as metrics_file:
    metrics_file.readline()

    for line in metrics_file:
        line_items = line.split("\t")
        image_file_name = os.path.basename(line_items[1]).replace(".jpg", "")
        is_duplicated = line_items[2] == "1"
        is_duplicated_dict[image_file_name] = is_duplicated

random.seed(33)

training_src_file_paths = sorted(glob.glob(f"{training_src_dir_path}/*"))
random.shuffle(training_src_file_paths)
training_file_paths = training_src_file_paths[:4000]
validation_file_paths = training_src_file_paths[4000:5000]

with open(out_tsv_file_path, "w") as out_file:
    out_file.write("file_path\n")
    for file_path in training_src_file_paths:
        if not is_duplicated_dict[os.path.basename(file_path).replace(".jpg", "")]:
            out_file.write(f"{os.path.basename(file_path)}\n")
print(out_tsv_file_path)

import sys
sys.exit()

folder = ""
destinationFolder = ""
imagePercent = 0.1

def withholdTest(folder):
    goodFolder = os.path.join(folder,"CVDfriendly")
    badFolder = os.path.join(folder,"CVDunfriendly")
    badCount=0
    badList = []
    goodCount = 0
    goodList = []

    for file in os.walk(badFolder):
        badCount+=1
        badList.append(str(file))

    for file in os.walk(goodFolder):
        goodCount+=1
        goodList.append(str(file))


    totalCount = badCount+goodCount

    amountGood = int(goodCount/totalCount * (totalCount*imagePercent))
    amountBad = int(badCount/totalCount * (totalCount*imagePercent))

    goodFilesToMove = [goodList.pop(random.randrange(0, len(goodCount))) for _ in range(amountGood)]

    for file in goodFilesToMove:
        src = os.path.join(goodFolder, file)
        dst = os.path.join(destinationFolder,"CVDfriendly")
        shutil.move(src, dst)

    badFilesToMove = [goodList.pop(random.randrange(0, len(badCount)))

for _ in range(amountBad)]
    for file in badFilesToMove:
        src = os.path.join(badFolder, file)
        dst = os.path.join(destinationFolder,"CVDunfriendly")
        shutil.move(src, dst)

withholdTest(folder)
