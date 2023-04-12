FROM debian:11-slim AS ffmpeg

RUN apt-get update && apt-get install -y --no-install-recommends curl build-essential libva-dev vainfo git ca-certificates
WORKDIR /

RUN git clone https://github.com/jasworks/ffmpeg-build-script.git \
  && cd ffmpeg-build-script && SKIPINSTALL=yes ./build-ffmpeg --build --enable-gpl-and-non-free --latest 

FROM debian:11-slim

LABEL org.opencontainers.image.title="x86_64 Optimized Homebridge in Docker"
LABEL org.opencontainers.image.description="x86_64 FFMPEG enabled Homebridge Docker Image"
LABEL org.opencontainers.image.authors="jasworks"
LABEL org.opencontainers.image.url="https://github.com/jasworks/docker-homebridge"
LABEL org.opencontainers.image.licenses="GPL-3.0"

ENV S6_OVERLAY_VERSION=3.1.1.2 \
 S6_CMD_WAIT_FOR_SERVICES_MAXTIME=0 \
 S6_KEEP_ENV=1 \
 LANG=C.UTF-8 \
 USER=homebridge \
 HOMEBRIDGE_APT_PACKAGE=1 \
 UIX_CUSTOM_PLUGIN_PATH="/var/lib/homebridge/node_modules" \
 PATH="/opt/homebridge/bin:/var/lib/homebridge/node_modules/.bin:$PATH" \
 HOME="/homebridge/lib" \
 npm_config_prefix=/opt/homebridge


RUN sed -i -e's/ main/ main contrib non-free/g' /etc/apt/sources.list

RUN set -x \
  && apt-get update \
  && apt-get install -y --no-install-recommends curl wget tzdata locales psmisc procps iputils-ping logrotate \
    libatomic1 apt-transport-https apt-utils jq openssl sudo net-tools ca-certificates \
    git make g++ \
    libva2 intel-media-va-driver-non-free xz-utils python3 python3-pip python3-setuptools vim libva-drm2 \
  && locale-gen en_US.UTF-8 \
  && ln -snf /usr/share/zoneinfo/Etc/GMT /etc/localtime && echo Etc/GMT > /etc/timezone

RUN set -x \ 
  && pip3 install tzupdate argparse python-dateutil urllib3 requests && pip3 cache purge

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

COPY --from=ffmpeg /ffmpeg-build-script/workspace/bin/ffmpeg /usr/bin/ffmpeg
RUN groupmod -g 5002 homebridge
RUN usermod -d /homebridge/lib -u 5002 -g 5002 homebridge


RUN apt-get -y autoremove && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/* \
  && rm -rf /etc/cron.daily/apt-compat /etc/cron.daily/dpkg /etc/cron.daily/passwd /etc/cron.daily/exim4-base

EXPOSE 8581/tcp
VOLUME /homebridge
WORKDIR /homebridge

ENTRYPOINT [ "/init" ]
