# Bind Docker

> A lightweight DNS resolution server built on Alpine.

[简体中文](./README_zh-CN.md)

## Quick Start

Use the following commands to view Bind's version, feature support, and compilation information.

```bash
$ docker run --rm dnomd343/bind -V
BIND 9.18.19 (Extended Support Version) <id:c78cd36>
running on Linux aarch64 6.5.11-linuxkit #1 SMP PREEMPT Mon Dec  4 11:30:00 UTC 2023
built by make with  '--build=aarch64-alpine-linux-musl' '--host=aarch64-alpine-linux-musl' '--prefix=/usr' '--sysconfdir=/etc/bind' '--localstatedir=/var' '--mandir=/usr/share/man' '--infodir=/usr/share/info' '--with-gssapi=yes' '--with-libxml2' '--with-openssl=yes' '--enable-dnstap' '--enable-largefile' '--enable-linux-caps' '--enable-shared' '--disable-static' 'build_alias=aarch64-alpine-linux-musl' 'host_alias=aarch64-alpine-linux-musl' 'CC=gcc' 'CFLAGS=-Os -Wformat -Werror=format-security -g -D_GNU_SOURCE' 'LDFLAGS=-Wl,--as-needed,-O1,--sort-common' 'CPPFLAGS=-Os -Wformat -Werror=format-security'
compiled by GCC 12.2.1 20220924
compiled with OpenSSL version: OpenSSL 3.1.3 19 Sep 2023
linked to OpenSSL version: OpenSSL 3.1.4 24 Oct 2023
compiled with libuv version: 1.44.2
linked to libuv version: 1.44.2
compiled with libnghttp2 version: 1.55.1
linked to libnghttp2 version: 1.57.0
compiled with libxml2 version: 2.11.4
linked to libxml2 version: 21106
compiled with zlib version: 1.2.13
linked to zlib version: 1.2.13
compiled with protobuf-c version: 1.4.1
linked to protobuf-c version: 1.4.1
threads support is enabled
DNSSEC algorithms: RSASHA1 NSEC3RSASHA1 RSASHA256 RSASHA512 ECDSAP256SHA256 ECDSAP384SHA384 ED25519 ED448
DS algorithms: SHA-1 SHA-256 SHA-384
HMAC algorithms: HMAC-MD5 HMAC-SHA1 HMAC-SHA224 HMAC-SHA256 HMAC-SHA384 HMAC-SHA512
TKEY mode 2 support (Diffie-Hellman): yes
TKEY mode 3 support (GSS-API): yes

...
```

The [default configuration](./named.conf) let Bind listening on local port 53 as a recursive DNS server, here is an example of it.

```bash
$ docker run --rm --network host dnomd343/bind
13-Dec-2023 23:04:35.370 starting BIND 9.18.19 (Extended Support Version) <id:c78cd36>
...
```

You can verify that the DNS server is working by entering the following command in another terminal.

```bash
$ dig +short @127.0.0.1 google.com
172.217.163.46
```

In more cases, Bind is used as the authoritative DNS server. When deploying, you should choose a working directory, such as `/var/service/bind/`, and create the `named.conf` configuration file under it. A simple example is as follows, which provides authoritative resolution of the `example.com` domain name and logging to files.

> Most of the time, it's a bad idea to provide both recursive and authoritative resolution, even if Bind can do it.

```
options {
    listen-on { any; };
    listen-on-v6 { any; };
    directory "/var/bind";

    recursion no;
    allow-query { any; };
    dnssec-validation yes;
    allow-transfer { none; };
};

logging {
    channel query_log {
        file "/var/log/bind/query.log" versions 5 size 50m;
        print-time yes;
        severity info;
    };
    category queries { query_log; };
    channel general_log {
        file "/var/log/bind/general.log" versions 5 size 50m;
        print-time yes;
        print-category yes;
        print-severity yes;
        severity info;
    };
    category default { general_log; };
    category general { general_log; };
};

zone "." IN {
    type hint;
    file "named.ca";
};

zone "example.com" {
    type master;
    file "db.example.com";
};
```

Next, you need to create a `named` folder in the working directory and create a new Zone file under it, in this case it is `/var/service/bind/named/db.example.com` and write the following configuration.

> Note that the SOA and NS records here need to be changed to your actual Name Server domain name.

