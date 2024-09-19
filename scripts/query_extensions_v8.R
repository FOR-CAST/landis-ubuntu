# library(dplyr)
library(glue)
library(googledrive)
# library(lubridate)
# library(readxl)
# library(rprojroot)

drive_auth()

landis.github.url <- "https://github.com/LANDIS-II-Foundation"

## identify all relevant LANDIS-II repos
apiurl <- glue("https://api.github.com/orgs/{basename(landis.github.url)}/repos?page=$PAGE&per_page=150")
ua <- httr::user_agent("FOR-CAST/landis-ubuntu") ## TODO

req <- httr::GET(apiurl, ua)
httr::stop_for_status(req)

landis.repos <- httr::content(req) |>
  lapply("[", c("git_url", "updated_at")) |>
  lapply(dplyr::bind_cols) |>
  dplyr::bind_rows() |>
  dplyr::mutate(git_url = gsub("git://github[.]com/|[.]git$", "", git_url)) |>
  dplyr::mutate(updated_at = lubridate::as_date(updated_at)) |>
  dplyr::filter(!grepl("Archive|Core-Model|Extensions|Foundation-Documents|Project", git_url)) |>
  dplyr::filter(updated_at > lubridate::ymd("2024-01-01")) ## only keep recently updated

landis.libraries <- grep("/Library-", landis.repos[["git_url"]], value = TRUE) |>
  c(
    ## additional libraries that haven't been recently updated
    "Library-Biomass",
    "Library-Core",
    "Library-Datasets",
    "Library-Metadata",
    "Library-Universal-Cohort",
    "Support-Library-Dlls-v8"
  ) |>
  unique() |>
  sort()

## use the google sheet of currently supported v8 extensions
landis.extensions.xlsx <- as_id("12o6F6FAlIt2Qe03lrfi4fSIOhHY1zgWkNN_YA-GS5e0") |>
  drive_download(overwrite = TRUE) |>
  _[["local_path"]]

landis.extensions.v8 <- readxl::read_excel(landis.extensions.xlsx) |>
  dplyr::rename(Name = "Succession Extensions", Updated = "Last Updated") |>
  na.omit() |>
  dplyr::filter(Link != "Coming soon!") |>
  dplyr::pull(Link) |>
  basename()

landis.extensions <- grep("/Extension-", landis.repos[["git_url"]], value = TRUE) |>
  basename() |>
  sort()

## not yet updated; check back November 2024 for updates/changes
landis.extensions.notcurrent <- landis.extensions[!landis.extensions %in% landis.extensions.v8]

## extensions to omit(for now)
landis.extensions.omit <- c(
  landis.extensions.notcurrent,
  "Extension-Biomass-Browse",
  "Extension-Biomass-Hurricane",
  "Extension-Local-Habitat-Suitability-Output",
  "Extension-NECN-Succession",
  "Extension-Output-Wildlife-Habitat",
  "Extension-Social-Climate-Fire"
) |> sort()

## extensions to keep which are updated for v8 as of October 2024
landis.extensions <- landis.extensions[!landis.extensions %in% landis.extensions.omit]
