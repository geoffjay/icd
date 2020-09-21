# Image Capture Service

[WIP]: this project is in an unfinished state, some of the goals of the project
were not implemented. The API generated was what was being worked towards but
time didn't allow for all to be completed and was used when it was _good enough_.
The [router](https://github.com/geoffjay/icd/blob/master/src/router.vala) file
has what routes were actually implemented.

Use libgphoto2 to capture images using compatible cameras and expose certain
functionality over a REST API as a service.

The API is generated from RAML and can be viewed [here](doc/api/API.md).

## Setup

### Fedora

```sh
sudo dnf install python-pip3 cmake valac flex bison gettext \
    libgphoto2-devel libgee-devel json-glib-devel libgda-devel libgda-sqlite \
    libgda-mysql libgda-postgres libsoup2.4-devel libxml2-devel openssl-devel \
    libxml2-devel libgtop2-devel glib2-devel meson ninja-build git
```

### Debian/Ubuntu

```sh
sudo apt-get install python3-pip cmake valac flex bison gettext \
    libgda-5.0-dev libgee-0.8-dev libgirepository1.0-dev libglib2.0-dev \
    libgphoto2-dev libjson-glib-dev libsoup2.4-dev libssl-dev libxml2-utils \
    libgtop2-dev libgudev-1.0-dev meson ninja-build git
```

### Common

A couple of the build dependencies are added to this repository as `meson`
subprojects and during testing it isn't necessary to install them.

```sh
sudo pip3 install scikit-build
git clone https://gitlab.gnome.org/GNOME/template-glib
cd template-glib
meson --prefix=/usr _build
ninja -C _build
sudo ninja -C _build install
cd ..
git clone https://github.com/valum-framework/valum.git
cd valum
meson --prefix=/usr --buildtype=release _build
ninja -C _build
sudo ninja -C _build install
```

### Cameras

USB cameras need to have the permissions changed, possibly just if the settings
will be changed. The example `udev` rule below is for a Canon camera that was
used during development.

```sh
echo 'SUBSYSTEM=="usb", ATTR{idVendor}=="04a9", ATTR{idProduct}=="3218", MODE="0666"' | \
    sudo tee /etc/udev/rules.d/50-canon.rules >/dev/null
sudo udevadm control --reload
sudo udevadm trigger
```

## Build/Install

```sh
git clone https://github.com/geoffjay/icd.git icd
cd icd
# During development
meson _build
ninja -C _build
# or
# For deployment
meson --prefix=/usr --sysconfdir=/etc --buildtype=plain _build
meson configure -Denable-systemd=true _build
ninja -C _build
sudo ninja -C _build install
```

### Post Install

Valum doesn't set the library path for the VSGI `.so` files that are needed so
this is necessary to execute `icd` once installed.

#### Fedora / Ubuntu

```sh
echo /usr/lib64/vsgi-0.4/servers | \
  sudo tee /etc/ld.so.conf.d/valum-x86_64.conf >/dev/null
sudo ldconfig
```

#### Raspberry Pi

```sh
echo /usr/lib/arm-linux-gnueabihf/vsgi-0.4/servers | \
  sudo tee /etc/ld.so.conf.d/valum-x86_64.conf >/dev/null
sudo ldconfig
```

## Ansible

This method is what's currently used to deploy on a RaspberryPi, it hasn't been tested anywhere else.

```sh
sudo apt-get install python3-pip git
python3 -m pip install --user ansible cryptography
echo -e '\nPATH=$HOME/.local/bin:$PATH' >> ~/.bashrc
. ~/.bashrc
sudo update-alternatives --install /usr/bin/python python /usr/bin/python3 20
sudo update-alternatives --install /usr/bin/python python /usr/bin/python2 10
sudo update-alternatives --config python
# pick python3
git clone <not sure yet> playbook # FIXME
cd playbook
ansible-playbook icd.yml
```

## Docker

Build and run the application using `Docker`.

```sh
docker build -t icd .
docker run --rm -it --privileged -v /dev/bus/usb:/dev/bus/usb -p 3003:3003 icd
```

Or with Docker Compose.

```sh
docker-compose up
```

This will put the database for the application in `/usr/share/icd`. This can be
changed by editing the configuration file in `data/config` to point at a
different volume that is mapped in a similar way as is done with the USB bus.

## Running

### Configuration

#### Properties

| Group    | Name        | Data Type    | Description                |
| -------- | ----------- | ------------ | -------------------------- |
| general  | address     | string       | Service IP address to use  |
| general  | port        | int          | Service port number to use |
| database | reset       | boolean      | Flag to reset the database |
| database | host        | string       | Database host IP address   |
| database | port        | int          | Database port number       |
| database | name        | string       | Database name              |
| database | provider    | string       | Database provider          |
| database | username    | string       | Database user name         |
| database | password    | string       | Database password          |
| database | dsn         | string       | Data service name          |

#### SQLite Sample

```sh
[general]
address = 127.0.0.1
port = 3003

[database]
reset = false
name = icd
provider = SQLite
path = /usr/share/icd/
```
