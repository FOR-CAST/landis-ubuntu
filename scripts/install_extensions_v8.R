## This script is intended to be run during docker build for a LANDIS-II v8 image;
## It gets a set of LANDIS-II v8 extensions, assuming the following have already been done:
## - install system dependencies (i.e., dotnet 8.0 and git);
## - setup the core model and support libs;

library(glue)
library(googledrive)
# library(lubridate)
# library(readxl)
# library(rprojroot)
library(withr)
library(xml2)

landis.dir <- if (interactive()) {
  file.path(rprojroot::find_root(rprojroot::is_git_root), "LANDIS-II")
} else {
  "/opt/landis-ii"
}

if (!dir.exists(landis.dir)) {
  dir.create(landis.dir, recursive = TRUE)
}

landis.core.dir <- file.path(landis.dir, "Core-Model-v8-LINUX")
landis.ext.dir <- file.path(landis.core.dir, "build", "extensions")
landis.release.dir <- file.path(landis.core.dir, "build", "Release")
landis.github.url <- "https://github.com/LANDIS-II-Foundation"
landis.fork.url <- "https://github.com/FOR-CAST"

## 1. get latest versions of extensions ------------------------------------------------------------

landis.extensions <- c(
  # "Extension-Base-BDA",
  "Extension-Base-Fire",
  # "Extension-Base-Wind",
  # "Extension-Biomass-Browse",
  # "Extension-Biomass-Drought",
  # "Extension-Biomass-Harvest",
  # "Extension-Biomass-Hurricane",
  "Extension-Biomass-Succession",
  # "Extension-Dynamic-Biomass-Fuels",
  # "Extension-Dynamic-Fire-System",
  # "Extension-Land-Use-Plus",
  # "Extension-LinearWind",
  # "Extension-Local-Habitat-Suitability-Output",
  # "Extension-NECN-Succession",
  # "Extension-Output-Wildlife-Habitat",
  "Extension-Output-Biomass",
  "Extension-Output-Biomass-By-Age",
  "Extension-Output-Biomass-Reclass",
  "Extension-Output-Cohort-Statistics"#,
  #"Extension-Output-Max-Species-Age",
  # "Extension-Social-Climate-Fire"
)

## 2. build extensions and make available for use --------------------------------------------------

console.csproj <- file.path(landis.core.dir, "Tool-Console", "src", "Console.csproj")

for (ext in landis.extensions) {
  message(glue("Cloning {ext} extension..."))
  system(glue("git -C {landis.dir} clone {landis.fork.url}/{ext}"))

  message(glue("Building {ext} extension..."))
  ext.inst.dir <- file.path(landis.dir, ext, "deploy", "installer")

  if (ext == "Extension-Biomass-Drought") {
    ext.src.dir <- list.dirs(file.path(landis.dir, ext), recursive = FALSE) |>
      grep("component", x = _, value = TRUE) |>
      file.path("src")
  } else {
    ext.src.dir <- file.path(landis.dir, ext, "src")
  }

  for (esd in ext.src.dir) {
    ## ensure each extension can see additional libs
    system(glue("ln -s {landis.dir}/Support-Library-Dlls-v8/*.dll {esd}/lib/"))

    ## build and install each extension
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
          paste(
            "\\n",
            "<PropertyGroup Condition=\"\'$(Configuration)|$(Platform)\'==\'Release|AnyCPU\'\">\\n",
            "  <OutputPath>..\\..\\build\\extensions</OutputPath>\\n",
            "</PropertyGroup>\\n"
          )
        ),
        ext.csproj
      )
    )

    ## ensure all `<Reference Include = ...>` items have `<HintPath>` specified, using relative paths
    system(glue("sed -i -e 's/lib\\\\1/..\\\\..\\\\Core-Model-v8-LINUX\\\\build\\\\extensions\\\\Ether/g' {ext.csproj}"))
    system(glue("sed -i -e 's/lib\\\\Landis.Library/..\\\\..\\\\Core-Model-v8-LINUX\\\\build\\\\extensions\\\\Landis.Library/g' {ext.csproj}"))

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

    withr::with_dir(ext.inst.dir, {
      system(glue("dotnet {landis.dll} remove '{ext.nam}'"))
      system(glue("dotnet {landis.dll} add '{ext.txt}'"))
    })
    if (file.exists(ext.dll)) {
      system(glue("cp {ext.dll} {landis.ext.dir}/."))

      ## add HintPath for all extensions to Tool-Console csproj file, based on:
      ## <https://github.com/CU-ESIIL/ExtremeWildfire/blob/main/docker/landis2/Dockerfile#L146-L197>
      system2(
        "sed",
        paste(
          "-i",
          "-e", shQuote("/<\\/Reference>/ a\\"),
          "-e", shQuote(
            glue(
              "    <Reference Include=\"{ext.csproj.name}.dll\">\\n",
              "      <HintPath>..\\\\..\\\\build\\\\extensions\\\\{ext.csproj.name}.dll</HintPath>\\n",
              "    </Reference>"
            )
          ),
          console.csproj
        )
      )
    } else {
      warning(glue("Extension {ext} failed to build."))
    }
  }
}

## rebuild Tool-Console
system(glue("dotnet build {dirname(console.csproj)} -c Release"))
