import sys

file_path = sys.argv[1]

current_metrics_dict = {}

with open(file_path) as my_file:
    header_line = my_file.readline()

    for line in my_file:
        line_items = line.rstrip("\n").split("\t")
        current_metrics_dict[line_items[0]] = float(line_items[1])

    current_metrics_dict["f1"] = 2 * (current_metrics_dict["precision"] * current_metrics_dict["recall"]) / (current_metrics_dict["precision"] + current_metrics_dict["recall"])

with open(file_path, "w") as my_file:
    my_file.write(header_line)

    for key, value in sorted(current_metrics_dict.items()):
        my_file.write(f"{key}\t{value}\n")
