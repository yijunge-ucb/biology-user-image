FROM buildpack-deps:jammy-scm

ENV TZ=America/Los_Angeles
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

ENV LC_ALL=en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US.UTF-8
ENV DEBIAN_FRONTEND=noninteractive
ENV NB_USER=jovyan
ENV NB_UID=1000

ENV CONDA_DIR=/srv/conda
ENV R_LIBS_USER=/srv/r

# Explicitly add littler to PATH
# See https://github.com/conda-forge/r-littler-feedstock/issues/6
ENV PATH=${CONDA_DIR}/lib/R/library/littler/bin:${CONDA_DIR}/bin:$PATH

RUN adduser --disabled-password --gecos "Default Jupyter user" ${NB_USER}

# Create user owned R libs dir
# This lets users temporarily install packages
RUN mkdir -p ${R_LIBS_USER} && chown ${NB_USER}:${NB_USER} ${R_LIBS_USER}

# Required for PAUP*
# Note that this doesn't actually install python2, thankfully
RUN apt-get update -qq --yes > /dev/null && \
    apt-get install --yes -qq \
        libpython2.7 > /dev/null

## library required for fast-PCA & https://github.com/DReichLab/EIG
RUN apt-get update -qq --yes && \
    apt-get install --yes --no-install-recommends -qq \
        libgsl-dev >/dev/null

# Install these without 'recommended' packages to keep image smaller.
# Useful utils that folks sort of take for granted
RUN apt-get update -qq --yes && \
    apt-get install --yes --no-install-recommends -qq \
        curl \
        emacs \
        htop \
        less \
        locales \
        man \
        man-db \
        manpages-dev \
        manpages-posix \
        manpages-posix-dev \
        nano \
        rsync \
        screen \
        tar \
        tini \
        tmux \
        vim \
        wget \
        zip > /dev/null

RUN echo "${LC_ALL} UTF-8" > /etc/locale.gen && \
    locale-gen

# Needed by RStudio
RUN apt-get update -qq --yes && \
    apt-get install --yes --no-install-recommends -qq \
        psmisc \
        sudo \
        libapparmor1 \
        lsb-release \
        libclang-dev \
        libpq5 > /dev/null

# Needed by many R libraries
# Picked up from https://github.com/rocker-org/rocker/blob/9dc3e458d4e92a8f41ccd75687cd7e316e657cc0/r-rspm/focal/Dockerfile
RUN apt-get update && \
	apt-get install -y --no-install-recommends \
                   libgdal-dev \
                   libgeos3.10.2 \
                   libproj22 \
                   libudunits2-0 \
                   libxml2 > /dev/null

# Install R.
# These packages must be installed into the base stage since they are in system
# paths rather than /srv.
# Pre-built R packages from rspm are built against system libs in jammy.
ENV R_VERSION=4.4.2-1.2204.0
ENV LITTLER_VERSION=0.3.20-2.2204.0
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys E298A3A825C0D65DFD57CBB651716619E084DAB9
RUN echo "deb https://cloud.r-project.org/bin/linux/ubuntu jammy-cran40/" > /etc/apt/sources.list.d/cran.list
RUN curl --silent --location --fail https://cloud.r-project.org/bin/linux/ubuntu/marutter_pubkey.asc > /etc/apt/trusted.gpg.d/cran_ubuntu_key.asc
RUN apt-get update -qq --yes > /dev/null && \
    apt-get install --yes -qq \
        r-base-core=${R_VERSION} \
        r-base-dev=${R_VERSION} r-cran-littler=${LITTLER_VERSION} > /dev/null
RUN apt-get install --yes -qq littler=${LITTLER_VERSION} > /dev/null

RUN apt-get install --yes -qq libglpk-dev \
        libzmq5 \
        nodejs npm > /dev/null

ENV RSTUDIO_URL=https://download2.rstudio.org/server/jammy/amd64/rstudio-server-2024.04.2-764-amd64.deb
RUN curl --silent --location --fail ${RSTUDIO_URL} > /tmp/rstudio.deb && \
    apt install --no-install-recommends --yes /tmp/rstudio.deb && \
    rm /tmp/rstudio.deb

# Install desktop packages
RUN apt-get update -qq --yes > /dev/null && \
    apt-get install --yes -qq \
        dbus-x11 \
        firefox \
        xfce4 \
        xfce4-panel \
        xfce4-terminal \
        xfce4-session \
        xfce4-settings \
        xorg \
        xubuntu-icon-theme > /dev/null

