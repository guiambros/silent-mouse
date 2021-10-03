#!/bin/bash
set -e

# See https://wrgms.com/disable-mouse-battery-low-spam-notification/
# for instructions on how to use it
#
# TL;DR: run with "--keyboard" if you want to patch upower to ignore both
# mice and keyboard notifications (by default it ignores only mice)

# Check distro and upower version in use, and install required libraries
#
echo
echo "---------------------------------------------------------------------------"
upower --version
echo "---------------------------------------------------------------------------"
echo

UPOWER_ORIG_VER=`upower --version`
OS=`awk -F= '/^ID=/{print $2}' /etc/os-release`
OS_VER=`awk -F= '/^VERSION_ID=/{print $2}' /etc/os-release | cut -d "\"" -f 2`
OS_VER_MAJOR=`echo ${OS_VER} | awk -F. '{print $1}'`

PATCH_LEGACY_URL="https://gist.githubusercontent.com/guiambros/f2bf07f1cc085f8f0b0a9e04c0a767b4/raw/73efac967c8fc9539802e7aa8eeba5492f8ae3b1/up-device-legacy.patch"
PATCH_CURRENT_URL="https://gist.githubusercontent.com/guiambros/f2bf07f1cc085f8f0b0a9e04c0a767b4/raw/73efac967c8fc9539802e7aa8eeba5492f8ae3b1/up-device-current-0.99.12p.patch"
PATCH_NAME="up-device.patch"
PATCH_URL=${PATCH_CURRENT_URL}

if [ "$OS" == "manjaro" ]
then
    echo "-- Manjaro detected; installing required libraries"
    sudo pacman -S base-devel gtk-doc gobject-introspection git
    PATH_UPOWERD="/usr/lib"
    PATH_UPOWER="/usr/bin"

elif [ "$OS" == "ubuntu" ]
then
    echo "-- Ubuntu detected; installing required libraries"
    sudo apt install -y git gtk-doc-tools gobject-introspection libgudev-1.0-dev libusb-1.0-0-dev autoconf libtool autopoint
    PATH_UPOWER="/usr/bin"

    if [ "${OS_VER}" == "20.10" ]
    then
        echo "--- Ubuntu version 20.10 (Groovy Gorilla) detected"
        PATH_UPOWERD="/usr/libexec"
        UPOWER_BRANCH="UPOWER_0_99_11"
        PATCH_URL=${PATCH_LEGACY_URL}

    elif [ ${OS_VER_MAJOR} -ge 21 ]
    then
        echo "--- Ubuntu version 21 or above detected"
        PATH_UPOWERD="/usr/libexec"
        UPOWER_BRANCH="UPOWER_0_99_11"
        PATCH_URL=${PATCH_LEGACY_URL}

    elif [ ${OS_VER_MAJOR} -le 20 ]
    then
        echo "--- Ubuntu version 20.04 or lower detected"
        PATH_UPOWERD="/usr/lib/upower"
        UPOWER_BRANCH="UPOWER_0_99_11"
        PATCH_URL=${PATCH_LEGACY_URL}
    fi
else
    echo "-- Unknown system; this script was only tested on ubuntu and manjaro."
    exit 1
fi
echo "---------------------------------------------------------------------------"
echo


# Download upowerd source and selects the proper branch
#
cd ~
git clone https://gitlab.freedesktop.org/upower/upower

if [ -z ${UPOWER_BRANCH} ]
then
    echo "-- Using latest master branch (0.99.12 or above)"
    cd upower/src
else
    echo "-- Using branch ${UPOWER_BRANCH} (latest compatible with your distro)"
    cd upower
    git fetch --all --tags
    git checkout tags/${UPOWER_BRANCH} -b ${UPOWER_BRANCH}
    cd src
fi


# Download and patch upowerd
#
wget ${PATCH_URL} -O ${PATCH_NAME}
if [ "$1" == "-keyboard" ] || [ "$1" == "--keyboard" ]; then
        SILENCE_KEYBOARD="+     if ((type == UP_DEVICE_KIND_MOUSE || type == UP_DEVICE_KIND_KEYBOARD) && state == UP_DEVICE_STATE_DISCHARGING) {"
        sed -i "/UP_DEVICE_KIND_MOUSE/c${SILENCE_KEYBOARD}" ${PATCH_NAME}
fi
patch -F 1 < ${PATCH_NAME}


# Compile upowerd
#
cd ..
./autogen.sh
./configure
make


# Install upowerd
#
CUR_DATETIME=`date +%Y-%m-%d-%H%M%S`

pushd .
cd src/.libs
strip upowerd
sudo chown root.root upowerd
sudo mv upowerd ${PATH_UPOWERD}/upowerd-silent
cd ${PATH_UPOWERD}
sudo mv upowerd upowerd-original-${CUR_DATETIME}
sudo ln -s upowerd-silent upowerd
popd


# Install upower
#
pushd .
cd tools/.libs
strip upower
sudo chown root.root upower
sudo mv upower ${PATH_UPOWER}/upower-silent
cd ${PATH_UPOWER}
sudo mv upower upower-original-${CUR_DATETIME}
sudo ln -s upower-silent upower
popd


# Restart upowerd
#
sudo systemctl restart upower


# Compare versions before/after (they will likely be different, but it depends on what your distro packages by default)
#
echo
echo "---------------------------------------------------------------------------"
echo "upower version BEFORE the update:"
echo "${UPOWER_ORIG_VER}"
echo "-------------------------------------"
echo "upower version AFTER the update:"
upower --version
