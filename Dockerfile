FROM debian:11-slim

LABEL org.opencontainers.image.title="x86_64 Optimized Homebridge in Docker"
LABEL org.opencontainers.image.description="x86_64 FFMPEG enabled Homebridge Docker Image"
LABEL org.opencontainers.image.authors="jasworks"
LABEL org.opencontainers.image.url="https://github.com/jasworks/docker-homebridge"
LABEL org.opencontainers.image.licenses="GPL-3.0"

ENV S6_OVERLAY_VERSION=3.1.1.2 \
 S6_CMD_WAIT_FOR_SERVICES_MAXTIME=0 \
 S6_KEEP_ENV=1 \
 ENABLE_AVAHI=1 \
 USER=root \
 HOMEBRIDGE_APT_PACKAGE=1 \
 UIX_CUSTOM_PLUGIN_PATH="/var/lib/homebridge/node_modules" \
 PATH="/opt/homebridge/bin:/var/lib/homebridge/node_modules/.bin:$PATH" \
 HOME="/homebridge/lib" \
 npm_config_prefix=/opt/homebridge


RUN sed -i -e's/ main/ main contrib non-free/g' /etc/apt/sources.list

RUN set -x \
  && apt-get update \
  && apt-get install -y --no-install-recommends curl wget tzdata locales psmisc procps iputils-ping logrotate \
    libatomic1 apt-transport-https apt-utils jq openssl sudo nano net-tools ca-certificates \
    git make g++ libnss-mdns libavahi-compat-libdnssd-dev \
    vainfo libva2 libva-dev intel-media-va-driver-non-free xz-utils python3 python3-pip vim \
    build-essential curl \
  && locale-gen en_US.UTF-8 \
  && ln -snf /usr/share/zoneinfo/Etc/GMT /etc/localtime && echo Etc/GMT > /etc/timezone

RUN set -x \ 
  && pip3 install tzupdate argparse psa-car-controller python-dateutil dnspython urllib3

RUN set -x \
  && chmod 4755 /bin/ping

  
RUN case "$(uname -m)" in \
    x86_64) S6_ARCH='x86_64';; \
    *) echo "unsupported architecture"; exit 1 ;; \
    esac \
  && cd /tmp \
  && set -x \
  && curl -SLOf https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz \
  && tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz \
  && curl -SLOf  https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-${S6_ARCH}.tar.xz \
  && tar -C / -Jxpf /tmp/s6-overlay-${S6_ARCH}.tar.xz

RUN case "$(uname -m)" in \
    x86_64) FFMPEG_ARCH='x86_64';; \
    *) echo "unsupported architecture"; exit 1 ;; \
    esac \
  && set -x \
  && curl -Lfs https://github.com/homebridge/ffmpeg-for-homebridge/releases/download/v0.1.0/ffmpeg-debian-${FFMPEG_ARCH}.tar.gz | tar xzf - -C / --no-same-owner

ENV HOMEBRIDGE_PKG_VERSION=1.0.33

RUN case "$(uname -m)" in \
    x86_64) DEB_ARCH='amd64';; \
    *) echo "unsupported architecture"; exit 1 ;; \
    esac \
  && set -x \
  && curl -sSLf -o /homebridge_${HOMEBRIDGE_PKG_VERSION}.deb https://github.com/homebridge/homebridge-apt-pkg/releases/download/${HOMEBRIDGE_PKG_VERSION}/homebridge_${HOMEBRIDGE_PKG_VERSION}_${DEB_ARCH}.deb \
  && dpkg -i /homebridge_${HOMEBRIDGE_PKG_VERSION}.deb \
  && rm -rf /homebridge_${HOMEBRIDGE_PKG_VERSION}.deb \
  && rm -rf /var/lib/homebridge

COPY rootfs /

RUN usermod -d /homebridge/lib homebridge

RUN mkdir /ffmpeg-build && cd /ffmpeg-build && git clone https://github.com/markus-perl/ffmpeg-build-script.git \
  && cd ffmpeg-build-script && SKIPINSTALL=yes ./build-ffmpeg --build --enable-gpl-and-non-free --latest && cp workspace/bin/ffmpeg /usr/bin/ffmpeg \
  && cd / && rm -fr ffmpeg-build

RUN apt-get remove -y build-essential libva-dev && apt-get -y autoremove && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/* \
  && rm -rf /etc/cron.daily/apt-compat /etc/cron.daily/dpkg /etc/cron.daily/passwd /etc/cron.daily/exim4-base

EXPOSE 8581/tcp
VOLUME /homebridge
WORKDIR /homebridge

ENTRYPOINT [ "/init" ]
