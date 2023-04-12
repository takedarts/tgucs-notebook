#!/bin/bash
# Copyright (c) Jupyter Development Team.
# Distributed under the terms of the Modified BSD License.

set -e

# Exec the specified command or fall back on bash
if [ $# -eq 0 ]; then
    cmd=( "bash" )
else
    cmd=( "$@" )
fi

run-hooks () {
    # Source scripts or run executable files in a directory
    if [[ ! -d "$1" ]] ; then
        return
    fi
    echo "$0: running hooks in $1"
    for f in "$1/"*; do
        case "$f" in
            *.sh)
                echo "$0: running $f"
                source "$f"
                ;;
            *)
                if [[ -x "$f" ]] ; then
                    echo "$0: running $f"
                    "$f"
                else
                    echo "$0: ignoring $f"
                fi
                ;;
        esac
    done
    echo "$0: done running hooks in $1"
}

run-hooks /usr/local/bin/start-notebook.d

# Handle special flags if we're root
if [ $(id -u) == 0 ] ; then
    # Get username, uid, gid from home directory stats
    NB_USER=`df | grep /home/jovyan | sed -r 's/^\S+:\/([es][0-9]+)\s+.*/\1/'`
    NB_UID=`stat -c "%u" /home/jovyan`
    NB_GID=`stat -c "%g" /home/jovyan`

    if [ -z "$NB_USER" ]; then
	NB_USER='user'
    fi

    # Change uid, gid, home to user settings if uid is 0.
    if [ "$NB_UID" == "0" ]; then
	NB_UID="1000"
	NB_GID="1000"
	chown -R $NB_UID:$NB_GID /home/jovyan
    fi

    # Change permission of home directory
    chmod go-w /home/jovyan/

    # Change owner of sketchbook directory (for processing)
    chown $NB_UID:$NB_GID /root/.processing 
    chown $NB_UID:$NB_GID /root/sketchbook

    # Change owner of quicklisp, maxima-jupyter directories (for maxima)
    chown -R $NB_UID:$NB_GID /usr/local/share/maxima-jupyter
    chown -R $NB_UID:$NB_GID /usr/local/share/quicklisp

    # Change gid
    groupmod -g $NB_GID users

    # Only attempt to change the jovyan username if it exists
    echo "Set username to: $NB_USER ($NB_UID:$NB_GID)"
    usermod -d /home/$NB_USER -u $NB_UID -g $NB_GID -l $NB_USER jovyan

    # handle home and working directory if the username changed
    echo "Relocating home dir to /home/$NB_USER"
    ln -s /home/jovyan "/home/$NB_USER"
    cd "/home/$NB_USER"

    # Copy sbclrc (for quicklisp)
    if [ ! -e "/home/$NB_USER/.sbclrc" ]; then
	cp "/usr/local/share/maxima-jupyter/sbclrc" "/home/$NB_USER/.sbclrc"
	chown $NB_UID:$NB_GID "/home/$NB_USER/.sbclrc"
    fi

    # Create ssh keys
    if [ ! -e "/home/$NB_USER/.ssh/" ]; then
	mkdir "/home/$NB_USER/.ssh" && ssh-keygen -f "/home/$NB_USER/.ssh/id_rsa" -t rsa -N ""
	cp "/home/$NB_USER/.ssh/id_rsa.pub" "/home/$NB_USER/.ssh/authorized_keys"
	chown $NB_UID:$NB_GID -R "/home/$NB_USER/.ssh"
    fi

    # Enable sudo if requested
    if [[ "$GRANT_SUDO" == "1" || "$GRANT_SUDO" == 'yes' ]]; then
        echo "Granting $NB_USER sudo access and appending $CONDA_DIR/bin to sudo PATH"
        echo "$NB_USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/notebook
    fi

    # Add $CONDA_DIR/bin to sudo secure_path
    sed -r "s#Defaults\s+secure_path=\"([^\"]+)\"#Defaults secure_path=\"\1:$CONDA_DIR/bin\"#" /etc/sudoers | grep secure_path > /etc/sudoers.d/path

    # Add a file server address to /etc/hosts
    echo "192.168.2.252 t1.cs.tohoku-gakuin.ac.jp" >> /etc/hosts
    echo "192.168.2.252 www.ds.tohoku-gakuin.ac.jp" >> /etc/hosts
    echo "192.168.2.252 gitlab.ds.tohoku-gakuin.ac.jp" >> /etc/hosts

    # Exec the command as NB_USER with the PATH and the rest of
    # the environment preserved
    run-hooks /usr/local/bin/before-notebook.d
    echo "Executing the command: ${cmd[@]}"
    exec sudo -E -H -u $NB_USER PATH=$PATH XDG_CACHE_HOME=/home/$NB_USER/.cache PYTHONPATH=${PYTHONPATH:-} "${cmd[@]}"
else
    echo "UID must be 0"
fi
