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
# library(xml2)

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
landis.github.org <- "LANDIS-II-Foundation"
landis.github.url <- glue("https://github.com/{landis.github.org}")

fixup_csproj <- function(csproj) {
  ## add the following to the `PropertyGroup` tag:
  ## <GenerateRuntimeConfigurationFiles>true</GenerateRuntimeConfigurationFiles>
  ## <AppendTargetFrameworkToOutputPath>false</AppendTargetFrameworkToOutputPath>
  system2(
    "sed",
    paste(
      "-i",
      "-e", shQuote("/<\\/PropertyGroup>/ i\\"),
      "-e", shQuote("    <GenerateRuntimeConfigurationFiles>true</GenerateRuntimeConfigurationFiles>"),
      csproj
    )
  )

  system2(
    "sed",
    paste(
      "-i",
      "-e", shQuote("/<\\/PropertyGroup>/ i\\"),
      "-e", shQuote("    <AppendTargetFrameworkToOutputPath>false</AppendTargetFrameworkToOutputPath>"),
      csproj
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
        if (grepl("src", csproj)) {
          paste(
            "\\n",
            "<PropertyGroup Condition=\"\'$(Configuration)|$(Platform)\'==\'Release|AnyCPU\'\">\\n",
            "  <OutputPath>..\\\\..\\\\build\\\\extensions</OutputPath>\\n",
            "</PropertyGroup>\\n"
          )
        } else {
          ## assume a library repo
          paste(
            "\\n",
            "<PropertyGroup Condition=\"\'$(Configuration)|$(Platform)\'==\'Release|AnyCPU\'\">\\n",
            "  <OutputPath>..\\\\build\\\\extensions</OutputPath>\\n",
            "</PropertyGroup>\\n"
          )
        }
      ),
      csproj
    )
  )

  ## ensure all `<Reference Include = ...>` items have `<HintPath>` specified, using relative paths
  if (grepl("src", csproj)) {
    system(glue("sed -i -e 's/lib\\\\1/..\\\\..\\\\Core-Model-v8-LINUX\\\\build\\\\extensions\\\\Ether/g' {csproj}"))
    system(glue("sed -i -e 's/lib\\\\Landis.Library/..\\\\..\\\\Core-Model-v8-LINUX\\\\build\\\\extensions\\\\Landis.Library/g' {csproj}"))
  } else {
    ## assume a library repo
    system(glue("sed -i -e 's/lib\\\\Landis.Library/..\\\\Core-Model-v8-LINUX\\\\build\\\\extensions\\\\Landis.Library/g' {csproj}"))
  }
}

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
  system(glue("git -C {landis.dir} clone {landis.github.url}/{lib.name}"))
  system(glue("git -C {landis.dir}/{lib.name} checkout {lib.sha}"))

  lib.csproj <- list.files(file.path(landis.dir, lib.name), pattern = "[.]csproj$", full.names = TRUE)

  message(glue("Building {lib.name} ..."))
  fixup_csproj(lib.csproj)
  system(glue("dotnet build {landis.dir}/{lib.name} -c Release"))
  unlink(file.path(landis.dir, lib.name), recursive = TRUE)
}

## 1. get specific versions of extensions ------------------------------------------------------------