```
$TTL 600
@         IN  SOA    ns1.dnomd343.top. admin.example.com. (
                     2023121300 ; serial number
                     3600       ; refresh interval
                     1200       ; retry interval
                     1209600    ; expiry period
                     600        ; negative TTL
)

@         IN  NS     ns1.dnomd343.top.
@         IN  NS     ns2.dnomd343.top.

@         IN  A      1.2.3.4
www       IN  A      1.2.3.4
```

Now, we can start running our service and use the following command to pull up the container.

```bash
docker run -d --network host \
  --volume /var/service/bind/named/:/var/bind/ \
  --volume /var/service/bind/log/:/var/log/bind/ \
  --volume /var/service/bind/named.conf:/etc/bind/named.conf \
  --name bind dnomd343/bind -f
```

You may have noticed that the `-f` parameter is added here, which prevents the container from using the default `-g` parameter to print logs to the standard output, because we need to let Bind store the logs in the `log` folder.

If you find that the container is not running correctly, you need to execute the `docker logs -f bind` command. If nothing unexpected happens, you can find the specific cause of the error. When everything is working fine, use the `dig` command to query.

```bash
$ dig +short @127.0.0.1 www.example.com
1.2.3.4
```

After running, the working directory will produce the following files and folders. The `log` directory stores log files for services and queries. You can configure them in the `logging` section of the configuration file. The working data of the DNS server will be stored in the `named` directory. `named.ca` will be automatically created at startup. It contains the IP address information of the DNS root servers. It should be noted that this file is released with the image and will not be automatically updated, and the root server addresses may change (usually in years). If you use Bind as a recursive DNS server, it is recommended to pull the latest image, or update [this file](https://www.internic.net/domain/named.root) manually.

> The `named.ca` file is only created if it does not exist. If you change this file, it will not be overwritten when the container is restarted or re-created.

```bash
.
├── log
│   ├── general.log
│   └── query.log
├── named
│   ├── db.example.com
│   └── named.ca
└── named.conf
```

Another more elegant way is to use `docker-compose` to deploy. You need to create `compose.yml` in the working directory and write the following configuration. It also maps the time zone information to the container and makes Bind to print out the correct time in log.

```yml
version: '3'
services:
  bind:
    container_name: bind
    image: dnomd343/bind
    network_mode: host
    restart: always
    command: -f
    volumes:
      - ./named/:/var/bind/
      - ./log/:/var/log/bind/
      - ./named.conf:/etc/bind/named.conf:ro
      - /etc/localtime:/etc/localtime:ro
      - /etc/timezone:/etc/timezone:ro
```

Use the following command to pull up the service, and be careful to use `docker rm -f bind` to remove the previous container.

```bash
$ docker-compose up -d
Creating bind ... done
```

## Tool Commands

The entire Bind tool chain has been built into the container, such as `dig`, `nsupdate`, etc., which are used for various functions related to DNS and Bind. You can directly specify the command and parameters at run time, such as the following commands.

```bash
$ docker run --rm -it dnomd343/bind dig +short 343.re NS
ns2.dnomd343.top.
ns1.dnomd343.top.
```

```bash
$ docker run --rm -it dnomd343/bind tsig-keygen
key "tsig-key" {
        algorithm hmac-sha256;
        secret "N7p4CllYmEut55ijnnDxHGpNE8gmdNZBx8qPr1/fQGk=";
};
```

Currently the following 7 tools are supported.

+ `dig`
+ `rndc`
+ `nslookup`
+ `nsupdate`
+ `tsig-keygen`
+ `ddns-confgen`
+ `rndc-confgen`

## Advanced

For the DNSSEC feature, the root key has been built into the container. The current KSK number is `20326`. If you need to replace this file, please map the key information to `/etc/bind/bind.keys`. The Bind service will automatically load this file when it is started.

The container does not enable the rndc function by default. If you need to enable it, please map the rndc key file to `/etc/bind/rndc.conf`. The Bind service will automatically load the key and listen on port 953. You can set the rndc functionality by changing the `controls` section of the configuration file.

## Image Build

Use the following command to quickly build an image locally.

```bash
$ docker build -t bind https://github.com/dnomd343/bind-docker.git
```

Use the following command to build multi-architecture supporting images and push them to the Docker Hub service.

```bash
$ docker buildx build -t dnomd343/bind \
  --platform 'linux/amd64,linux/386,linux/arm64,linux/arm/v7' \
  https://github.com/dnomd343/bind-docker.git --push
```

## License

MIT ©2023 [@dnomd343](https://github.com/dnomd343)
