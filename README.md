# Signal Web Gateway

Putting [janimo's](https://github.com/janimo/textsecure) behind a Flask/Gunicorn server to have a web gateway.

## Prepare config and storage

If you do not already have a config file, just create one like this:

```
mkdir .config .storage
sudo chown -R 1000:1000 .config .storage # needs to belong to signal user
docker run --rm -it registry.gitlab.com/morph027/signal-web-gateway:master cat .config/config.yml > .config/config.yml
```

## Register

Now you need to register like described at [janimo's wiki](https://github.com/janimo/textsecure/wiki/Installation). This could be done via SMS or Voice (for SIP numbers)
Edit the `.config/config.yml` to suit your needs and start the registration:

```
docker run --rm -it --name signal-web-gateway -v $PWD/.config:/signal/.config -v $PWD/.storage:/signal/.storage -p 5000:5000 registry.gitlab.com/morph027/signal-web-gateway:master /bin/sh
./textsecure
```

## Run


```
docker run -d --name signal-web-gateway -v $PWD/.config:/signal/.config -v $PWD/.storage:/signal/.storage -p 5000:5000 registry.gitlab.com/morph027/signal-web-gateway:master
```

## Access

Now you can just use curl to send messages using the form data `to`, `message`, `file` (optionally) and `group` (optionally):

* Plain text (assuming you're running against the docker container at your machine):

```
curl -X POST -F "to=+1337" -F "message=Test" http://localhost:5000
```

* Text message with attachement (assuming you're running against the docker container at your machine):

```
curl -X POST -F file=@some-random-cat-picture.gif -F "to=+1337" -F "message=Test" http://localhost:5000
```

* Send to groups (assuming you're running against the docker container at your machine):

```
curl -X POST -F "to=ff702f10bebfa2f1508deb475ded2d65" -F "group=True" -F "message=Test" http://localhost:5000
```

You can retrieve the groupid by having a look into `.storage/groups`

## Security

You might want to run this behind an reverse proxy like nginx to add some basic auth or (much better) run this inside Docker swarm with [Docker Flow Proxy](https://proxy.dockerflow.com) and [basic auth](https://proxy.dockerflow.com/swarm-mode-auto/#service-authentication) using secrets.