# for nbconvert & notebook-to-pdf
RUN apt-get update -qq --yes && \
    apt-get install --yes -qq \
        pandoc \
        texlive-xetex \
        texlive-fonts-recommended \
        libx11-xcb1 \
        libxtst6 \
        libxrandr2 \
        libasound2 \
        libpangocairo-1.0-0 \
        libatk1.0-0 \
        libatk-bridge2.0-0 \
        libgtk-3-0 \
        libnss3 \
        libxss1 \
        > /dev/null

# Adding ncompress,pbzip2 for issue #1885 BioE-131, Fall 2020
RUN apt-get update -qq --yes > /dev/null && \
    apt-get install --yes -qq \
        ncompress \
        pbzip2 > /dev/null

WORKDIR /home/jovyan

# R_LIBS_USER is set by default in /etc/R/Renviron, which RStudio loads.
# We uncomment the default, and set what we wanna - so it picks up
# the packages we install. Without this, RStudio doesn't see the packages
# that R does.
# Stolen from https://github.com/jupyterhub/repo2docker/blob/6a07a48b2df48168685bb0f993d2a12bd86e23bf/repo2docker/buildpacks/r.py
# To try fight https://community.rstudio.com/t/timedatectl-had-status-1/72060,
# which shows up sometimes when trying to install packages that want the TZ
# timedatectl expects systemd running, which isn't true in our containers
RUN sed -i -e '/^R_LIBS_USER=/s/^/#/' /etc/R/Renviron && \
    echo "R_LIBS_USER=${R_LIBS_USER}" >> /etc/R/Renviron && \
    echo "TZ=${TZ}" >> /etc/R/Renviron

# Needed by Rhtslib
RUN apt-get update -qq --yes && \
    apt-get install --yes  -qq \
        libcurl4-openssl-dev > /dev/null

USER root
# Create user owned conda dir
# This lets users temporarily install packages
RUN install -d -o ${NB_USER} -g ${NB_USER} ${CONDA_DIR}

# Install conda environment as our user
USER ${NB_USER}

# Install conda 
COPY --chown=${NB_USER}:${NB_USER} install-miniforge.bash /tmp/install-miniforge.bash
RUN bash /tmp/install-miniforge.bash

# Install Conda packages
ENV PATH=${CONDA_DIR}/bin:$PATH
COPY environment.yml /tmp/

RUN mamba env create -n notebook -f /tmp/environment.yml && \
    mamba clean -afy

ENV PATH=${CONDA_DIR}/envs/notebook/bin:$PATH

USER root
RUN rm /tmp/environment.yml 

ENV PLAYWRIGHT_BROWSERS_PATH=${CONDA_DIR}
RUN playwright install-deps
RUN chown -Rh jovyan:jovyan /srv/conda

USER ${NB_USER}

# DH-333
ENV PLAYWRIGHT_BROWSERS_PATH=${CONDA_DIR}
RUN playwright install chromium

# Set CRAN mirror to rspm before we install anything
COPY Rprofile.site /usr/lib/R/etc/Rprofile.site
# RStudio needs its own config
COPY rsession.conf /etc/rstudio/rsession.conf
# As does RServer
COPY rserver.conf /etc/rstudio/rserver.conf
# Use simpler locking strategy
COPY file-locks /etc/rstudio/file-locks

# Install IRKernel
RUN r -e "install.packages('IRkernel', version='1.2')" && \
    r -e "IRkernel::installspec(user = FALSE, prefix='${CONDA_DIR}')"

# Install R packages, cleanup temp package download location
COPY install.R /tmp/install.R
RUN r /tmp/install.R && \
    rm -rf /tmp/downloaded_packages/ /tmp/*.rds

# install bio1b packages
USER ${NB_USER}
COPY bio1b-packages.bash /tmp/bio1b-packages.bash
RUN bash /tmp/bio1b-packages.bash
USER root
RUN rm /tmp/bio1b-packages.bash

# install ib134L packages
USER ${NB_USER}
COPY ib134-packages.bash /tmp/ib134-packages.bash
RUN bash /tmp/ib134-packages.bash
USER root
RUN rm /tmp/ib134-packages.bash

# install ccb293 packages
USER ${NB_USER}
COPY ccb293-packages.bash /tmp/ccb293-packages.bash
RUN bash /tmp/ccb293-packages.bash
USER root
RUN rm /tmp/ccb293-packages.bash

ENV REPO_DIR=/srv/repo
COPY --chown=${NB_USER}:${NB_USER} image-tests ${REPO_DIR}/image-tests

USER ${NB_USER}
WORKDIR /home/${NB_USER}

EXPOSE 8888

ENTRYPOINT ["tini", "--"]
