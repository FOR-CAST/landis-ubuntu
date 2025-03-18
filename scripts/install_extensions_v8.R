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

## 0. rebuild specific versions of some libraries ------------------------------------------------------------

landis.libraries <- list(
  ## TODO: check whether others should be included
  "Library-Initial-Community" = "5dc6dd299eef88ded1c88871470d58c26c1a4093",
  "Library-Universal-Cohort" = "a1e84adc8073fb7c89ee078a38349b5d578d4179"
)

for (lib in names(landis.libraries)) {
  lib.name <- lib
  lib.sha <- landis.libraries[[lib]]
  message(glue("Cloning {lib} ..."))
  system(glue("git -C {landis.dir} clone  --depth 5 {landis.github.url}/{lib.name}"))
  system(glue("git -C {landis.dir}/{lib.name} checkout {lib.sha}"))

  message(glue("Building {lib.name} ..."))
  ## TODO: need to cleanup .csproj files
  system(glue("dotnet build {landis.dir}/{lib.name} -c Release"))
}

## 1. get specific versions of extensions ------------------------------------------------------------

## TODO: add Klemet/LANDIS-II-Forest-Roads-Simulation-extension
## TODO: add Klemet/LANDIS-II-Magic-Harvest

landis.extensions <- list(
  ## Succession extensions
  "Extension-Biomass-Succession" = "58ad3673e02abe82f437a6b68c44220c51351091",
  # "Extension-DGS-Succession" = "", ## TODO: not yet ready for v8
  # "Extension-ForCS-Succession = "", ## TODO: not yet ready for v8
  "Extension-NECN-Succession" = "37ce246c37bab3448e3db134373deb56063e14ac",
  # "Extension-PnET-Succession" = "", ## TODO: see Extension-PnET-Succession#17

  ## Disturbance and other extensions
  "Extension-Base-BDA" = "eb1d998a14b7555ddd7c527dda797669b0c99546",
  "Extension-Base-Fire" = "40169a04b62be126e109c7990fa6a6d64a8ff895",
  "Extension-Base-Wind" = "e0796d577a6221c78b10502da4fc7dd0ddfe08e9",
  # "Extension-Biomass-Browse" = "", ## TODO: not yet ready for v8
  "Extension-Biomass-Harvest" = "24b01fea5a90b05b2732c3e52e09a02fdb47db59",
  "Extension-Biomass-Hurricane" = "a12806d77d4b251d8800766f124c39adf90541be",
  "Extension-Dynamic-Biomass-Fuels" = "06dd67482b20a74a0e075782e66b09b4fe42c248",
  "Extension-Dynamic-Fire-System" = "4970f846bd2b22f014f201ba2af2278436aefd7c",
  "Extension-Land-Use-Plus" = "574940aa6382ed9e5840b78b0544300bf5a40cd2",
  "Extension-LinearWind" = "b8efe5ca20ca386fc978db97670e50424941153e",
  # "Extension-Root-Rot" = "", ## TODO: not yet ready for v8
  "Extension-Social-Climate-Fire" = "b463ea378f1bcde4369907a408dfe64b9cc52c7a",
  # "Extension-SOSIEL-Harvest" = "", ## TODO: not yet ready for v8

  ## Output extensions
  "Extension-Output-Biomass" = "d5cb256f7669df36a76d9337c779cdc7f1cdbd0b",
  "Extension-Output-Biomass-By-Age" = "0419cc64634f57ad3660590408ded3aef88ecf9d",
  "Extension-Output-Biomass-Community" = "58252f441cc393cc1e63ea6c36175e15bba93916",
  "Extension-Output-Biomass-Reclass" = "fad7e9f7e39b9cf72e1e55210cb0e8cd09082671",
  "Extension-Output-Cohort-Statistics" = "045272850c77b8b5e8c36ba1fe8c5041b7a523c2",
  # "Extension-Output-Landscape-Habitat" = "", ## TODO: not yet ready for v8
  "Extension-Output-Max-Species-Age" = "bba5b5a4879d0d6cbfbcce4867702bd4df3ac350",
  "Extension-Output-Wildlife-Habitat" = "695a03ba11a21d8a12eb714a6c8759a8284290f2",

  "Extension-Local-Habitat-Suitability-Output" = "1366a092625e0a26fff870e16529c1fe3e071c14"
)

## 2. build extensions and make available for use --------------------------------------------------

console.csproj <- file.path(landis.core.dir, "Tool-Console", "src", "Console.csproj")

for (ext in names(landis.extensions)) {
  ext.name <- ext
  ext.sha <- landis.extensions[[ext]]
  message(glue("Cloning {ext.name} ..."))
  ## TODO: use sparse checkout
  system(glue("git -C {landis.dir} clone  --depth 5 {landis.github.url}/{ext.name}"))
  system(glue("git -C {landis.dir}/{ext.name} checkout {ext.sha}"))

  message(glue("Building {ext.name} extension..."))
  ext.inst.dir <- switch(
    ext.name,
    "Extension-Biomass-Hurricane" = file.path(landis.dir, ext.name, "deploy", "current"),
    file.path(landis.dir, ext.name, "deploy", "installer")
  )
  ext.src.dir <- file.path(landis.dir, ext.name, "src")

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

    ## remove any .sln files as these don't help the builds
    list.files(esd, "[.]sln$", full.names = TRUE) |> file.remove()

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

  unlink(file.path(landis.dir, ext.name), recursive = TRUE)
}

## rebuild Tool-Console
system(glue("dotnet build {dirname(console.csproj)} -c Release"))
