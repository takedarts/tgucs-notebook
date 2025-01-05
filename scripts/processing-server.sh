#!/bin/bash

set -e

# Add a configuration for jupyter-server-proxy
tee --append /etc/jupyter/jupyter_server_config.py > /dev/null <<EOF

# Register a http server
c.ServerProxy.servers["processing"] = {
    "command" : ["python", "-m", "http.server", "-d", "/opt/processing", "8100"],
    "launcher_entry": {
        "enabled": True,
        "icon_path": "/opt/processing/processing.svg",
        "title": "Processing",
    },
    "port": 8100,
}
EOF

