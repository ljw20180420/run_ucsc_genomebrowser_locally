#!/bin/bash

run() {
    if [ "$(docker ps -aq -f name=^/ucsc_genomebrowser$)" ]; then
        echo "Container exists. Starting it..."
        docker start ucsc_genomebrowser
    else
        echo "Container does not exist. Creating and running a new one..."
        docker run -d \
            --name ucsc_genomebrowser \
            -p 8080:80 \
            -v ${hub_dir}:/usr/local/apache/htdocs/myHub \
            ljw/ucsc_genomebrowser_image \
            /sbin/my_init \
            --skip-startup-files
    fi
}

update() {
    docker exec ucsc_genomebrowser /bin/bash /root/browserSetup.sh cgiUpdate
}

cmd=$1
shift
"${cmd}" "$@"
