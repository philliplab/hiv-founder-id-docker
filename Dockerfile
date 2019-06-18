FROM ubuntu:18.04

## Copied but then heavily modified from https://github.com/rocker-org/rocker

## To avoid prompt for time zone config
## https://askubuntu.com/questions/909277/avoiding-user-interaction-with-tzdata-when-installing-certbot-in-a-docker-contai
## Note that this does not 'fix' the timezone issue - it just makes the installer not care about it

LABEL maintainer="Phillip Labuschagne <jlabusc2@fredhutch.org>"

RUN adduser --home /home/docker --ingroup staff --shell /bin/bash --disabled-password --gecos ,,,, docker

ENV LC_ALL=en_US.UTF-8 \
    LANG=en_US.UTF-8 \
    TERM=xterm \
    DEBIAN_FRONTEND=noninteractive 

RUN apt-get update \
	&& apt-get install -y \
		ed \
		less \
		locales \
		vim-tiny \
		wget \
		ca-certificates \
		fonts-texgyre \
    gnupg2 \
    apt-transport-https \ 
    software-properties-common \
    build-essential \
    git \
    libcurl4 \
    libcurl4-openssl-dev \
    libssl-dev \
    libmagick++-dev \
    libglu1-mesa-dev \ 
    freeglut3-dev \ 
    mesa-common-dev \
    cargo \
    autoconf \
    vim \
	&& rm -rf /var/lib/apt/lists/* \
  && echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen \
	&& locale-gen en_US.utf8 \
	&& /usr/sbin/update-locale LANG=en_US.UTF-8 \
  && apt-key adv --keyserver keyserver.ubuntu.com --recv-keys E298A3A825C0D65DFD57CBB651716619E084DAB9 \
  && add-apt-repository 'deb https://cloud.r-project.org/bin/linux/ubuntu bionic-cran35/' \
  && apt update \
  && apt install -y r-base \
  ## Add a default CRAN mirror
  && echo "options(repos = c(CRAN = 'https://cran.rstudio.com/'), download.file.method = 'libcurl')" >> /usr/lib/R/etc/Rprofile.site \
  ## Add a library directory (for user-installed packages)
  && mkdir -p /usr/lib/R/site-library \
  && chown root:staff /usr/lib/R/site-library \
  && chmod g+wx /usr/lib/R/site-library \
  ## Fix library path
  && echo "R_LIBS_USER='/usr/lib/R/site-library'" >> /usr/lib/R/etc/Renviron \
  && echo "R_LIBS=\${R_LIBS-'/usr/lib/R/site-library:/usr/lib/R/library:/usr/lib/R/library'}" >> /usr/lib/R/etc/Renviron \
  ## install packages from specific CRAN repo
  && echo "options(repos = c(CRAN='https://cloud.r-project.org'), download.file.method = 'libcurl')" >> /usr/lib/R/etc/Rprofile.site \
  ## Use littler installation scripts
  && R -e "install.packages(c('littler', 'docopt', 'devtools'), repo = 'https://cloud.r-project.org')" \
  && ln -s /usr/lib/R/site-library/littler/examples/install2.r /usr/bin/install2.r \
  && ln -s /usr/lib/R/site-library/littler/examples/installGithub.r /usr/bin/installGithub.r \
  && ln -s /usr/lib/R/site-library/littler/bin/r /usr/bin/r \
  && install2.r --error --deps TRUE knitr \
    entropy \
    dynamicTreeCut \
  # hypermutR install
  && R -e "devtools::install_github('philliplab/hypermutR')" \
  && R -e "file.symlink(from = file.path(find.package('hypermutR'), 'hypermutR.R'), to = '/usr/bin')" \
  # perl install
  && (echo y;echo o conf prerequisites_policy follow;echo o conf commit)|cpan \
  && cpan App::cpanminus \
  && cpanm Path::Tiny \
  && cpanm Sort::Fields \
  && cpanm WWW::Mechanize \
  && cpanm Statistics::Descriptive \
  && cpanm Readonly \
  # phyml patch and install
  && cd /usr/local/src \
  && git clone https://github.com/stephaneguindon/phyml \
  && cd phyml \
  && git checkout 8eb35001287ab083762aad1d9e68dcc462fdad1f \
  && cd /usr/local/src/phyml/src \
  && perl -0777 -i.bla -pe 's/$\s*tree\s*= mat->tree;\n\s*tree->mat\s*= mat;/tree = mat->tree;\n      tree->mat = mat;\n      Print_Mat(mat);\n      Exit("");\n/igs' utilities.c \
  && rm utilities.c.bla \
  && cd /usr/local/src/phyml \
  && sh ./autogen.sh \
  && ./configure --enable-phyml \
  && make

RUN su docker -c "git clone https://github.com/philliplab/hiv-founder-id /home/docker/hiv-founder-id" \
  && su docker -c "chmod u+x /home/docker/hiv-founder-id/*" \
  && su docker -c "cd ~/hiv-founder-id/tests; ./test_pipeline.R --pipeline_dir=/home/docker/hiv-founder-id --build_command_scripts" \
  && ln -s /usr/local/src/phyml/src/phyml /home/docker/hiv-founder-id/phyml \
  && su docker -c "mkdir /home/docker/example" \
  && su docker -c "cp /home/docker/hiv-founder-id/tests/example_data_v4/* /home/docker/example/." \
  && su docker -c "cp /home/docker/hiv-founder-id/tests/example_docker.sh /home/docker/." \
  && echo "hack to rebuild this layer : 32" > /tmp/hack.txt

USER docker

WORKDIR /home/docker

ENTRYPOINT ["/bin/bash"]
