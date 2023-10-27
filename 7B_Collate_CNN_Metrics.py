from glob import glob
import sys

out_file_path = "Cross_Validation_Results_CNN.tsv"

with open(out_file_path, "w") as out_file:
    out_file.write("iteration\tfold\talgorithm\tauroc\n")

    for metrics_file_path in sorted(glob(f"CNN_Metrics/model_*/iteration_*/fold_*/metrics.tsv")):
        parts = metrics_file_path.split("/")
        model = parts[1].split("_")[1]
        iteration = parts[2].split("_")[1]
        fold = parts[3].split("_")[1]

        auroc = None
        with open(metrics_file_path) as metrics_file:
            for line in metrics_file:
                if line.startswith("auc"):
                    auroc = float(line.rstrip("\n").split("\t")[1])

        out_file.write(f"{iteration}\t{fold}\t{model}\t{auroc}\n")
