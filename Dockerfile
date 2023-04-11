# Copyright (c) Atsushi TAKEDA
# Distributed under the terms of the Modified BSD License.
ARG BASE_CONTAINER=jupyter/datascience-notebook:lab-3.5.3
FROM $BASE_CONTAINER

LABEL maintainer="Atsushi TAKEDA <takeda@cs.tohoku-gakuin.ac.jp>"

USER root

# re-install for manuals
RUN rm /etc/dpkg/dpkg.cfg.d/excludes &&\
    apt-get update && \
    apt-get install -y --reinstall libgcc-s1:amd64 && \
    dpkg -l | grep ^ii | cut -d' ' -f3 | grep -v '^libgcc-s1:amd64$' | xargs apt-get install -y --reinstall && \
    apt-get clean && \
    rm -r /var/lib/apt/lists/* && \
    echo 'y' | unminimize

# required softwares
RUN apt-get update && \
    apt-get install -y --no-install-recommends man less curl vim emacs openssh-client rsync && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# network tools
RUN apt-get update && \
    apt-get install -y --no-install-recommends iputils-ping net-tools && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# python
RUN conda install --quiet --yes \
    autopep8 \
    isort \
    xeus-python \
    jupyter-dash \
    plotly \
    polars \
    jupyterlab_code_formatter && \
    conda clean --all -f -y && \
    pip install \
    ipyturtle3 \
    lckr-jupyterlab-variableinspector && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER

# processing
RUN wget -q https://download.processing.org/processing-3.5.4-linux64.tgz && \
    tar xf processing-3.5.4-linux64.tgz && \
    mv processing-3.5.4 /opt/processing && \
    rm -f processing-3.5.4-linux64.tgz && \
    pip install calysto_processing && \
    python -m calysto_processing install && \
    mv /usr/local/share/jupyter/kernels/calysto_processing /opt/conda/share/jupyter/kernels/ && \
    chmod go+x /root && \
    mkdir /root/.processing && chown $NB_UID:$NB_GID /root/.processing && \
    mkdir /root/sketchbook && chown $NB_UID:$NB_GID /root/sketchbook && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER

ENV PROCESSING_JAVA=/opt/processing/processing-java    

# bash
RUN conda install --quiet --yes \
    bash \
    bash_kernel && \
    conda clean --all -f -y && \
    python -m bash_kernel.install && \
    rm -rf /usr/local/share/jupyter/kernels/bash && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER

# maxima
# use maxima-jupyter@538ac8309f064a85fc9a5b7edd709e00553f94ef
# the newer versions do not display figures.
RUN apt-get update && \
    apt-get install -y --no-install-recommends texinfo sbcl libczmq-dev gnuplot && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    curl -O https://beta.quicklisp.org/quicklisp.lisp && \
    sbcl --load quicklisp.lisp \
    --eval '(quicklisp-quickstart:install :path "/usr/local/share/quicklisp/")' \
    --eval '(ql-util:without-prompting (ql:add-to-init-file))' \
    --eval '(quit)' && \
    rm quicklisp.lisp && \
    echo "(asdf:initialize-output-translations" >> /home/$NB_USER/.sbclrc && \
    echo " '(:output-translations :disable-cache :ignore-inherited-configuration))" >> /home/$NB_USER/.sbclrc && \
    curl -OL https://sourceforge.net/projects/maxima/files/Maxima-source/5.45.1-source/maxima-5.45.1.tar.gz && \
    tar xf maxima-5.45.1.tar.gz && \
    cd maxima-5.45.1 && \
    ./configure --enable-sbcl --prefix=/usr/local && \
    make && \
    make install && \
    cd .. && \
    rm -rf maxima-5.45.1 maxima-5.45.1.tar.gz && \
    git clone https://github.com/robert-dodier/maxima-jupyter && \
    cd maxima-jupyter && \
    git checkout 538ac8309f064a85fc9a5b7edd709e00553f94ef && \
    maxima --batch-string="load(\"load-maxima-jupyter.lisp\");jupyter_install();" && \
    cd .. && \
    rm -rf maxima-jupyter && \
    mv /home/$NB_USER/.local/share/maxima-jupyter /usr/local/share/ && \
    cp /home/$NB_USER/.sbclrc /usr/local/share/maxima-jupyter/sbclrc && \
    mkdir /opt/conda/share/jupyter/kernels/maxima && \
    sed -e "s/\/home\/$NB_USER\/.local/\/usr\/local/" \
    /home/$NB_USER/.local/share/jupyter/kernels/maxima/kernel.json > /opt/conda/share/jupyter/kernels/maxima/kernel.json && \
    cp /home/$NB_USER/.local/share/jupyter/kernels/maxima/logo-64x64.png /opt/conda/share/jupyter/kernels/maxima/ && \
    rm -rf /home/$NB_USER/.local/share/jupyter && \
    maxima --batch-string="load(\"/usr/local/share/maxima-jupyter/local-projects/maxima-jupyter/load-maxima-jupyter.lisp\");" && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER

# ruby
RUN apt-get update && \
    apt-get install -y --no-install-recommends libtool libffi-dev ruby ruby-dev make && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    gem install iruby && \
    iruby register --force && \
    mv /home/$NB_USER/.local/share/jupyter/kernels/ruby /opt/conda/share/jupyter/kernels/ruby && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER

# extensions
RUN conda install --quiet --yes \
    jupyterlab-language-pack-ja-JP \
    jupyterlab-git && \
    conda clean --all -f -y && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER

# build jupyter lab
RUN jupyter lab build

# scripts
COPY scripts/start.sh /usr/local/bin/start.sh
RUN chmod 755 /usr/local/bin/start.sh

# patches
RUN cd /opt/conda/share/jupyter/lab/static/ && \
    curl -O https://requirejs.org/docs/release/2.3.6/minified/require.js

COPY patches/docmanager.patch \
    patches/extensionmanager.patch \
    patches/inspector.patch \
    patches/quicklisp.patch \
    patches/terminal.patch \
    patches/translation.patch \
    patches/formatter.patch \
    patches/processing.patch \
    /home/$NB_USER/

RUN cd /opt/conda/share/jupyter/lab/static/ && \
    sed -e 's/<\/head>/<script defer="defer" src="{{page_config.fullStaticUrl}}\/require.js"><\/script><\/head>/' \
    index.html > index.html.new && mv index.html.new index.html && \
    cd /opt/conda/share/jupyter/lab/schemas/\@jupyterlab/docmanager-extension/ && \
    patch -p1 < /home/$NB_USER/docmanager.patch && \
    cd /opt/conda/share/jupyter/lab/schemas/\@jupyterlab/extensionmanager-extension/ && \
    patch -p1 < /home/$NB_USER/extensionmanager.patch && \
    cd /opt/conda/share/jupyter/lab/schemas/\@jupyterlab/inspector-extension/ && \
    patch -p1 < /home/$NB_USER/inspector.patch && \
    cd /opt/conda/share/jupyter/lab/schemas/\@jupyterlab/terminal-extension/ && \
    patch -p1 < /home/$NB_USER/terminal.patch && \
    cd /opt/conda/share/jupyter/lab/schemas/\@jupyterlab/translation-extension/ && \
    patch -p1 < /home/$NB_USER/translation.patch && \
    cd /opt/conda/share/jupyter/labextensions/@ryantam626/jupyterlab_code_formatter/schemas/@ryantam626/jupyterlab_code_formatter && \
    patch -p1 < /home/$NB_USER/formatter.patch && \
    cd /opt/conda/lib/python3.10/site-packages/calysto_processing/ && \
    patch -p1 < /home/$NB_USER/processing.patch && \
    COMMON_LISP_JUPYTER=`ls /usr/local/share/quicklisp/dists/quicklisp/software/ | grep 'common-lisp-jupyter'` && \
    cd /usr/local/share/quicklisp/dists/quicklisp/software/$COMMON_LISP_JUPYTER/src/ && \
    patch -p1 < /home/$NB_USER/quicklisp.patch && \
    rm -f /home/$NB_USER/*.patch

# clean-up
RUN cd && rm -rf * `find ./ -maxdepth 1 | grep '\./\..'`

# change default page to "Lab-style" page
CMD ["start-notebook.sh", "--NotebookApp.default_url=\"/lab\""]

# change default timezone to JST
ENV TZ Asia/Tokyo

USER $NB_UID
