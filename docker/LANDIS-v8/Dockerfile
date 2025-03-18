## adapted for Docker based on the official LANDIS-II Docker repo
## <https://github.com/LANDIS-II-Foundation/Tool-Docker-Apptainer/>

FROM rocker/geospatial:4.4.3

LABEL org.opencontainers.image.authors="achubaty@for-cast.ca"

ENV C_INCLUDE_PATH=/usr/include/gdal
ENV CPLUS_INCLUDE_PATH=/usr/include/gdal
ENV DEBIAN_FRONTEND=noninteractive
ENV LC_ALL=C.UTF-8

## update and install additional system dependencies
RUN apt-get update -y && apt-get upgrade -y \
  && apt-get install -y \
    git \
    dotnet-sdk-8.0 \
    libjpeg62 \
    libpng16-16t64 \
    software-properties-common \
    wget \
  && rm -rf /var/lib/apt/lists/*

## install LANDIS-II and extensions
ARG LANDIS_GITHUB=https://github.com/LANDIS-II-Foundation
ARG LANDIS_DIR=/opt/landis-ii
ARG LANDIS_CORE_DIR=${LANDIS_DIR}/Core-Model-v8-LINUX
ARG LANDIS_EXT_DIR=${LANDIS_CORE_DIR}/build/extensions
ARG LANDIS_REL_DIR=${LANDIS_CORE_DIR}/build/Release
ARG PROJECT_DIR=/home/${DEFAULT_USER}/LANDIS-II

WORKDIR ${LANDIS_DIR}

## get core model; use earlier commit (broken binaries on latest main)
# RUN git -C ${LANDIS_DIR} clone --depth 1 ${LANDIS_GITHUB}/Core-Model-v8-LINUX \
RUN git -C ${LANDIS_DIR} clone ${LANDIS_GITHUB}/Core-Model-v8-LINUX \
  && git -C ${LANDIS_CORE_DIR} checkout 7b0f215705900423068b85cec5eb197de4a7b419

RUN sed -i -e 's/lib\\Landis.Library/..\\..\\build\\extensions\\Landis.Library/g' \
  ${LANDIS_CORE_DIR}/Tool-Console/src/Console.csproj \
  && dotnet build ${LANDIS_CORE_DIR}/Tool-Console/src -c Release

RUN git -C ${LANDIS_DIR} clone --depth 1 ${LANDIS_GITHUB}/Support-Library-Dlls-v8 \
  && cp ${LANDIS_DIR}/Support-Library-Dlls-v8/*.dll ${LANDIS_EXT_DIR}/ \
  && ln -s -f ${LANDIS_DIR}/Support-Library-Dlls-v8/*.dll ${LANDIS_REL_DIR}

COPY scripts/install_extensions_v8.R ${LANDIS_DIR}/install_extensions_v8.R
RUN Rscript ${LANDIS_DIR}/install_extensions_v8.R

RUN echo "alias landis='dotnet ${LANDIS_REL_DIR}/Landis.Console.dll'" >> /home/${DEFAULT_USER}/.bashrc

## switch to user's project directory
WORKDIR ${PROJECT_DIR}

## additional directory setup for volume mounts
RUN mkdir -p ${PROJECT_DIR}
RUN mkdir -p /mnt/scratch

## grant permissions to the user
RUN chown -R ${DEFAULT_USER}:${DEFAULT_USER} ${LANDIS_DIR}
RUN chown -R ${DEFAULT_USER}:${DEFAULT_USER} ${PROJECT_DIR}
