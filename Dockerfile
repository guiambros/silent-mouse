# Dockerfile
#FROM manjarolinux/base:latest
#FROM debian:12
#FROM ubuntu:20.04
ARG DISTRO_VERSION=ubuntu:latest
FROM ${DISTRO_VERSION}

# Install dependencies or perform other setup tasks
RUN apt-get update && \
  DEBIAN_FRONTEND=noninteractive \
  apt-get install -y --no-install-recommends \
  tzdata ca-certificates systemd systemd-sysv dbus \
  dbus-user-session upower bash git sudo lsb-release patch
COPY docker-entrypoint.sh /
ENTRYPOINT ["/docker-entrypoint.sh"]
