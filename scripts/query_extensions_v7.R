# library(dplyr)
library(glue)
library(googledrive)
# library(readxl)

drive_auth()

landis.github.url <- "https://github.com/LANDIS-II-Foundation"

## use the google sheet of currently supported v7 extensions
landis.extensions.xlsx <- as_id("1BvaJeaLWHcNuXfb3D17lHFJ3Y02K9h5cEmBz1T4VsIQ") |>
  drive_download(overwrite = TRUE) |>
  _[["local_path"]]

landis.extensions.v7 <- readxl::read_excel(landis.extensions.xlsx) |>
  dplyr::rename(Name = "...1", Link = "...2", Updated = "...3", CWBS = "Compatible w/...5") |>
  dplyr::select(Name, Link, Updated, CWBS) |>
  dplyr::filter(CWBS == "X") |>
  dplyr::filter(!Name %in% c("Succession Extensions", "BFOLDS Fire")) |>
  na.omit() |>
  dplyr::pull(Link) |>
  basename() |>
  sort()
