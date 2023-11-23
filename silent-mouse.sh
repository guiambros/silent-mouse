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
DEBUG_VARS="false"
BUILD_SYSTEM="cmake" # use the classic cmake or the newer mason (in more recent distros)

# Check distro and upower version in use, and install required libraries
echo
echo "---------------------------------------------------------------------------"
upower --version
echo "---------------------------------------------------------------------------"
echo

declare -A tested_versions

# list of all versions tested
PATH_UPOWER="/usr/bin"
PATH_UPOWERD="/usr/libexec"
PATCH_LEGACY="up-device-0_99_11.patch"
PATCH_AFTER_v13="up-device-0_99_13.patch"
tested_versions["ubuntu_16.04"]="BRANCH='UPOWER_0_99_4' PATCH=${PATCH_LEGACY} PATH_UPOWERD='/usr/lib/upower'"
tested_versions["ubuntu_18.04"]="BRANCH='UPOWER_0_99_7' PATCH=${PATCH_LEGACY} PATH_UPOWERD='/usr/lib/upower'"
tested_versions["ubuntu_20.04"]="BRANCH='UPOWER_0_99_11' PATCH=${PATCH_LEGACY} PATH_UPOWERD='/usr/lib/upower'"
tested_versions["ubuntu_22.04"]="BRANCH='v0.99.17' PATCH=${PATCH_AFTER_v13} BUILD_SYSTEM='meson'"
tested_versions["ubuntu_23.10"]="BRANCH='v1.90.2' PATCH=${PATCH_AFTER_v13} BUILD_SYSTEM='meson'"
tested_versions["debian_10"]="BRANCH='UPOWER_0_99_10' PATCH=${PATCH_LEGACY} PATH_UPOWERD='/usr/lib/upower'"
tested_versions["debian_11"]="BRANCH='UPOWER_0_99_11' PATCH=${PATCH_AFTER_v13}"
tested_versions["debian_12"]="BRANCH='v0.99.20' PATCH=${PATCH_AFTER_v13} BUILD_SYSTEM='meson'"
tested_versions["manjaro_23.1"]="BRANCH='v1.90.2' PATCH=${PATCH_AFTER_v13} PATH_UPOWERD='/usr/lib' BUILD_SYSTEM='meson'"

set_upower_branch() {
    local key="${1}_${2}"
    local values=${tested_versions[$key]}
    
    # check for exact os/os_version match
    if [[ -n ${tested_versions[$key]} ]]; then
        eval "${tested_versions[$key]}"
    else
        # combination of os/os_ver not yet tested
        unknown_system
        exit 1
    fi
}

unknown_system() {
    echo "-- Unknown system; this script wasn't tested with your OS. Please open"
    echo "-- an issue and add debug info below: https://github.com/guiambros/silent-mouse/issues"
    debug_vars
    exit 1
}

debug_vars() {
    echo PATH_UPOWER=${PATH_UPOWER}
    echo PATH_UPOWERD=${PATH_UPOWERD}
    echo OS=${OS}
    echo OS_VER=${OS_VER}
    echo OS_VER_MAJOR=${OS_VER_MAJOR}
    echo UPOWER_ORIG_VER=${UPOWER_ORIG_VER}
    echo BRANCH=${BRANCH}
    echo PATCH=${PATCH}
    echo PATH_UPOWER=${PATH_UPOWER}
    echo PATH_UPOWERD=${PATH_UPOWERD}
    echo BUILD_SYSTEM=${BUILD_SYSTEM}
}

echo -e "OS detected:\n--- OS = ${OS}\n--- OS_VER = ${OS_VER}\n\n"
set_upower_branch $OS $OS_VER

if [ "$DEBUG_VARS" == "true" ] || [ "$1" == "-debug" ] || [ "$1" == "--debug" ]; then
    debug_vars
    exit 0
fi

# additional packages required depending on build system (cmake / meson)
if [ "${BUILD_SYSTEM}" == "meson" ]; then
    ADDT_PACKAGES="meson ninja-build libimobiledevice-dev libgirepository1.0-dev"
