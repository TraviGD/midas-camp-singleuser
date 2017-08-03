FROM ubuntu:latest
MAINTAINER travigd@umich.edu

# Environment
# Configure environment
ENV SHELL /bin/bash
ENV NB_USER nbuser
ENV NB_UID 1000
ENV LC_ALL en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US.UTF-8
RUN apt-get update && \
    apt-get install -y locales && \
    locale-gen en_US.UTF-8

ENV DEBIAN_FRONTENT noninteractive
RUN apt-get update && \
    apt-get install -y build-essential wget bzip2 ca-certificates sudo \
                       locales fonts-liberation debhelper dpkg-dev \
                       libarpack2-dev libdouble-conversion-dev libdsfmt-dev \
                       libfftw3-dev libgmp-dev libjs-mathjax libmpfr-dev \
                       libopenblas-dev libopenlibm-dev libopenspecfun-dev \
                       libpcre2-dev libsuitesparse-dev libunwind8-dev \
                       libutf8proc-dev llvm-3.8-dev python3-sphinx \
                       python3-sphinx-rtd-theme python3 python3-pip \
                       python python-pip

# Install Tini
RUN wget --quiet https://github.com/krallin/tini/releases/download/v0.10.0/tini && \
    echo "1361527f39190a7338a0b434bd8c88ff7233ce7b9a4876f3315c22fce7eca1b0 *tini" | sha256sum -c - && \
    mv tini /usr/local/bin/tini && \
    chmod +x /usr/local/bin/tini

# Install Julia 0.5.2
ADD deps/apt.juliadeps.txt /root/apt.juliadeps.txt
RUN apt-get -y install $(cat /root/apt.juliadeps.txt)
RUN wget https://github.com/JuliaLang/julia/releases/download/v0.5.2/julia-0.5.2.tar.gz && \
    tar -xf julia-0.5.2.tar.gz && \
    cd julia-0.5.2 && echo prefix=/opt/julia-0.5 > Make.user && \
    make -j 8 && \
    make install

# Install Julia 0.6.0
RUN wget https://github.com/JuliaLang/julia/releases/download/v0.6.0/julia-0.6.0.tar.gz && \
    tar -xf julia-0.6.0.tar.gz && \
    cd julia-0.6.0 && echo prefix=/opt/julia-0.6 > Make.user && \
    ./contrib/download_cmake.sh && \
    make -j 8 && \
    make install


# Install any last minute dependencies (moved after Julia since compiling
# Julia takes a little longer than eternity)
ADD deps/apt.juliapkgdeps.txt /root/apt.juliapkgdeps.txt
RUN apt-get install -y $(cat /root/apt.juliapkgdeps.txt)

RUN useradd --create-home --shell $SHELL --uid $NB_UID $NB_USER
WORKDIR /home/$NB_USER
USER $NB_USER

# Install Julia packages/modules/whatever they're called
RUN mkdir .deps
ADD deps/julia.pkgs.txt .deps/julia.pkgs.txt
RUN for pkg in $(cat .deps/julia.pkgs.txt); do \
      echo "Pkg.add(\"$pkg\")"; \
      /opt/julia-0.5/bin/julia -e "Pkg.add(\"$pkg\")" && \
      /opt/julia-0.5/bin/julia -e "using $pkg" ;\
      /opt/julia-0.6/bin/julia -e "Pkg.add(\"$pkg\")" && \
      /opt/julia-0.6/bin/julia -e "using $pkg" ;\
    done

RUN pip3 install --user --upgrade pip && \
    pip3 install --user --upgrade docker

# Install JupyterHub and notebook
RUN pip3 install --user --upgrade jupyterhub==0.7.0 notebook pandoc

# Add start scripts
ADD bin/start-singleuser.sh /usr/local/bin/start-singleuser.sh
ADD bin/start.sh /usr/local/bin/start.sh
USER root
RUN chmod +x /usr/local/bin/start-singleuser.sh /usr/local/bin/start.sh

# TODO move this line to the very top
ENV PATH=/home/$NB_USER/.local/bin:$PATH
ENV update=1
USER root
RUN apt-get install -y git
USER $NB_USER
WORKDIR /home/$NB_USER
RUN git clone https://github.com/TraviGD/nbp.git nbp && \
    mkdir -p /home/$NB_USER/.local/share/jupyter/nbextensions && \
    cp -R ./nbp/nbunlocksection /home/$NB_USER/.local/share/jupyter/nbextensions/nbunlock && \
    jupyter nbextension enable nbunlock/main

# Add configuration
USER root
RUN mkdir -p /etc/jupyter
ADD jupyter_notebook_config.py /etc/jupyter

EXPOSE 8888
ENTRYPOINT ["tini", "--"]

USER $NB_USER
