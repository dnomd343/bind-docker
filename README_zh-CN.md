# Bind Docker

> 基于 Alpine 构建的轻量 DNS 解析服务器。

## 快速开始

使用以下命令查看 Bind 的版本、功能支持和编译信息。

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

[默认配置](./named.conf)让 Bind 监听在本地 53 端口作为递归DNS服务器，下面是它的示例。

```bash
$ docker run --rm --network host dnomd343/bind
13-Dec-2023 23:04:35.370 starting BIND 9.18.19 (Extended Support Version) <id:c78cd36>
...
```

您可以在另一个终端中输入以下命令，验证 DNS 服务器的工作状态。

```bash
$ dig +short @127.0.0.1 google.com
172.217.163.46
```

在更多情况下，Bind 被作为权威 DNS 服务器。在部署时，您应当选择一个工作目录，例如 `/var/service/bind/` ，在它下面创建 `named.conf` 配置文件。一个简单的例子如下，它提供了对 `example.com` 域名的权威解析，同时将日志记录到文件中。

> 绝大多数时候，同时提供递归解析和权威解析是一个糟糕的主意，即使 Bind 可以做到这一点。

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

接着，您需要在工作目录下创建一个 `named` 文件夹，并在它下面新建 Zone 文件，在这里它是 `/var/service/bind/named/db.example.com` ，写入以下配置。

> 注意，这里的 SOA 和 NS 记录需要更改为您的实际名称服务域名。

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

现在，可以开始运行我们的服务了，使用下面的命令拉起容器。

```bash
docker run -d --network host \
  --volume /var/service/bind/named/:/var/bind/ \
  --volume /var/service/bind/log/:/var/log/bind/ \
  --volume /var/service/bind/named.conf:/etc/bind/named.conf \
  --name bind dnomd343/bind -f
```

您可能已经注意到了，这里加入了 `-f` 参数，它避免容器使用默认的 `-g` 参数将日志打印到标准输出上，因为我们需要让 Bind 将日志存入 `log` 文件夹中。

如果您发现容器没有正确运行，您需要执行 `docker logs -f bind` 命令，没有意外的话，您可以发现具体的错误原因。当一切工作正常的时候，使用 `dig` 命令查询。

```bash
$ dig +short @127.0.0.1 www.example.com
1.2.3.4
```

在运行后，工作目录会产生以下文件和文件夹，`log` 目录存储服务和查询的日志文件，您可以在配置文件的 `logging` 部分配置它们。DNS服务器的工作数据将存储在 `named` 目录下，`named.ca` 会在启动时自动创建，它包含根服务器的地址信息。需要注意的是，这个文件随镜像发布，并不会自动更新，而根服务器地址是有可能变动的（一般以年为单位），如果您将 Bind 作为递归 DNS 服务器，建议拉取最新镜像，或手动更新[这个文件](https://www.internic.net/domain/named.root)。

> `named.ca` 文件仅在不存在时创建，如果您更改了这个文件，容器重启或重新创建时并不会覆盖它。

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

另一个更优雅的方式是使用 `docker-compose` 部署，您需要在工作目录下创建 `compose.yml` ，写入以下配置，它还把时区信息映射到容器中，可以让 Bind 打印出正确时间的日志。

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

使用以下命令拉起服务，注意使用 `docker rm -f bind` 移除之前的容器。

```bash
$ docker-compose up -d
Creating bind ... done
```

## 工具命令

容器中已内置整套 Bind 工具链，例如 `dig` 、`nsupdate` 等，用于 DNS 与 Bind 相关的各类功能。您可以在运行时直接指定命令及参数，例如下面的命令。

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

目前支持的工具有以下 7 个。

+ `dig`
+ `rndc`
+ `nslookup`
+ `nsupdate`
+ `tsig-keygen`
+ `ddns-confgen`
+ `rndc-confgen`

## 高级功能

对于 DNSSEC 功能，容器中已内置了根密钥，当前 KSK 编号为 `20326` ，如果您需要替换该文件，请把密钥信息映射到 `/etc/bind/bind.keys` ，Bind 服务在开启时将自动载入该文件。

容器默认未开启 rndc 功能，如果您需要启用，请将 rndc 密钥文件映射到 `/etc/bind/rndc.conf` ，Bind 服务将自动载入该密钥，并自动监听在 953 端口上，您可以更改配置文件的 `controls` 部分设置 rndc 功能。

## 镜像构建

使用以下命令在本地快速构建镜像。

```bash
$ docker build -t bind https://github.com/dnomd343/bind-docker.git
```

使用以下命令构建多架构支持镜像，并推送至 Docker Hub 服务。

```bash
$ docker buildx build -t dnomd343/bind \
  --platform 'linux/amd64,linux/386,linux/arm64,linux/arm/v7' \
  https://github.com/dnomd343/bind-docker.git --push
```

## 许可证

MIT ©2023 [@dnomd343](https://github.com/dnomd343)
