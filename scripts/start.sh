#!/bin/bash
# Copyright (c) Jupyter Development Team.
# Distributed under the terms of the Modified BSD License.

set -e

# The _log function is used for everything this script wants to log. It will
# always log errors and warnings, but can be silenced for other messages
# by setting JUPYTER_DOCKER_STACKS_QUIET environment variable.
_log () {
    if [[ "$*" == "ERROR:"* ]] || [[ "$*" == "WARNING:"* ]] || [[ "${JUPYTER_DOCKER_STACKS_QUIET}" == "" ]]; then
        echo "$@"
    fi
}
_log "Entered start.sh with args:" "$@"

# A helper function to unset env vars listed in the value of the env var
# JUPYTER_ENV_VARS_TO_UNSET.
unset_explicit_env_vars () {
    if [ -n "${JUPYTER_ENV_VARS_TO_UNSET}" ]; then
        for env_var_to_unset in $(echo "${JUPYTER_ENV_VARS_TO_UNSET}" | tr ',' ' '); do
            _log "Unset ${env_var_to_unset} due to JUPYTER_ENV_VARS_TO_UNSET"
            unset "${env_var_to_unset}"
        done
        unset JUPYTER_ENV_VARS_TO_UNSET
    fi
}

# Default to starting bash if no command was specified
if [ $# -eq 0 ]; then
    cmd=( "bash" )
else
    cmd=( "$@" )
fi

# NOTE: This hook will run as the user the container was started with!
# shellcheck disable=SC1091
source /usr/local/bin/run-hooks.sh /usr/local/bin/start-notebook.d

# If the container started as the root user, then we have permission to refit
# the jovyan user, and ensure file permissions, grant sudo rights, and such
# things before we run the command passed to start.sh as the desired user
# (NB_USER).
#
if [ "$(id -u)" == 0 ] ; then
    # Get username, uid, gid from home directory stats
    NB_USER=`df | grep /home/jovyan | sed -r 's/^\S+:\/([es][0-9]+)\s+.*/\1/'`
    NB_UID=`stat -c "%u" /home/jovyan`
    NB_GID=`stat -c "%g" /home/jovyan`

    if [ -z "${NB_USER}" ]; then
    	NB_USER='user'
    fi

    # Change uid, gid, home to user settings if uid is 0.
    if [ "${NB_UID}" == "0" ]; then
    	NB_UID="1000"
	    NB_GID="1000"
    	chown -R ${NB_UID}:${NB_GID} /home/jovyan
    fi

    # Change permission of home directory
    chmod go-w /home/jovyan/

    # Change owner of quicklisp, maxima-jupyter directories (for maxima)
    chown -R ${NB_UID}:${NB_GID} /usr/local/share/maxima-jupyter
    chown -R ${NB_UID}:${NB_GID} /usr/local/share/quicklisp

    # Change gid
    groupmod -g ${NB_GID} users

    # Only attempt to change the jovyan username if it exists
    if ! id ${NB_USER} &> /dev/null ; then
        _log "Set username to: ${NB_USER} (${NB_UID}:${NB_GID})"
        usermod -d /home/${NB_USER} -u ${NB_UID} -g ${NB_GID} -l ${NB_USER} jovyan
    fi

    # Symlink home and working directory
    if [ ! -e /home/${NB_USER} ]; then
        _log "Relocating home dir to /home/${NB_USER}"
        ln -s /home/jovyan "/home/${NB_USER}"
        chown ${NB_UID}:${NB_GID} "/home/${NB_USER}"
    fi
    cd "/home/${NB_USER}"

    # Copy sbclrc (for quicklisp)
    if [ ! -e "/home/${NB_USER}/.sbclrc" ]; then
    	cp "/usr/local/share/maxima-jupyter/sbclrc" "/home/${NB_USER}/.sbclrc"
	    chown ${NB_UID}:${NB_GID} "/home/${NB_USER}/.sbclrc"
    fi

    # Update potentially outdated environment variables since image build
    export XDG_CACHE_HOME="/home/${NB_USER}/.cache"

    # Prepend ${CONDA_DIR}/bin to sudo secure_path
    sed -r "s#Defaults\s+secure_path\s*=\s*\"?([^\"]+)\"?#Defaults secure_path=\"${CONDA_DIR}/bin:\1\"#" /etc/sudoers | grep secure_path > /etc/sudoers.d/path

    # Optionally grant passwordless sudo rights for the desired user
    if [[ "$GRANT_SUDO" == "1" || "$GRANT_SUDO" == "yes" ]]; then
        _log "Granting ${NB_USER} passwordless sudo rights!"
        echo "${NB_USER} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/added-by-start-script
    fi

    # NOTE: This hook is run as the root user!
    # shellcheck disable=SC1091
    source /usr/local/bin/run-hooks.sh /usr/local/bin/before-notebook.d
    unset_explicit_env_vars

    _log "Running as ${NB_USER}:" "${cmd[@]}"
    exec sudo --preserve-env --set-home --user "${NB_USER}" \
        LD_LIBRARY_PATH="${LD_LIBRARY_PATH}" \
        PATH="${PATH}" \
        PYTHONPATH="${PYTHONPATH:-}" \
        "${cmd[@]}"

# The container must start as the root user.
else
    echo "UID must be 0"
fi