landis.extensions <- rbind(
  ## Succession extensions
  c(landis.github.org, "Extension-Biomass-Succession", "58ad3673e02abe82f437a6b68c44220c51351091"),
  # TODO: "Extension-DGS-Succession" not yet ready for v8
  # TODO: "Extension-ForCS-Succession" not yet ready for v8
  c(landis.github.org, "Extension-NECN-Succession", "dd5838ab2b5c8eef874d48b16e9e52480c5671b6"),
  # TODO: "Extension-PnET-Succession" see issue Extension-PnET-Succession#17

  ## Disturbance and other extensions
  c(landis.github.org, "Extension-Base-BDA", "1aaa2e28627ba21949fd9053b9aae18f099032d5"),
  c(landis.github.org, "Extension-Base-Fire", "52b878c81aba65000689e0a572ac2ebc5a0cd0c7"),
  c(landis.github.org, "Extension-Base-Wind", "85b9ac626b89241729d9d978baa99b271218cd7d"),
  # TODO: "Extension-Biomass-Browse" not yet ready for v8
  c(landis.github.org, "Extension-Biomass-Harvest", "24b01fea5a90b05b2732c3e52e09a02fdb47db59"),
  c(landis.github.org, "Extension-Biomass-Hurricane", "a6afe3f3d2c8664023e32a9ca66544aa14d24449"),
  c(landis.github.org, "Extension-Dynamic-Biomass-Fuels", "06dd67482b20a74a0e075782e66b09b4fe42c248"),
  c(landis.github.org, "Extension-Dynamic-Fire-System", "999b479f503cfd4b4eb9cf0bf1f1a7af21b96eb6"),
  c(landis.github.org, "Extension-Land-Use-Plus", "574940aa6382ed9e5840b78b0544300bf5a40cd2"),
  c(landis.github.org, "Extension-LinearWind", "fde29473f773c9f995f3a702ca919f7f30a6bcd1"),
  # TODO: "Extension-Root-Rot" not yet ready for v8
  c(landis.github.org, "Extension-Social-Climate-Fire", "0a9bb3de83a601804e825d41afcbb17fcaedbe76"),
  # TODO: "Extension-SOSIEL-Harvest" not yet ready for v8
  # c("Klemet", "LANDIS-II-Forest-Roads-Simulation-extension", ""), ## TODO: need fixed .csproj
  # c("Klemet", "LANDIS-II-Magic-Harvest", ""),                     ## TODO: need fixed .csproj

  ## Output extensions
  c(landis.github.org, "Extension-Output-Biomass", "d5cb256f7669df36a76d9337c779cdc7f1cdbd0b"),
  c("FOR-CAST", "Extension-Output-Biomass-By-Age", "b8e1cadfe79433ad1c064e588dfc273ae4bff6e5"),
  c("FOR-CAST", "Extension-Output-Biomass-Community", "9d4dca5c205f5d2eeb8ed9e949a76e51764d862c"),
  c(landis.github.org, "Extension-Output-Biomass-Reclass", "fad7e9f7e39b9cf72e1e55210cb0e8cd09082671"),
  c("FOR-CAST", "Extension-Output-Cohort-Statistics", "fe9996e68aca8d407585535066c66717c784a459"),
  # TODO: "Extension-Output-Landscape-Habitat" not yet ready for v8
  c("FOR-CAST", "Extension-Output-Max-Species-Age", "5a1fcadc11a3f5fba6af85a961a6ea39ad622031"),
  c(landis.github.org, "Extension-Output-Wildlife-Habitat", "695a03ba11a21d8a12eb714a6c8759a8284290f2"),

  c(landis.github.org, "Extension-Local-Habitat-Suitability-Output", "1366a092625e0a26fff870e16529c1fe3e071c14")
) |>
  as.data.frame() |>
  setNames(c("org", "repo", "sha"))

## 2. build extensions and make available for use --------------------------------------------------

console.csproj <- file.path(landis.core.dir, "Tool-Console", "src", "Console.csproj")

for (i in 1:nrow(landis.extensions)) {
  ext.name <- landis.extensions[["repo"]][i]
  ext.repo <- glue("https://github.com/{landis.extensions[['org']][i]}/{ext.name}")
  ext.sha <- landis.extensions[["sha"]][i]

  ext.inst.dir <- switch(
    ext.name,
    "Extension-Biomass-Hurricane" = file.path(landis.dir, ext.name, "deploy", "current"),
    file.path(landis.dir, ext.name, "deploy", "installer")
  )
  ext.src.dir <- file.path(landis.dir, ext.name, "src")

  message(glue("Cloning {ext.name} ..."))
  ## use sparse-checkout to speed up checkout
  system(glue("git -C {landis.dir} clone --no-checkout {ext.repo}"))
  system(glue("git -C {landis.dir}/{ext.name} sparse-checkout init --cone"))
  system(glue("git -C {landis.dir}/{ext.name} sparse-checkout set {basename(dirname(ext.inst.dir))} {basename(ext.src.dir)}"))
  system(glue("git -C {landis.dir}/{ext.name} checkout {ext.sha}"))

  message(glue("Building {ext.name} extension..."))

  ## ensure each extension can see additional libs
  system(glue("ln -s {landis.dir}/Support-Library-Dlls-v8/*.dll {ext.src.dir}/lib/"))

  ## build and install each extension
  ext.csproj <- list.files(ext.src.dir, pattern = "[.]csproj$", full.names = TRUE)
  ext.csproj.xml <- xml2::read_xml(ext.csproj)
  ext.csproj.name <- xml2::xml_find_all(ext.csproj.xml, ".//AssemblyName") |> xml2::xml_text()

  fixup_csproj(ext.csproj)

  ## remove any .sln files as these don't help the builds
  list.files(ext.src.dir, "[.]sln$", full.names = TRUE) |> file.remove()

  system(glue("dotnet build {ext.src.dir} -c Release"))

  ## add each extension to extensions database
  landis.dll <- file.path(landis.release.dir, "Landis.Extensions.dll") ## executable that calls the dll
  ext.dll <- file.path(ext.src.dir, "obj", "Release", glue("{ext.csproj.name}.dll"))
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

  unlink(file.path(landis.dir, ext.name), recursive = TRUE) ## keep image layer lean
}

## rebuild Tool-Console
system(glue("dotnet build {dirname(console.csproj)} -c Release"))
