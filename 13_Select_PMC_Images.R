# I obtained the articles as of March 13, 2024
# They are from the PMC OA Subset - Commercial Use
# I did not use the incremental files.
# So they were selected from December 17, 2023 and earlier.

library(tidyverse)

if (!dir.exists("PMC"))
    dir.create("PMC")

fileListFilePath = "PMC/PMC_File_List.tsv.gz"

if (!file.exists(fileListFilePath)) {
    read_tsv("https://ftp.ncbi.nlm.nih.gov/pub/pmc/oa_comm_use_file_list.txt", skip=1, col_names=FALSE) %>%
        dplyr::rename(File_Path = X1, Citation = X2, PMCID = X3, PMID = X4, License = X5) %>%
        filter(License == "CC BY") %>%
        select(-License) %>%
        mutate(Publication_Date = str_extract(Citation, "\\d\\d\\d\\d [A-Z][a-z][a-z] \\d{1,2}")) %>%
        filter(!is.na(Publication_Date)) %>%
        mutate(Publication_Date = as.Date(Publication_Date, format = "%Y %b %d")) %>%
        mutate(Publication_Year = year(Publication_Date)) %>%
        filter(Publication_Year >= 2012 & Publication_Year <= 2022) %>%
        mutate(Journal = str_extract(Citation, "(.+)\\. \\d{4} ", group=1)) %>%
        select(-Citation) -> candidates

    print(nrow(candidates))

    slice_sample(candidates, n = 2000) %>%
        arrange(Publication_Date) %>%
        write_tsv(fileListFilePath)

    # 2,730,105 article candidates
}

# TODO: Ignore journals and articles with "review" in the title.
# TODO: Parse through the metadata. Does anything indicate article type? Yes.
# TODO: Download some extras to make sure we have at least 2000 after final filtering.

selectedArticles = read_tsv(fileListFilePath)

# Retrieve images.
for (i in 1:nrow(selectedArticles)) {
    filePath = pull(selectedArticles[i,], File_Path)
    url = paste0("https://ftp.ncbi.nlm.nih.gov/pub/pmc/", filePath)

    pmcid = pull(selectedArticles[i,], PMCID)
    print(pmcid)

    tmpDirPath = paste0("/tmp/", pmcid)
    tmpFilePath = paste0(tmpDirPath, "/", basename(url))

    if (!file.exists(tmpFilePath)) {
        unlink(tmpDirPath)
        dir.create(tmpDirPath, showWarnings=FALSE)

        download.file(url, tmpFilePath)
#        untar(tarfile = tmpFilePath, exdir = tmpDirPath)

#        jpgFilePaths = Sys.glob(paste0(tmpDirPath, "/", pmcid, "/*.jpg"))

#        print(length(jpgFilePaths))
#        unlink(tmpDirPath)

#        break
    }
}
