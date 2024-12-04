ARG CONTAINER=ghcr.io/openwrt/sdk
ARG ARCH=x86_64

FROM ${CONTAINER}:${ARCH}

LABEL "com.github.actions.name"="OpenWrt Packager"
LABEL "repository"="https://github.com/gretel/openwrt-packager"
LABEL "maintainer"="gretel"

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]