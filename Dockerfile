# Copyright (c) Atsushi TAKEDA
# Distributed under the terms of the Modified BSD License.
FROM --platform=linux/amd64 jupyter/datascience-notebook:lab-4.0.7

LABEL maintainer="Atsushi TAKEDA <takedarts@mail.tohoku-gakuin.ac.jp>"

USER root

# update packages and install manuals
RUN apt-get update && \
    apt-get upgrade -y && \
    # common softwares
    apt-get install -y --no-install-recommends \
    libtool vim emacs rsync make \
    iputils-ping iputils-arping iputils-tracepath \
    net-tools dnsutils telnet && \
    # for ruby
    apt-get install -y --no-install-recommends \
    libffi-dev libzmq3-dev ruby ruby-dev && \
    # for maxima
    apt-get install -y --no-install-recommends \
    texinfo sbcl libczmq-dev gnuplot cl-quicklisp && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER && \
    cd && rm -rf * `find ./ -maxdepth 1 | grep '\./\..'`

# update conda and remove jupyter-pluto-proxy
RUN conda install conda==23.11.0 && \
    conda remove jupyter-pluto-proxy && \
    conda clean --all -f -y && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER && \
    cd && rm -rf * `find ./ -maxdepth 1 | grep '\./\..'`

# disable announcements "Would you like to receive official Jupyter news?"
RUN jupyter labextension disable "@jupyterlab/apputils-extension:announcements" && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER && \
    cd && rm -rf * `find ./ -maxdepth 1 | grep '\./\..'`

# python
RUN conda install --quiet --yes \
    autopep8==2.3.1 \
    isort==5.13.2 \
    xeus-python==0.15.12 \
    xeus-zmq==1.1.1 \
    dash==2.18.0 \
    jupyter-dash==0.4.2 \
    ipython-sql==0.3.9 \
    lightgbm==4.5.0 \
    plotly==5.24.1 \
    polars==1.15.0 && \
    conda clean --all -f -y && \
    pip install \
    ipyturtle3==0.1.4 && \
    pip cache purge && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER && \
    cd && rm -rf * `find ./ -maxdepth 1 | grep '\./\..'` 

# bash
RUN conda install --quiet --yes \
    bash==5.2.21 \
    bash_kernel==0.9.3 && \
    conda clean --all -f -y && \
    python -m bash_kernel.install && \
    rm -rf /usr/local/share/jupyter/kernels/bash && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER && \
    cd && rm -rf * `find ./ -maxdepth 1 | grep '\./\..'`

# maxima
RUN sbcl --load /usr/share/common-lisp/source/quicklisp/quicklisp.lisp \
    --eval '(quicklisp-quickstart:install :path "/usr/local/share/quicklisp/")' \
    --eval '(ql-util:without-prompting (ql:add-to-init-file))' \
    --eval '(quit)' && \
    echo "(asdf:initialize-output-translations" >> /home/$NB_USER/.sbclrc && \
    echo " '(:output-translations :disable-cache :ignore-inherited-configuration))" >> /home/$NB_USER/.sbclrc && \
    curl -OL https://sourceforge.net/projects/maxima/files/Maxima-source/5.45.1-source/maxima-5.45.1.tar.gz && \
    tar xf maxima-5.45.1.tar.gz && \
    cd maxima-5.45.1 && \
    ./configure --enable-sbcl --enable-lang-ja --prefix=/usr/local && \
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
    fix-permissions /home/$NB_USER && \
    cd && rm -rf * `find ./ -maxdepth 1 | grep '\./\..'`

# ruby
RUN gem install iruby -v 0.7.4 && \
    gem cleanup && \
    iruby register --force && \
    mv /home/$NB_USER/.local/share/jupyter/kernels/ruby /opt/conda/share/jupyter/kernels/ruby && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER && \
    cd && rm -rf * `find ./ -maxdepth 1 | grep '\./\..'`

# extensions
RUN conda install --quiet --yes \
    jupyterlab-language-pack-ja-jp==4.1.post0 \
    jupyterlab_code_formatter==2.2.1 \
    jupyterlab-git==0.50.0 && \
    conda install --quiet --yes -c conda-forge \
    jupyter-server-proxy==4.1.0 \
    jupyterlab-variableinspector==3.2.1 && \
    conda clean --all -f -y && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER && \
    cd && rm -rf * `find ./ -maxdepth 1 | grep '\./\..'`

