## adapted for Docker based on the official LANDIS-II Singularity image at
## <https://github.com/LANDIS-II-Foundation/Tool-Linux-Singularity/>

## NOTE: Ubuntu 20.04 Focal is the most recent OS that still supports .Net 2.1;
FROM achubaty/geospatial:4.4.3-focal-ubuntugis

LABEL org.opencontainers.image.authors="achubaty@for-cast.ca"

ENV C_INCLUDE_PATH=/usr/include/gdal
ENV CPLUS_INCLUDE_PATH=/usr/include/gdal
ENV DEBIAN_FRONTEND=noninteractive
ENV LC_ALL=C.UTF-8

## update and install additional system dependencies
RUN apt-get update -y && apt-get upgrade -y \
  && apt-get install -y \
    git \
    libjpeg62 \
    libpng16-16 \
    software-properties-common \
    wget \
  && rm -rf /var/lib/apt/lists/*

## install LANDIS-II dependency .NET v2.1
RUN wget -q https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb \
  && dpkg -i packages-microsoft-prod.deb \
  && add-apt-repository universe \
  && apt-get install -y apt-transport-https \
  && apt-get update \
  && apt-get install -y dotnet-sdk-2.1 \
  && apt-get clean \
  && rm packages-microsoft-prod.deb \
  && rm -rf /var/lib/apt/lists/*

## install LANDIS-II and extensions
ARG LANDIS_GITHUB=https://github.com/LANDIS-II-Foundation
ARG LANDIS_DIR=/opt/landis-ii
ARG LANDIS_CORE_DIR=${LANDIS_DIR}/Core-Model-v7-LINUX
ARG LANDIS_EXT_DIR=${LANDIS_CORE_DIR}/build/extensions
ARG LANDIS_REL_DIR=${LANDIS_CORE_DIR}/build/Release
ARG PROJECT_DIR=/home/${DEFAULT_USER}/LANDIS-II

WORKDIR ${LANDIS_DIR}

## get core model; use kejones modified repo
# RUN git clone --depth 1 --branch v7 ${LANDIS_GITHUB}/Core-Model-v7-LINUX
RUN git clone --depth 1 --branch v7 https://github.com/kejones8/Core-Model-v7-LINUX

RUN dotnet build ${LANDIS_CORE_DIR}/Tool-Console/src -c Release

RUN git -C ${LANDIS_CORE_DIR} clone ${LANDIS_GITHUB}/Support-Library-Dlls-v7 \
  && cp ${LANDIS_CORE_DIR}/Support-Library-Dlls-v7/*.dll ${LANDIS_EXT_DIR}/

COPY scripts/install_extensions_v7.R ./install_extensions_v7.R
RUN Rscript ./install_extensions_v7.R

RUN echo "alias landis='dotnet ${LANDIS_REL_DIR}/Landis.Console.dll'" >> /home/${DEFAULT_USER}/.bashrc

## switch to user's project directory
WORKDIR ${PROJECT_DIR}

## additional directory setup for volume mounts
RUN mkdir -p ${PROJECT_DIR}
RUN mkdir -p /mnt/scratch

## grant permissions to the user
RUN chown -R ${DEFAULT_USER}:${DEFAULT_USER} ${LANDIS_DIR}
RUN chown -R ${DEFAULT_USER}:${DEFAULT_USER} ${PROJECT_DIR}
