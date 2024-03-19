# I obtained the articles as of March 19, 2024
# They are from the PMC OA Subset - Commercial Use
# I did not use the incremental files.
# So they were selected from December 17, 2023 and earlier.

library(tidyverse)

set.seed(0)
dir.create("PMC/Images", showWarnings=FALSE)

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
    select(-Citation) -> candidateArticles

numArticles = nrow(candidateArticles)
print(numArticles)
# 2,730,204 article candidates

candidateArticles = slice_sample(candidateArticles, n = numArticles)

selectedArticles = NULL

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

    if (!file.exists(tmpFilePath)) {
        unlink(tmpDirPath)
        dir.create(tmpDirPath, showWarnings=FALSE)

        download.file(url, tmpFilePath)
        untar(tarfile = tmpFilePath, exdir = tmpDirPath)
    }

    xmlFilePath = Sys.glob(str_c(tmpDirPath, "/", pmcid, "/*nxml"))
    xml = str_c(suppressWarnings(readLines(xmlFilePath)), collapse = " ")
    journal_title = str_extract(xml, "<journal-title>(.+?)</journal-title>", group=1)
    article_title = str_extract(xml, "<article-title>(.+?)</article-title>", group=1)
    article_type = str_extract(xml, " article-type=\"(.+?)\".+?>", group=1)

    if (article_type != "research-article") {
        print(str_c("Not a research article: ", article_type, "."))
        next
    }

    fig_xml = str_extract_all(xml, "<fig.*?>.*?<graphic xlink:href=\".*?\".*?\\/>.*?<\\/fig>", simplify=TRUE)
    jpg_file_prefixes = str_extract(fig_xml, "<graphic xlink:href=\"(.*?)\".*?\\/>", group=1)
    jpg_file_paths = str_c(tmpDirPath, "/", pmcid, "/", jpg_file_prefixes, ".jpg")

    if (length(jpg_file_paths) == 0) {
        print(str_c("No matching figures for ", pmcid, "."))
        next
    }

    selected_jpg_file_path = sample(jpg_file_paths, size=1)
    dest_jpg_file_path = str_c("PMC/Images/", pmcid, "____", basename(selected_jpg_file_path))
    file.copy(selected_jpg_file_path, dest_jpg_file_path)

    outRow = tibble(PMCID=pmcid, PMID=pmid, Title=article_title, Journal=journal_title, Publication_Date=publicationDate, File_Name=basename(selected_jpg_file_path))

    if (is.null(selectedArticles)) {
        selectedArticles = outRow
    } else {
        selectedArticles = bind_rows(selectedArticles, outRow)
    }

    if (nrow(selectedArticles) == 2000) {
        break
    } else {
        print(str_c(nrow(selectedArticles), " processed"))
    }
}

write_tsv(selectedArticles, "PMC/Selected_Articles.tsv")
unlink(tmpDirPath)
