import os
import random
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
