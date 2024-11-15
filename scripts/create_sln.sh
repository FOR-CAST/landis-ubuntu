#!/bin/bash

## adapted from Windows instructions for LANDIS-II v7 at
## https://github.com/LANDIS-II-Foundation/Core-Model-v8/blob/master/Installation_Notes_PennState%202017.md

dotnet new sln -o LANDIS-II/landis-ubuntu.sln

## 1. add core model projects (NOTE: Ecoregions_Tests and Species_Tests are broken; not added here)
dotnet sln LANDIS-II/landis-ubuntu.sln add ./Core-Model-v8-LINUX/Tool-Console/src/Console.csproj
dotnet sln LANDIS-II/landis-ubuntu.sln add ./Library-Core/src/Core/Landis.Core.csproj
dotnet sln LANDIS-II/landis-ubuntu.sln add ./Library-Core/src/Implementation/Landis.Core.Implementation.csproj
dotnet sln LANDIS-II/landis-ubuntu.sln add ./Core-Model-v8-LINUX/Tool-Extension-Admin/src/Extension_Admin.csproj
dotnet sln LANDIS-II/landis-ubuntu.sln add ./Library-Datasets/src/Extension_Dataset.csproj

## 2. add core model dependencies

## TODO: add log4net

## TODO: add Troschuetz Random Number Library

dotnet add ./Library-Core/src/Core/Landis.Core.csproj reference ./LANDIS-II/Core-Model-v8-LINUX/build/Release/Troschuetz.Random.dll
dotnet add ./Library-Core/src/Implementation/Landis.Core.Implementation.csproj reference ./LANDIS-II/Core-Model-v8-LINUX/build/Release/Troschuetz.Random.dll

## TODO: Edu.Wisc.Forest.Flel.Util no longer used by this name?

## Library-Spatial
dotnet sln LANDIS-II/landis-ubuntu.sln add ./Library-Spatial/src/api/Landis_SpatialModeling.csproj
dotnet sln LANDIS-II/landis-ubuntu.sln add ./Library-Spatial/src/Landscapes/Landis_Landscapes.csproj
dotnet sln LANDIS-II/landis-ubuntu.sln add ./Library-Spatial/src/RasterIO/Landis_RasterIO.csproj
dotnet sln LANDIS-II/landis-ubuntu.sln add ./Library-Spatial/src/RasterIO.Gdal/Landis_RasterIO_Gdal.csproj

dotnet add ./Core-Model-v8-LINUX/Tool-Console/src/Console.csproj reference ./Library-Spatial/src/api/Landis_SpatialModeling.csproj
dotnet add ./Core-Model-v8-LINUX/Tool-Console/src/Console.csproj reference ./Library-Spatial/src/Landscapes/Landis_Landscapes.csproj
dotnet add ./Core-Model-v8-LINUX/Tool-Console/src/Console.csproj reference ./Library-Spatial/src/RasterIO/Landis_RasterIO.csproj
dotnet add ./Core-Model-v8-LINUX/Tool-Console/src/Console.csproj reference ./Library-Spatial/src/RasterIO.Gdal/Landis_RasterIO_Gdal.csproj

dotnet add ./Library-Core/src/Core/Landis.Core.csproj reference ./Library-Spatial/src/api/Landis_SpatialModeling.csproj

dotnet add ./Library-Core/src/Implementation/Landis.Core.Implementation.csproj reference ./Library-Spatial/src/api/Landis_SpatialModeling.csproj

dotnet add ./Core-Model-v8-LINUX/Tool-Extension-Admin/src/Extension_Admin.csproj reference ./Library-Spatial/src/api/Landis_SpatialModeling.csproj

## 2a. add updated Extension.Dataset to Console and Extension_Admin tools
dotnet add ./Library-Datasets/src/Extension_Dataset.csproj reference ./Library-Core/src/Core/Landis.Core.csproj
dotnet add ./Core-Model-v8-LINUX/Tool-Extension-Admin/src/Extension_Admin.csproj reference ./Library-Datasets/src/Extension_Dataset.csproj
dotnet add ./Core-Model-v8-LINUX/Tool-Console/src/Console.csproj reference ./Library-Datasets/src/Extension_Dataset.csproj


dotnet add ./Library-Core/src/Core/Landis.Core.csproj reference ./Library-Utilities/src/Landis.Utilities.csproj
dotnet add ./Core-Model-v8-LINUX/Tool-Extension-Admin/src/Extension_Admin.csproj reference ./Library-Utilities/src/Landis.Utilities.csproj
dotnet add ./Core-Model-v8-LINUX/Tool-Console/src/Console.csproj reference ./Library-Utilities/src/Landis.Utilities.csproj
dotnet add ./Library-Succession/src/library-succession.csproj reference ./Library-Utilities/src/Landis.Utilities.csproj

