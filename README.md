# Signal Web Gateway

Putting [janimo's](https://github.com/janimo/textsecure) Signal client behind a web server to have a web gateway for other apps (reporting, monitoring, ...).

You might want to check the [wiki](https://gitlab.com/morph027/signal-web-gateway/wikis/home) for more stuff (like a signal-web-gateway addon).

This setup runs in Docker, so you can easily throw it into your swarm. If you want to run it standalone, just have a look at the bottom of this page.

**You will need a spare phone number to use for registration!** (SIP numbers are fine)

## Prepare config and storage

If you do not already have a config file, just create one like this:

```
mkdir .config .storage
touch .config/contacts.yml
docker run --rm -it registry.gitlab.com/morph027/signal-web-gateway:master cat .config/config.yml > .config/config.yml
sudo chown -R 1000:1000 .config .storage # needs to belong to signal user
```

## Register

Now you need to register like described at [janimo's wiki](https://github.com/janimo/textsecure/wiki/Installation). This could be done via SMS or Voice (for SIP numbers)
Edit the `.config/config.yml` to suit your needs and start the registration:

```
docker run --rm -it -v $PWD/.config:/signal/.config -v $PWD/.storage:/signal/.storage registry.gitlab.com/morph027/signal-web-gateway:master /bin/sh
./textsecure
# confirm code
# ctrl+c
# ctrl+d
```

A cool way to register test numbers is [SMSReceiveFree](https://smsreceivefree.com/).

## Run

```
docker run -d --name signal-web-gateway --restart always -v $PWD/.config:/signal/.config -v $PWD/.storage:/signal/.storage -p 5000:5000 registry.gitlab.com/morph027/signal-web-gateway:master
```

## Access

### Multipart form data (w/ image upload)

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
curl -X POST -F "to=ff702f10bebfa2f1508deb475ded2d65" -F "message=Test" http://localhost:5000
```

You can retrieve the groupid by having a look into `.storage/groups`

### JSON data to specific path

If your sending app for whatever reasons is unable to specify form values and just posts json webhooks (Influx Kapacitor, Gitlab webhooks), you can post this data to a path containing the recipient (e.g. `/+1337` or `/ff702f10bebfa2f1508deb475ded2d65`).
The gateway then tries to send the value from json key defined in environment variable `JSON_MESSAGE`.

Example:

```
curl -X POST -d '{"message":"foo"}' http://localhost:5000/+1337
```

### Rekey in case of re-installing Signal

If you (or someone) has re-installed Signal (or switched to a new mobile), the Signal app and the servers will create new keys and this gateway refuses to send messages due to the changed key. You can send a `DELETE` request to `/<recipient>` to delete the old key and receive messages again.

```
curl -X DELETE http://localhost:5000/491337420815
```

## Security

You might want to run this behind an reverse proxy like nginx to add some basic auth or (much better) run this inside Docker swarm with [Docker Flow Proxy](https://proxy.dockerflow.com) and [basic auth](https://proxy.dockerflow.com/swarm-mode-auto/#service-authentication) using secrets.

## Standalone

If you want to run this without Docker, you need to setup:

* janimo's [go binary]([wiki](https://gitlab.com/morph027/signal-web-gateway/wikis/home))
* a dedicated user
* a python virtualenv for this user
* python requirements
* app
* startup script (e.g. systemd unit file)
* reverse proxy (in case you want to secure using basic auth and tls, ...)

### User

```
useradd -s /bin/bash -m signal
```

### Virtualenv + requirements

```
sudo -u signal -H virtualenv /home/signal/virtualenv
sudo -u signal -H pip install flask gunicorn
```

### App

```
sudo -u signal -H git clone https://gitlab.com/morph027/signal-web-gateway /home/signal/signal-web-gateway
```

### Startup

This is an example which listens on a socket fot it's reverse proxy

`/etc/systemd/system/signal-web-gateway.socket`:

```
[Unit]
Description=signal-web-gateway gunicorn socket

[Socket]
ListenStream=/run/signal-web-gateway/socket

[Install]
WantedBy=sockets.target
```

`/etc/systemd/system/signal-web-gateway.service`:

```
[Unit]
Description=signal-web-gateway daemon
Requires=signal-web-gateway.socket
After=network.target

[Service]
PIDFile=/run/signal-web-gateway/pid
User=signal
Group=signal
RuntimeDirectory=signal-web-gateway
WorkingDirectory=/home/signal/signal-web-gateway
ExecStart=/home/signal/virtualenv/bin/gunicorn --pid /run/signal-web-gateway/pid --bind unix:/run/signal-web-gateway/socket signal-web-gateway:app
ExecReload=/bin/kill -s HUP $MAINPID
ExecStop=/bin/kill -s TERM $MAINPID
PrivateTmp=true

[Install]
WantedBy=multi-user.target
```

### Reverse proxy

As there are plenty of proxy or webservers (e.g. nginx, apache, caddy, traefik,...), just pick your favourite one. Make sure to proxy requests to the socket at `/run/signal-web-gateway/socket`.
