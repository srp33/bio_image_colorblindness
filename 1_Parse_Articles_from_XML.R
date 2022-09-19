library(httr)
library(tidyverse)
library(xml2)

out_file_path = "all_eLife_articles.tsv"

if (file.exists(out_file_path)) {
    print(paste0(out_file_path, " already exists, so the GitHub repository does not need to be parsed."))
} else {
  if (!dir.exists("elife-article-xml")) {
    # NOTE: The git command-line tool must be installed on your computer.
    system("git clone https://github.com/elifesciences/elife-article-xml")
  }

  # Get paths to all XML files
  files <- list.files(path="elife-article-xml/articles", pattern="*.xml", full.names=TRUE)

  files_found <- c()

  articles_tbl = NULL
  former_id = ""
  f <- 1

  for (xm in files) {
    #convert file path to the url of the xml on github
    xml_id = sub("elife-article-xml/articles/", "elifesciences/elife-article-xml/blob/master/articles/", xm)
    xml_url = paste0("https://github.com/", xml_id)

    #find the current version of the file you are looking at 
    v_number = str_extract(xm, "-v[0-9]+")
    number = str_extract(v_number, "[0-9]+")

    #calculates what the next version would be (if it exists)
    v_next_number = sub(number, (strtoi(number)+1), v_number)
    xm_v = sub(v_number, v_next_number, xm)
  
    #checks to see if a newer version of the article exists and has not been visited yet
    if ((xm_v %in% files) & !(xm_v %in% files_found)) { 
      files_found[f] <- xm_v
      next
    }

    xm_v = ""
    f <- f+1
  
    print(xm)
  
    #read the xml file
    article_response = GET(xml_url)
    article = content(article_response, as = "text")
    raw_xml = str_extract(article, "elifesciences/elife-article-xml/raw/master/articles/.+xml")
    raw_xml = paste0("https://github.com/", raw_xml)
    xml_response = GET(raw_xml)
    xml_content = content(xml_response, as = "text")
    xml_content <- gsub("[\n]", "", xml_content)
  
    #gets what the current version of the article is
    version = str_extract(xm, "v[1-9]")
  
    #gets the article id
    article_id = str_extract_all(xml_content, "publisher-id\\\">[0-9]+", )
    article_id = sub("publisher-id\\\">", "", article_id) # add this to tsv

    #gets the doi 
    doi = str_extract(xml_content, "doi\\\">[0-9]+\\.[0-9]+/eLife\\.[0-9]+")
    doi = sub('doi\\\">', "", doi)
    doi_full = paste0("https://doi.org/", doi)
  
    #gets the article type (i.e. Research Article, Insight, etc)
    type = str_extract_all(xml_content, 'subj-group subj-group-type="display-channel"><subject>[A-Za-z ]+')
  
    type = sub('subj-group subj-group-type="display-channel"><subject>', "", type)
    type <- tolower(type)
  
    #gets the subject of the article 
    subject = str_extract_all(xml_content, '<subj-group subj-group-type="heading"><subject>[A-Z a-z]+')
    new_subject = c()
    i <- 1

    for (s in subject[[1]]) {
      s = sub('<subj-group subj-group-type="heading"><subject>', "", s)
      if (s == type) { #skips the subject if it is the same as "type" (since sometimes it grabs them together)
        next
      }

      new_subject[i] <- s
      i <- i+1
    }

    subjects = paste(unlist(new_subject),collapse=", ")
  
    #gets the day, month, and year
    day = str_extract(xml_content, "<day>[0-9]+")
    month = str_extract(xml_content, "</day><month>[0-9]+")
    year = str_extract(xml_content, "</month><year>[0-9]+")
    day = sub("<day>", "", day)
    month = sub("</day><month>", "", month)
    year = sub("</month><year>", "", year)
  
    #format the date so that it is YYYY-MM-DD
    full_date = paste0(year, month, day)
    date_formatted = as.Date(full_date, format="%Y%m%d")
  
    #turn everything we want into a single row dataframe
    row <- c(doi_full, type, subjects, as.character(date_formatted), as.character(article_id), version)
    row_df <- data.frame(matrix(ncol=length(row), nrow=0))
    new_row_df <- rbind(row_df, row)
    colnames(new_row_df) <- c("DOI", "TYPE", "SUBJECT(S)", "DATE", "ARTICLE ID", "VERSION")

    if (!(article_id %in% articles_tbl$`ARTICLE ID`)) { #if we have not yet found an article with this same id
      if (is.null(articles_tbl)) {
        articles_tbl = new_row_df
      } else {
        articles_tbl = bind_rows(articles_tbl, new_row_df)
      }
    }
  }

  write_tsv(articles_tbl, out_file_path)
}