# Vidual Studio Code
COPY scripts/code-server.sh /home/$NB_USER/
RUN sh code-server.sh --version 4.21.2 && \
    rm -f code-server.sh && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER && \
    cd && rm -rf * `find ./ -maxdepth 1 | grep '\./\..'`

# Http Server
COPY scripts/http-server.sh /home/$NB_USER/
RUN bash http-server.sh && \
    rm -f http-server.sh && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER && \
    cd && rm -rf * `find ./ -maxdepth 1 | grep '\./\..'`

# build jupyter lab
RUN jupyter lab build

# download IPAex japanese font to matplotlib
RUN curl -OL https://moji.or.jp/wp-content/ipafont/IPAexfont/IPAexfont00401.zip && \
    unzip IPAexfont00401.zip && \
    cp IPAexfont00401/ipaexg.ttf /opt/conda/lib/python3.11/site-packages/matplotlib/mpl-data/fonts/ttf/IPAexGothic.ttf && \
    cp IPAexfont00401/ipaexm.ttf /opt/conda/lib/python3.11/site-packages/matplotlib/mpl-data/fonts/ttf/IPAexMincho.ttf && \
    chmod 644 /opt/conda/lib/python3.11/site-packages/matplotlib/mpl-data/fonts/ttf/IPAexGothic.ttf && \
    chmod 644 /opt/conda/lib/python3.11/site-packages/matplotlib/mpl-data/fonts/ttf/IPAexMincho.ttf && \
    rm -rf IPAexfont00401.zip IPAexfont00401

# patches
COPY patches/docmanager.patch \
    patches/extensionmanager.patch \
    patches/inspector.patch \
    patches/quicklisp.patch \
    patches/terminal.patch \
    patches/translation.patch \
    patches/formatter.patch \
    patches/matplotlibrc.patch \
    /home/$NB_USER/
RUN cd /opt/conda/share/jupyter/lab/schemas/\@jupyterlab/docmanager-extension/ && \
    patch -p1 < /home/$NB_USER/docmanager.patch && \
    cd /opt/conda/share/jupyter/lab/schemas/\@jupyterlab/extensionmanager-extension/ && \
    patch -p1 < /home/$NB_USER/extensionmanager.patch && \
    cd /opt/conda/share/jupyter/lab/schemas/\@jupyterlab/inspector-extension/ && \
    patch -p1 < /home/$NB_USER/inspector.patch && \
    cd /opt/conda/share/jupyter/lab/schemas/\@jupyterlab/terminal-extension/ && \
    patch -p1 < /home/$NB_USER/terminal.patch && \
    cd /opt/conda/share/jupyter/lab/schemas/\@jupyterlab/translation-extension/ && \
    patch -p1 < /home/$NB_USER/translation.patch && \
    cd /opt/conda/share/jupyter/labextensions/jupyterlab_code_formatter/schemas/jupyterlab_code_formatter/ && \
    patch -p1 < /home/$NB_USER/formatter.patch && \
    cd /opt/conda/lib/python3.11/site-packages/matplotlib/mpl-data/ && \
    patch -p1 < /home/$NB_USER/matplotlibrc.patch && \
    COMMON_LISP_JUPYTER=`ls /usr/local/share/quicklisp/dists/quicklisp/software/ | grep 'common-lisp-jupyter'` && \
    cd /usr/local/share/quicklisp/dists/quicklisp/software/$COMMON_LISP_JUPYTER/src/ && \
    patch -p1 < /home/$NB_USER/quicklisp.patch && \
    cd && rm -rf * `find ./ -maxdepth 1 | grep '\./\..'`

# scripts
COPY scripts/start.sh /usr/local/bin/start.sh
RUN chmod 755 /usr/local/bin/start.sh

# change default page to "Lab-style" page
CMD ["start-notebook.sh", "--NotebookApp.default_url=\"/lab\""]

# change default timezone to JST
ENV TZ Asia/Tokyo

USER $NB_UID
