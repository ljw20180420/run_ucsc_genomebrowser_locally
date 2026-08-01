# Usage

Clone repository.
```shell
$ git clone git@github.com:ljw20180420/run_ucsc_genomebrowser_locally.git
$ cd run_ucsc_genomebrowser_locally
```
Write [`config.json`](src/config.json). Generate hub tree by running
```shell
$ src/hub.sh
```

Run
```shell
$ docker compose up
```
Then visit [connection hub](http://localhost:8080/cgi-bin/hgHubConnect?hgHub_do_redirect=on&hgHubConnect.remakeTrackHub=on&hgHub_do_firstDb=1&hubUrl=http://localhost/myHub/hub.txt). Press `d` to make the ucsc local docker container running in the backgroud, or you can directly run
```shell
$ docker compose up -d
```

To stop the container but not delete it, run
```shell
$ docker compose stop
```
To restart the stopped container, run
```shell
$ docker compose start
```

To stop and delete the container, run
```shell
$ docker compose down
```
Then to recreate the deleted container, you need to run
```shell
$ docker compose up
```

# TODO

- 加入bed
