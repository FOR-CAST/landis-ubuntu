## This script is intended to be run during docker build for a LANDIS-II v7 image;
## It gets a set of LANDIS-II v7 extensions, assuming the following have already been done:
## - install system dependencies (i.e., dotnet 2.1 and git);
## - setup the core model and support libs;

library(glue)
library(googledrive)
# library(lubridate)
library(magrittr)
# library(readxl)
# library(rprojroot)
library(withr)
library(xml2)

landis.dir <- if (interactive()) {
  file.path(rprojroot::find_root(rprojroot::is_git_root), "LANDIS-II")
} else {
  "/opt/landis-ii"
}
landis.core.dir <- file.path(landis.dir, "Core-Model-v7-LINUX")
landis.ext.dir <- file.path(landis.core.dir, "build", "extensions")
landis.release.dir <- file.path(landis.core.dir, "build", "Release")
landis.github.url <- "https://github.com/LANDIS-II-Foundation"
landis.fork.url <- "https://github.com/FOR-CAST" ## forked repos from LANDIS-II-Foundation

## 1. get specific versions of extensions ----------------------------------------------------------

landis.extensions.v7 <- c(
  "Extension-Base-BDA",
  "Extension-Base-EDA",
  "Extension-Base-Fire",
  "Extension-Base-Harvest",
  "Extension-Base-Wind",
  "Extension-Biomass-Browse",
  "Extension-Biomass-Harvest",
  "Extension-Biomass-Succession",
  "Extension-Dynamic-Biomass-Fuels",
  "Extension-Dynamic-Fire-System",
  "Extension-Land-Use-Plus",
  "Extension-LinearWind",
  "Extension-Local-Habitat-Suitability-Output",
  "Extension-Output-Biomass",
  "Extension-Output-Biomass-By-Age",
  "Extension-Output-Biomass-Community",
  "Extension-Output-Biomass-Reclass",
  "Extension-Output-Bird-Habitat",
  "Extension-Output-Cohort-Statistics",
  "Extension-Output-Max-Species-Age",
  "Extension-SOSIEL-Harvest",
  "LANDIS-II-Forest-Roads-Simulation-extension")

## extensions to omit(for now)
landis.extensions.omit <- c(
  "Extension-Base-BDA",
  "Extension-Base-EDA",
  "Extension-Biomass-Browse",
  "Extension-Dynamic-Biomass-Fuels",
  "Extension-Dynamic-Fire-System", ## needs dotnet-sdk-3.5
  "Extension-Output-Bird-Habitat",
  "Extension-Output-Cohort-Statistics",
  "Extension-Local-Habitat-Suitability-Output",
  "Extension-Output-Max-Species-Age",
  "Extension-SOSIEL-Harvest",
  "LANDIS-II-Forest-Roads-Simulation-extension"
) |> sort()

## extensions to install
landis.extensions <- landis.extensions.v7[!landis.extensions.v7 %in% landis.extensions.omit]

## 2. build extensions and make available for use --------------------------------------------------

