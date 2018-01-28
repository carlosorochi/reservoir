FROM rocker/geospatial:latest
MAINTAINER "Noam Ross" ross@ecohealthalliance.org

## Install stuff

### Shiny
#RUN export ADD=shiny && bash /etc/cont-init.d/add
ADD latest-rstudio-preview.R /latest-rstudio-preview.R
### Shell tools
RUN  echo 'deb http://download.opensuse.org/repositories/shells:/fish:/release:/2/Debian_9.0/ /' > /etc/apt/sources.list.d/fish.list \
 && apt-get update && apt-get install -y --force-yes --no-install-recommends --no-upgrade \
     curl man ncdu tmux byobu htop zsh fish silversearcher-ag lsb-release mosh pv gnupg apt-transport-https ccache \
### R package dependencies
     libnlopt-dev \
     libglpk-dev coinor-symphony coinor-symphony coinor-libsymphony-dev coinor-libcgl-dev \ 
      grass grass-doc grass-dev \
      python-setuptools python-dev build-essential git-core \
      libtesseract-dev libleptonica-dev tesseract-ocr-eng libpoppler-cpp-dev \
      libopenmpi-dev \
      libgoogle-perftools-dev libprotoc-dev libprotobuf-dev protobuf-compiler golang-go graphviz \
### MonetDB
 && echo "deb http://dev.monetdb.org/downloads/deb/ stretch monetdb" > /etc/apt/sources.list.d/monetdb.list \
 && echo "deb-src http://dev.monetdb.org/downloads/deb/ stretch monetdb" >> /etc/apt/sources.list.d/monetdb.list \
 && wget -q --output-document=- https://www.monetdb.org/downloads/MonetDB-GPG-KEY | sudo apt-key add - \
 && apt-get update && sudo apt-get install -y --allow-unauthenticated --force-yes --no-install-recommends --no-upgrade \
      monetdb5-sql monetdb-client \
## Python stuff
 && easy_install pip \
 && pip install virtualenv --no-cache-dir \
### non-apt stuff (micro)
  && curl -sL https://gist.githubusercontent.com/zyedidia/d4acfcc6acf2d0d75e79004fa5feaf24/raw/a43e603e62205e1074775d756ef98c3fc77f6f8d/install_micro.sh | bash -s linux64 /usr/bin \
### RStudio preview version 
  && Rscript latest-rstudio-preview.R \
  && dpkg -i rstudio-server-preview-stretch-amd64.deb \
  && rm rstudio-server-preview-stretch-amd64.deb latest-rstudio-preview.R \

### Gurobi
  && wget -q http://packages.gurobi.com/7.5/gurobi7.5.2_linux64.tar.gz \
  && tar xfz gurobi7.5.2_linux64.tar.gz -C /opt \
  && rm gurobi7.5.2_linux64.tar.gz \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/ 

# Set up config files
COPY config ./
RUN chmod +x /motd.sh; sync; ./motd.sh > /etc/motd; rm motd.sh \
  && mv -f rsession.conf /etc/rstudio/rsession.conf \
  && mv -f rserver.conf /etc/rstudio/rserver.conf \
  && mv -f Rprofile.site /usr/local/lib/R/etc/Rprofile.site \
  && mv -f Renviron.site /usr/local/lib/R/etc/Renviron.site \
  && mv -f Makevars.site /usr/local/lib/R/etc/Makevars.site \
  && mv -f bash_settings.sh /etc/bash.bashrc \
  && mv -f userconf.sh /etc/cont-init.d/conf \
  && mv -f byobu_status /usr/share/byobu/status/status \
  && mv -f gurobi.lic /opt/gurobi752/gurobi.lic \
  && ln -s /usr/bin/byobu-launch /etc/profile.d/Z98-byobu.sh \
  && echo 'set -g default-terminal "screen-256color"' >> /usr/share/byobu/profiles/tmux

## Set up ccache
ENV CCACHE_DIR=/opt/.ccache
ENV CCACHE_UMASK=002
RUN mkdir /opt/.ccache \
  && chmod -R 2777  /opt/.ccache/ \
  && xargs chmod g+s /opt/.ccache \
  && unset CCACHE_HARDLINK


### R config and packages
RUN . /etc/environment \
  && R CMD javareconf \
  && installGithub.r s-u/unixtools \
  && Rscript -e "withr::with_envvar(c('CCACHE'=''), withr::with_makevars(c('CCACHE'=''), install.packages('rJava')))" \
  && install2.r -e -r $MRAN V8 rgrass7 ROI Rglpk ROI.plugin.glpk Rsymphony ROI.plugin.symphony lme4 MonetDBLite rstan keras \
### cleanup
  && Rscript -e 'install.packages("/opt/gurobi752/linux64/R/gurobi_7.5-2_R_x86_64-pc-linux-gnu.tar.gz", lib="/usr/local/lib/R/site-library", repos = NULL)'  \
  && rm -rf /tmp/downloaded_packages/ /tmp/*.rds 


## Setup SSH. s6 supervisor already installed for RStudio, so
## just create the run and finish scripts

RUN mkdir -p /var/run/sshd \
  && mkdir -p /etc/services.d/sshd \
  && echo '#!/bin/bash \nexec /usr/sbin/sshd -D' > /etc/services.d/sshd/run \
  && echo '#!/bin/bash \n service ssh stop' > /etc/services.d/sshd/finish \ 
  && sed -i 's/PermitRootLogin no/PermitRootLogin yes/' /etc/ssh/sshd_config \
  && echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config \
  && echo "AllowGroups ssh-users" >> /etc/ssh/sshd_config

## Add and run config files

## Open ports

EXPOSE 22 8787
