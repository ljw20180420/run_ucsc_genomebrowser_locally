#!/bin/bash

# change to the dir of the script
cd $( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

_config_docker_build_and_run_proxy() {
    local port=$1

    mv ~/.docker/config.json ~/.docker/config.json.bak
    jq -s '.[0] * .[1]' ~/.docker/config.json.bak - \
        > ~/.docker/config.json \
        << EOF
{
    "proxies": {
            "default": {
            "httpProxy": "http://127.0.0.1:${port}",
            "httpsProxy": "http://127.0.0.1:${port}",
            "noProxy": "localhost,127.0.0.1/8"
        }
    }
}
EOF
}

_config_docker_daemon_proxy() {
    local port=$1

    mv ~/.config/docker/daemon.json ~/.config/docker/daemon.json.bak
    jq -s '.[0] * .[1]' ~/.config/docker/daemon.json.bak - \
        > ~/.config/docker/daemon.json \
        << EOF
{
    "proxies": {
        "http-proxy": "http://127.0.0.1:${port}",
        "https-proxy": "http://127.0.0.1:${port}",
        "no-proxy": "localhost,127.0.0.0/8"
    }
}
EOF
}

proxy() {
    local port=$1

    _config_docker_build_and_run_proxy ${port}
    _config_docker_daemon_proxy ${port}
    systemctl --user daemon-reload
    systemctl --user restart docker
}

read port < <(jq -r ".port" config.json)
proxy ${port}