for (ext in landis.extensions) {
  ext.inst.dir <- file.path(landis.core.dir, ext, "deploy", "installer")

  ## add each extension from GitHub and checkout the corresponding tag for model v7
  message(glue("Downloading {ext} extension..."))

  tag <- switch(
    ext,
    "Extension-Biomass-Succession" = "6.0.1",
    "Extension-Base-Fire" = "4.0",
    "Extension-Base-Harvest" = "4.1",
    "Extension-Base-Wind" = "3.2",
    "Extension-Biomass-Harvest" = "4.1",
    "Extension-Dynamic-Fire-System" = "2.1",
    "Extension-Land-Use-Plus" = "1.0",
    "Extension-LinearWind" = "2.0",
    "Extension-Output-Biomass-By-Age" = "3.0",
    "Extension-Output-Biomass-Community" = "2.0",
    "Extension-Output-Biomass" = "3.0",
    "Extension-Output-Biomass-Reclass" = "3.0"
  )

  if (!dir.exists(file.path(landis.core.dir, ext))) {
    system(glue("git -C {landis.core.dir} submodule add {landis.github.url}/{ext}"))
    system(glue("git -C {file.path(landis.core.dir, ext)} checkout v{tag}"))
  }

  ## build and install each extension
  message(glue("Building {ext} extension..."))
  if (ext == "Extension-Biomass-Drought") {
    ext.src.dir <- list.dirs(file.path(landis.core.dir, ext), recursive = FALSE) |>
      grep("component", x = _, value = TRUE) |>
      file.path("src")
  } else {
    ext.src.dir <- file.path(landis.core.dir, ext, "src")
  }

  for (esd in ext.src.dir) {
    ext.csproj <- list.files(esd, pattern = "[.]csproj$", full.names = TRUE)
    ext.csproj.xml <- read_xml(ext.csproj)

    ext.csproj.name <- xml_find_all(ext.csproj.xml, ".//AssemblyName") |> xml_text()

    ## add the following to the `PropertyGroup` tag:
    ## <GenerateRuntimeConfigurationFiles>true</GenerateRuntimeConfigurationFiles>
    ## <AppendTargetFrameworkToOutputPath>false</AppendTargetFrameworkToOutputPath>
    system2(
      "sed",
      paste(
        "-i",
        "-e", shQuote("/<\\/PropertyGroup>/ i\\"),
        "-e", shQuote("    <GenerateRuntimeConfigurationFiles>true</GenerateRuntimeConfigurationFiles>"),
        ext.csproj
      )
    )

    system2(
      "sed",
      paste(
        "-i",
        "-e", shQuote("/<\\/PropertyGroup>/ i\\"),
        "-e", shQuote("    <AppendTargetFrameworkToOutputPath>false</AppendTargetFrameworkToOutputPath>"),
        ext.csproj
      )
    )

    ## update file to use correct OutputPath:
    ## <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Release|AnyCPU'">
    ##   <OutputPath>..\..\build\extensions</OutputPath>
    ## </PropertyGroup>
    system2(
      "sed",
      paste(
        "-i",
        "-e", shQuote("/<\\/PropertyGroup>/ a\\"),
        "-e", shQuote(
          paste0(
            "\\n",
            "  <PropertyGroup Condition=\"\'$(Configuration)|$(Platform)\'==\'Release|AnyCPU\'\">\\n",
            "    <OutputPath>..\\..\\build\\extensions</OutputPath>\\n",
            "  </PropertyGroup>\\n"
          )
        ),
        ext.csproj
      )
    )

    ## ensure all `<Reference Include = ...>` items have `<HintPath>` specified, using relative paths
    system(glue("sed -i -e 's/lib\\\\Landis.Library/..\\\\..\\\\build\\\\extensions\\\\Landis.Library/g' {ext.csproj}"))

    ## build the extension
    system(glue("dotnet build {esd} -c Release"))

    ## add each extension to extensions database
    landis.dll <- file.path(landis.release.dir, "Landis.Extensions.dll") ## executable that calls the dll
    ext.dll <- file.path(esd, "obj", "Release", glue("{ext.csproj.name}.dll"))
    ext.txt <- list.files(ext.inst.dir, pattern = "[.]txt$") |> sort() |> tail(1L)
    ext.nam <- readLines(file.path(ext.inst.dir, ext.txt)) |>
      grep("Name", x = _, value = TRUE) |>
      strsplit("\"") |>
      _[[1]] |>
      grep("Name", x = _, invert = TRUE, value = TRUE)

    system(glue("dotnet {landis.dll} remove '{ext.nam}'"))

    withr::with_dir(ext.inst.dir, {
      system(glue("dotnet {landis.dll} add '{ext.txt}'"))
    })

    if (file.exists(ext.dll)) {
      system(glue("cp {ext.dll} {landis.ext.dir}/."))
    } else {
      warning(glue("Extension {ext} failed to build."))
    }
  }
}