elif [ "${BUILD_SYSTEM}" == "cmake" ]; then
    ADDT_PACKAGES="autoconf automake make"
else
    echo "Invalid build system"
    debug_vars
    exit 1
fi

# distro-specific packages
if [ "$OS" == "ubuntu" ]; then
    if [ "${BUILD_SYSTEM}" == "meson" ]; then
        ADDT_PACKAGES="meson ninja-build libimobiledevice-dev libgirepository1.0-dev"
    fi
    echo -e "-- Ubuntu detected; installing required libraries\n\n"
    sudo apt install -y git gtk-doc-tools gobject-introspection libgudev-1.0-dev \
    libusb-1.0-0-dev autoconf libtool autopoint intltool ${ADDT_PACKAGES}

elif [ "$OS" == "debian" ]; then
    echo -e "-- Debian detected; installing required libraries\n\n"
    sudo apt install -y git gtk-doc-tools gobject-introspection libgudev-1.0-dev \
        libusb-1.0-0-dev autoconf libtool autopoint intltool ${ADDT_PACKAGES}

elif [ "$OS" == "manjaro" ]; then
    echo -e "-- Manjaro detected; installing required libraries\n\n"
    sudo pacman -Syu --noconfirm base-devel gtk-doc gobject-introspection \
        git libtool ${ADDT_PACKAGES}

else
    unknown_system
    exit 1
fi

echo "---------------------------------------------------------------------------"
echo

# Download upowerd source and select the proper branch
git clone https://gitlab.freedesktop.org/upower/upower
echo "-- Using branch ${BRANCH}"
cd upower
git fetch --all --tags
git checkout tags/${BRANCH} -b ${BRANCH}
cd src

# Download and patch upowerd
cp ../../${PATCH} .
if [ "$1" == "-keyboard" ] || [ "$1" == "--keyboard" ]; then
    SILENCE_KEYBOARD="+     if ((type == UP_DEVICE_KIND_MOUSE || type == UP_DEVICE_KIND_KEYBOARD) && state == UP_DEVICE_STATE_DISCHARGING) {"
    sed -i "/UP_DEVICE_KIND_MOUSE/c${SILENCE_KEYBOARD}" ${PATCH}
fi
patch -F 2 < ${PATCH}
cd ..

# Compile upowerd according to the build system
if [ "${BUILD_SYSTEM}" == "cmake" ]; then
    ./autogen.sh
    ./configure
    make
elif [ "${BUILD_SYSTEM}" == "meson" ]; then
    meson _build -Dintrospection=enabled -Dman=true -Dgtk-doc=true -Didevice=enabled
    ninja -C _build
else
    echo "Invalid build system"
    unknown_system
    exit 1
fi

# Install upowerd
CUR_DATETIME=`date +%Y-%m-%d-%H%M%S`
pushd . # we're in ./silent-mouse/upower/
if [ "${BUILD_SYSTEM}" == "meson" ]; then
    cd _build/src
else # cmake
    cd src/.libs
fi
strip upowerd
sudo chown root upowerd
sudo chgrp root upowerd
sudo mv upowerd ${PATH_UPOWERD}/upowerd-silent
cd ${PATH_UPOWERD}
sudo mv upowerd upowerd-original-${CUR_DATETIME}
sudo ln -s upowerd-silent upowerd
popd

# Install upower
pushd .
if [ "${BUILD_SYSTEM}" == "meson" ]; then
    cd _build/tools
else # cmake
    cd tools/.libs
fi
strip upower
sudo chown root upower
sudo chgrp root upower
sudo mv upower ${PATH_UPOWER}/upower-silent
cd ${PATH_UPOWER}
sudo mv upower upower-original-${CUR_DATETIME}
sudo ln -s upower-silent upower
popd

# Restart upowerd
sudo systemctl restart upower

# Compare versions before/after (they will likely be different, but it depends on distro defaults)
echo
echo "---------------------------------------------------------------------------"
echo "upower version BEFORE the update:"
echo "${UPOWER_ORIG_VER}"
echo "-------------------------------------"
echo "upower version AFTER the update (likely same version, or a minor number above/below):"
upower --version
echo "-------------------------------------"

