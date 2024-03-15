# I obtained the articles as of March 13, 2024
# They are from the PMC OA Subset - Commercial Use
# I did not use the incremental files.
# So they were selected from December 17, 2023 and earlier.

library(tidyverse)

fileListTmpFilePath = "/tmp/PMC_File_List.tsv.gz"
fileListTmpFilePath2 = "/tmp/PMC_File_List2.tsv.gz"
fileListTmpFilePath3 = "/tmp/PMC_File_List3.tsv.gz"

if (!file.exists(fileListTmpFilePath)) {
    # These contain publication timestamps.
    urls = paste0("https://ftp.ncbi.nlm.nih.gov/pub/pmc/oa_bulk/oa_comm/txt/oa_comm_txt.PMC0",
                c("00", "01", "02", "03", "04", "05", "06", "07", "08", "09", "10"),
                "xxxxxx.baseline.2023-12-17.filelist.txt")

    read_tsv(urls, col_types = "cccTc") %>%
      filter(Retracted == "no") %>%
      filter(License == "CC BY") %>%
      dplyr::rename(PMCID = AccessionID, Timestamp = `LastUpdated (YYYY-MM-DD HH:MM:SS)`) %>%
      select(PMCID, Timestamp) %>%
      write_tsv(fileListTmpFilePath)
    # 3,621,654 articles

    # These contain the path where the individual details can be found.
    read_tsv("https://ftp.ncbi.nlm.nih.gov/pub/pmc/oa_comm_use_file_list.txt", skip=1, col_names=FALSE) %>%
        dplyr::rename(File_Path = X1, Citation = X2, PMCID = X3, PMID = X4, License = X5) %>%
        filter(License == "CC BY") %>%
        select(-License) %>%
        write_tsv(fileListTmpFilePath2)
    # 3,807,800 articles
    # 2024-03-15 10:23:02

    read_tsv(fileListTmpFilePath) %>%
      inner_join(read_tsv(fileListTmpFilePath2)) %>%
      write_tsv(fileListTmpFilePath3)
    # 3,621,508 articles after inner join
}

read_tsv(fileListTmpFilePath3) %>%
    slice_sample(n = 2000) %>%
    arrange(Timestamp) %>%
    print()

#TODO: Randomly select articles. Retrieve images.
