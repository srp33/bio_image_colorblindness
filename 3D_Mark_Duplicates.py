with open("/tmp/eLife_Metrics.tsv") as in_file:
    in_file.readline()

    image_dict = {}

    for line in in_file:
        line_items = line.split("\t")

        path_parts = line_items[1].split("-")
        image_unique_key = f"{path_parts[1]}____{path_parts[2]}"
        image_version = path_parts[3]

        if image_unique_key not in image_dict:
            image_dict[image_unique_key] = []

        image_dict[image_unique_key].append(image_version)

for key, value in image_dict.items():
    image_dict[key] = sorted(value)

with open("/tmp/eLife_Metrics.tsv") as in_file:
    with open("/tmp/eLife_Metrics2.tsv", "w") as out_file:
        header_items = in_file.readline().split("\t")
        header_items.insert(2, "is_duplicate")
        out_file.write("\t".join(header_items))

        for line in in_file:
            line_items = line.split("\t")

            path_parts = line_items[1].split("-")
            image_unique_key = f"{path_parts[1]}____{path_parts[2]}"
            image_version = path_parts[3]

            is_duplicate = int(image_dict[image_unique_key].index(image_version) > 0)
            line_items.insert(2, str(is_duplicate))

            out_file.write("\t".join(line_items))
