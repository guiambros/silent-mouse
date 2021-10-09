#!/bin/bash
set -e

# This script patches your upower / upowerd to ignore low battery notifications from 
# a wireless mouse (and optionally keyboard) device.
#
# By default it disables only mouse; if ydesired run with "--keyboard" if you
# also disable keyboard notifications.
#
# See https://wrgms.com/disable-mouse-battery-low-spam-notification/
# for details


OS=`awk -F= '/^ID=/{print $2}' /etc/os-release`
OS_VER=`awk -F= '/^VERSION_ID=/{print $2}' /etc/os-release | cut -d "\"" -f 2`
OS_VER_MAJOR=`echo ${OS_VER} | awk -F. '{print $1}'`
UPOWER_ORIG_VER=`upower --version`

# Check distro and upower version in use, and install required libraries
#
echo
echo "---------------------------------------------------------------------------"
upower --version
echo "---------------------------------------------------------------------------"
echo

set_legacy_upowerd() {
    UPOWER_BRANCH="UPOWER_0_99_12"
    PATCH_NAME="up-device-0_99_12.patch"
}

set_current_upowerd() {
    UPOWER_BRANCH="UPOWER_0_99_13"
    PATCH_NAME="up-device-0_99_13.patch"
}

if [ "$OS" == "manjaro" ]
then
    echo "-- Manjaro detected; installing required libraries"
    sudo pacman -Syu --noconfirm base-devel gtk-doc gobject-introspection git libtool meson autoconf automake make 
    PATH_UPOWERD="/usr/lib"
    PATH_UPOWER="/usr/bin"
    set_current_upowerd

elif [ "$OS" == "ubuntu" ]
then
    echo "-- Ubuntu detected; installing required libraries"
    sudo apt install -y git gtk-doc-tools gobject-introspection libgudev-1.0-dev libusb-1.0-0-dev autoconf libtool autopoint
    PATH_UPOWER="/usr/bin"

    if [ "${OS_VER}" == "20.10" ]
    then
        echo "--- Ubuntu version 20.10 (Groovy Gorilla) detected"
        PATH_UPOWERD="/usr/libexec"
        set_legacy_upowerd

    elif [ ${OS_VER_MAJOR} -le 20 ]
    then
        echo "--- Ubuntu version 20.04 or lower detected"
        PATH_UPOWERD="/usr/lib/upower"
        set_legacy_upowerd

    elif [ ${OS_VER_MAJOR} -ge 21 ]
    then
        echo "--- Ubuntu version 21 or above detected"
        PATH_UPOWERD="/usr/libexec"
        set_legacy_upowerd

    # TODO: test with Ubuntu 21.10, and add configuration here if needed
    fi

elif [ "$OS" == "debian" ]
then
    echo "-- Debian detected; installing required libraries"
    sudo apt install -y git gtk-doc-tools gobject-introspection libgudev-1.0-dev libusb-1.0-0-dev autoconf libtool autopoint
    set_legacy_upowerd
    if [ ${OS_VER_MAJOR} -le 10 ]
    then
        PATH_UPOWERD="/usr/lib/upower"
        PATH_UPOWER="/usr/bin"
    elif [ ${OS_VER_MAJOR} -ge 11 ]
    then
        PATH_UPOWERD="/usr/libexec"
        PATH_UPOWER="/usr/bin"
    else
        echo "-- Unknown Debian system [${OS_VER} / ${OS_VER_MAJOR}]."
        exit 1    
    fi
else
    echo "-- Unknown system; this script was only tested on ubuntu and manjaro."
    exit 1
fi
echo "---------------------------------------------------------------------------"
echo


# Download upowerd source and selects the proper branch
#
git clone https://gitlab.freedesktop.org/upower/upower

if [ -z ${UPOWER_BRANCH} ]
then
    echo "-- Using latest master branch (untested; may not work)"
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
cp ../../${PATCH_NAME} .
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
echo "upower version AFTER the update (likely same version, or a minor number above):"
upower --version
echo "-------------------------------------"
