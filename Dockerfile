FROM ubuntu:latest AS ffmpeg

RUN apt-get clean && cd /var/lib/apt && rm -r lists && mkdir -p lists/partial && apt-get clean && apt-get update && apt-get -y upgrade

RUN \
	 apt-get update && apt-get -y upgrade &&  \
	 apt-get install -y --no-install-recommends curl build-essential libva-dev vainfo git ca-certificates ninja-build meson libmfx-dev
WORKDIR /

RUN git clone https://github.com/jasworks/ffmpeg-build-script.git \
  && cd ffmpeg-build-script && SKIPINSTALL=yes ./build-ffmpeg --build --enable-gpl-and-non-free --latest 

FROM ubuntu:latest

LABEL org.opencontainers.image.title="x86_64 Optimized Homebridge in Docker"
LABEL org.opencontainers.image.description="x86_64 FFMPEG enabled Homebridge Docker Image"
LABEL org.opencontainers.image.authors="jasworks"
LABEL org.opencontainers.image.url="https://github.com/jasworks/docker-homebridge"
LABEL org.opencontainers.image.licenses="GPL-3.0"

# update to latest releases prior to release


ENV S6_OVERLAY_VERSION=3.1.5.0 \
 S6_CMD_WAIT_FOR_SERVICES_MAXTIME=0 \
 S6_KEEP_ENV=1 \
 ENABLE_AVAHI=1 \
 LANG=C.UTF-8 \
 USER=homebridge \
 HOMEBRIDGE_APT_PACKAGE=1 \
 UIX_CUSTOM_PLUGIN_PATH="/var/lib/homebridge/node_modules" \
 PATH="/opt/homebridge/bin:/var/lib/homebridge/node_modules/.bin:$PATH" \
 HOME="/homebridge/lib" \
 npm_config_prefix=/opt/homebridge

RUN apt-get clean && cd /var/lib/apt && rm -r lists && mkdir -p lists/partial && apt-get clean && apt-get update && apt-get -y upgrade

RUN set -x \
  && sed -i -e's/ main/ main contrib non-free/g' /etc/apt/sources.list \
  && DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get update \
  && DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get -y upgrade \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends curl wget tzdata locales psmisc procps iputils-ping logrotate \
    libatomic1 apt-transport-https apt-utils jq openssl sudo net-tools ca-certificates \
    git make g++ libnss-mdns libavahi-compat-libdnssd-dev avahi-daemon \
    libva2 libmfx1 intel-media-va-driver-non-free xz-utils python3 python3-venv python3-pip python3-setuptools \
    vim libva-drm2 \
    python3-dateutil python3-urllib3 python3-requests expect openssh-client \
  && locale-gen en_US.UTF-8 \
  && ln -snf /usr/share/zoneinfo/Etc/GMT /etc/localtime && echo Etc/GMT > /etc/timezone \
  && chmod 4755 /bin/ping

RUN pip install --break-system-packages tzupdate
  
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

#RUN case "$(uname -m)" in \
#    x86_64) FFMPEG_ARCH='x86_64';; \
#    *) echo "unsupported architecture"; exit 1 ;; \
#    esac \
#  && set -x \
#  && curl -Lfs https://github.com/homebridge/ffmpeg-for-homebridge/releases/download/${FFMPEG_VERSION}/ffmpeg-debian-${FFMPEG_ARCH}.tar.gz | tar xzf - -C / --no-same-owner

COPY --from=ffmpeg /ffmpeg-build-script/workspace/bin/ffmpeg /usr/bin/ffmpeg

ENV HOMEBRIDGE_PKG_VERSION=v1.2.1 \
  FFMPEG_VERSION=v2.1.1

RUN apt-get install -y --no-install-recommends python3-dev \
  && case "$(uname -m)" in \
    x86_64) DEB_ARCH='amd64';; \
    *) echo "unsupported architecture"; exit 1 ;; \
    esac \
  && set -x \
  && curl -sSLf -o /homebridge_${HOMEBRIDGE_PKG_VERSION}.deb https://github.com/homebridge/homebridge-apt-pkg/releases/download/${HOMEBRIDGE_PKG_VERSION}/homebridge_${HOMEBRIDGE_PKG_VERSION}_${DEB_ARCH}.deb \
  && dpkg -i /homebridge_${HOMEBRIDGE_PKG_VERSION}.deb \
  && rm -rf /homebridge_${HOMEBRIDGE_PKG_VERSION}.deb \
  && rm -rf /var/lib/homebridge

COPY rootfs /

RUN set -x &&  groupmod -g 5002 homebridge && usermod -d /homebridge/lib -u 5002 -g 5002 homebridge && groupmod -g 5003 messagebus && groupmod -g 5004 avahi && usermod -u 5003 -g 5003 messagebus && usermod -u 5004 -g 5004 avahi && chown -R homebridge:homebridge /opt/homebridge/lib/node_modules

EXPOSE 8581/tcp
VOLUME /homebridge
WORKDIR /homebridge


RUN set -x \
  &&  apt-get -y autoremove && apt-get clean \
  && rm -rf /tmp/* /var/lib/apt/lists/* /var/tmp/* \
  && rm -rf /etc/cron.daily/apt-compat /etc/cron.daily/dpkg /etc/cron.daily/passwd /etc/cron.daily/exim4-base

ENTRYPOINT [ "/init" ]
