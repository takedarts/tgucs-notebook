# Copyright (c) Atsushi TAKEDA
# Distributed under the terms of the Modified BSD License.
ARG BASE_CONTAINER=jupyter/scipy-notebook:9b87b1625445
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
    apt-get install -y --no-install-recommends man less curl vim openssh-client rsync && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

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

# php
RUN wget https://litipk.github.io/Jupyter-PHP-Installer/dist/jupyter-php-installer.phar && \
    apt-get update -y && \
    apt-get install -y --no-install-recommends \
    php \
    php-bz2 \
    php-cli \
    php-common \
    php-curl \
    php-gd \
    php-gmp \
    php-json \
    php-mbstring \
    php-readline \
    php-sqlite3 \
    php-xml \
    php-xmlrpc \
    php-zip \
    php-zmq \
    && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    curl -sS https://getcomposer.org/installer | php && \
    mv composer.phar /usr/local/bin/composer && \
    composer require psy/psysh && \
    php jupyter-php-installer.phar install -vv && \
    mv /usr/local/share/jupyter/kernels/jupyter-php /opt/conda/share/jupyter/kernels/ && \
    rm -rf /home/$NB_USER/vendor && \		    
    rm -f /home/$NB_USER/composer.json /home/$NB_USER/composer.lock && \
    rm -f /home/$NB_USER/jupyter-php-installer.phar && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER

# maxima
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
    curl -OL https://sourceforge.net/projects/maxima/files/Maxima-source/5.44.0-source/maxima-5.44.0.tar.gz && \
    tar xf maxima-5.44.0.tar.gz && \
    cd maxima-5.44.0 && \
    ./configure --enable-sbcl --prefix=/usr/local && \
    make && \
    make install && \
    cd .. && \
    rm -rf maxima-5.44.0 maxima-5.44.0.tar.gz && \
    git clone https://github.com/robert-dodier/maxima-jupyter && \
    cd maxima-jupyter && \
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

# python debugger
# RUN conda install --quiet --yes \
#    xeus-python \
#    jupyterlab-git && \
#    conda clean --all -f -y && \
#    jupyter labextension install @jupyterlab/debugger@^0.2.0 --no-build && \
#    jupyter labextension install @jupyterlab/toc@^3.0.0 --no-build && \
#    jupyter lab build -y && \
#    jupyter lab clean -y && \
#    npm cache clean --force && \
#    rm -rf /home/$NB_USER/.cache/yarn && \
#    rm -rf /home/$NB_USER/.node-gyp && \
#    fix-permissions $CONDA_DIR && \
#    fix-permissions /home/$NB_USER

# cling
# RUN conda install --quiet --yes 'xeus-cling' && \
#    conda clean --all -f -y && \
#    fix-permissions $CONDA_DIR && \
#    fix-permissions /home/$NB_USER

# install network tools
RUN apt-get update && \
    apt-get install -y --no-install-recommends iputils-ping net-tools && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# patches
RUN cp /usr/local/bin/start.sh /usr/local/bin/start.sh- && \
    cp /opt/conda/lib/python3.8/site-packages/calysto_processing/kernel.py \
    /opt/conda/lib/python3.8/site-packages/calysto_processing/kernel.py-

COPY start.sh /usr/local/bin/start.sh
COPY calysto_processing.patch /opt/conda/lib/python3.8/site-packages/calysto_processing/kernel.patch
RUN patch -u /opt/conda/lib/python3.8/site-packages/calysto_processing/kernel.py \
    < /opt/conda/lib/python3.8/site-packages/calysto_processing/kernel.patch

RUN curl -O https://requirejs.org/docs/release/2.3.6/minified/require.js && \
    mv require.js /opt/conda/share/jupyter/lab/static/require.js

RUN mv /opt/conda/share/jupyter/lab/static/index.html /opt/conda/share/jupyter/lab/static/index.html- && \
    sed -e 's/<\/body>/<script type="text\/javascript" src="{{page_config.fullStaticUrl}}\/require.js"><\/script><\/body>/' \
    /opt/conda/share/jupyter/lab/static/index.html- > /opt/conda/share/jupyter/lab/static/index.html

RUN mv /opt/conda/share/jupyter/lab/schemas/\@jupyterlab/terminal-extension/plugin.json \
    /opt/conda/share/jupyter/lab/schemas/\@jupyterlab/terminal-extension/plugin.json- && \
    sed -e 's/"default": "monospace"/"default": "Monaco, monospace"/' \
    /opt/conda/share/jupyter/lab/schemas/\@jupyterlab/terminal-extension/plugin.json- \
    > /opt/conda/share/jupyter/lab/schemas/\@jupyterlab/terminal-extension/plugin.json

RUN COMMON_LISP_JUPYTER=`ls /usr/local/share/quicklisp/dists/quicklisp/software/ | grep 'common-lisp-jupyter'` && \
    mv /usr/local/share/quicklisp/dists/quicklisp/software/$COMMON_LISP_JUPYTER/src/kernel.lisp \
    /usr/local/share/quicklisp/dists/quicklisp/software/$COMMON_LISP_JUPYTER/src/kernel.lisp- && \
    sed -e 's/\"common-lisp-jupyter\"/\"\.common-lisp-jupyter\"/' \
    /usr/local/share/quicklisp/dists/quicklisp/software/$COMMON_LISP_JUPYTER/src/kernel.lisp- \
    > /usr/local/share/quicklisp/dists/quicklisp/software/$COMMON_LISP_JUPYTER/src/kernel.lisp

RUN cd && rm -rf * `find ./ -maxdepth 1 | grep '\./\..'`

USER $NB_UID
