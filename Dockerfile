FROM debian:latest

MAINTAINER Geoff Johnson <geoff.jay@gmail.com>

RUN apt-get update
RUN apt-get install -y \
    libgda-5.0-dev \
    libgee-0.8-dev \
    libgirepository1.0-dev \
    libglib2.0-dev \
    libgphoto2-dev \
    libgtop2-dev \
    libjson-glib-dev \
    libsoup2.4-dev \
    libssl-dev \
    libxml2-utils \
    bison \
    flex \
    gettext \
    git \
    python3-pip \
    unzip \
    valac
RUN rm -rf /var/lib/apt/lists/*

# Meson and Ninja
RUN pip3 install meson ninja

WORKDIR /icd
ADD . .
RUN meson setup --prefix=/usr --sysconfdir=/etc --buildtype=release _build
RUN meson configure -Denable-tests=false _build
RUN meson compile -C _build && meson install -C _build

CMD ["/usr/bin/icd", "--config", "/etc/icd/icd.conf"]

EXPOSE 3003
