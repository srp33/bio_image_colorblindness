# I obtained the articles as of March 19, 2024
# They are from the PMC OA Subset - Commercial Use
# I did not use the incremental files.
# So they were selected from December 17, 2023 and earlier.

library(tidyverse)
library(xml2)

set.seed(0)
dir.create("PMC_Images", showWarnings=FALSE, recursive=TRUE)

tmpArticleFilePath = "/tmp/Articles.tsv.gz"

if (!file.exists(tmpArticleFilePath)) {
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
        select(-Citation) %>%
        write_tsv(tmpArticleFilePath)
}

candidateArticles = read_tsv(tmpArticleFilePath)

numArticles = nrow(candidateArticles)
# 2,730,205 article candidates

# We randomly select enough that we will be able to get 2,000 after filtering.
candidateArticles = slice_sample(candidateArticles, n = 2000)

# Retrieve images.
for (i in 1:nrow(candidateArticles)) {
    filePath = pull(candidateArticles[i,], File_Path)
    url = str_c("https://ftp.ncbi.nlm.nih.gov/pub/pmc/", filePath)

    pmcid = pull(candidateArticles[i,], PMCID)
    print(pmcid)

    pmid = pull(candidateArticles[i,], PMID) %>%
        str_replace("PMID:", "")
    publicationDate = pull(candidateArticles[i,], Publication_Date)

    tmpDirPath = str_c("/tmp/", pmcid)
    tmpFilePath = str_c(tmpDirPath, "/", basename(url))

    unlink(tmpDirPath, recursive=TRUE)
    dir.create(tmpDirPath, showWarnings=FALSE, recursive=TRUE)

    dest_dir_path = str_c("PMC_Images/", pmcid)
    dir.create(dest_dir_path, showWarnings=FALSE, recursive=TRUE)
    ignore_file_path = str_c(dest_dir_path, "/IGNORE")

    if (file.exists(ignore_file_path)) {
        print(str_c("Based on prior evaluation, ignoring ", pmcid))
        unlink(tmpDirPath, recursive=TRUE)
        next
    }

    dest_jpg_file_pattern = str_c("PMC_Images/", pmcid, "/*.jpg")
    if (length(Sys.glob(dest_jpg_file_pattern))) {
        print(str_c("Already saved .jpg file: ", pmcid))
        unlink(tmpDirPath, recursive=TRUE)
        next
    }

    download.file(url, tmpFilePath)
    untar(tarfile = tmpFilePath, exdir = tmpDirPath)

    xmlFilePath = Sys.glob(str_c(tmpDirPath, "/", pmcid, "/*nxml"))
    print(str_c("Parsing ", xmlFilePath))
    xml = str_c(suppressWarnings(readLines(xmlFilePath)), collapse = " ")
    journal_title = str_extract(xml, "<journal-title>(.+?)</journal-title>", group=1)
    article_title = str_extract(xml, "<article-title>(.+?)</article-title>", group=1)
    article_type = str_extract(xml, " article-type=\"(.+?)\".+?>", group=1)

    if (article_type != "research-article") {
        print(str_c("Not a research article: ", article_type, "."))
        file.create(ignore_file_path)
        unlink(tmpDirPath, recursive=TRUE)
        next
    }

    fig_xml = read_xml(xml)
    graphic_nodes = xml_find_all(fig_xml, "//fig//graphic")
    graphic_names = sapply(graphic_nodes, xml_attr, "href")
    jpg_file_paths = str_c(tmpDirPath, "/", pmcid, "/", graphic_names, ".jpg")

    if (length(jpg_file_paths) == 0) {
        print(str_c("No matching figures for ", pmcid, "."))
        file.create(ignore_file_path)
        unlink(tmpDirPath, recursive=TRUE)
        next
    }

    selected_jpg_file_path = sample(jpg_file_paths, size=1)
    dest_jpg_file_path = str_c(dest_dir_path, "/", basename(selected_jpg_file_path))
    file.copy(selected_jpg_file_path, dest_jpg_file_path)
    unlink(tmpDirPath, recursive=TRUE)

    outRow = tibble(PMCID=pmcid, PMID=pmid, Title=article_title, Journal=journal_title, Publication_Date=publicationDate, File_Path=str_c("PMC_Images/", pmcid, "/", basename(dest_jpg_file_path)))
    write_tsv(outRow, str_c("PMC_Images/", pmcid, "/data.tsv"))

    numSaved = length(Sys.glob("PMC_Images/PMC*/data.tsv"))

    if (numSaved == 2000) {
        break
    } else {
        print(str_c(numSaved, " saved."))
    }
}

read_tsv(Sys.glob("PMC_Images/PMC*/data.tsv")) %>%
  write_tsv("PMC_Selected_Articles.tsv")

for (filePath in Sys.glob("PMC_Images/PMC*/data.tsv")) {
  unlink(filePath)
}

for (filePath in Sys.glob("PMC_Images/PMC*/IGNORE")) {
  unlink(filePath)
  unlink(dirname(filePath), recursive=TRUE)
}
