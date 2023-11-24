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

# Configuration variables
BUILD_SYSTEM="cmake" # use the classic cmake or the newer mason (in more recent distros)
PATH_UPOWER="/usr/bin"
PATH_UPOWERD="/usr/libexec"
PATCH_LEGACY="up-device-0_99_11.patch"
PATCH_AFTER_v13="up-device-0_99_13.patch"
DEBUG_VARS="false"
declare -A tested_versions

# list of all versions tested
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
    echo "-- ERROR: Unknown system; this script wasn't tested with your OS. Please open"
    echo "-- an issue and include debug info below: https://github.com/guiambros/silent-mouse/issues"
    debug_vars
    exit 1
}

debug_vars() {
    echo -e "\n-- Debug variables:"
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
    echo
}

# Detect running OS and confirm upower is installed
OS=`awk -F= '/^ID=/{print $2}' /etc/os-release`

# manjaro uses a rolling release schedule, without major/minor releases; try lsb_release instead
if [ "${OS}" == "manjaro" ]; then
    if command -v lsb_release >/dev/null 2>&1; then
        OS_VER=`lsb_release -a | awk '/^Release:/{print $2}' | cut -d '.' -f 1-2`
    else
        echo "-- ERROR: Manjaro detected, but can't figure out which version. Aborting"
        debug_vars
        exit 1
    fi
else
    OS_VER=`awk -F= '/^VERSION_ID=/{print $2}' /etc/os-release | cut -d "\"" -f 2`
fi
OS_VER_MAJOR=`echo ${OS_VER} | awk -F. '{print $1}'`

if command -v upower >/dev/null 2>&1; then
    echo
    echo "---------------------------------------------------------------------------"
    upower --version
    echo "---------------------------------------------------------------------------"
    echo
    UPOWER_ORIG_VER=`upower --version`
else
    echo "-- ERROR: upower is not installed; nothing to do."
    debug_vars
    exit 1
fi
echo -e "OS detected:\n--- OS = ${OS}\n--- OS_VER = ${OS_VER}\n\n"
set_upower_branch $OS $OS_VER

if [ "$DEBUG_VARS" == "true" ] || [ "$1" == "-debug" ] || [ "$1" == "--debug" ]; then
    debug_vars
    exit 0
fi

# additional packages required depending on build system (cmake / meson)
if [ "${BUILD_SYSTEM}" == "meson" ]; then
    if [ "${OS}" == "manjaro" ]; then
        ADDT_PACKAGES="meson ninja libimobiledevice libgirepository"
    else
        ADDT_PACKAGES="meson ninja-build libimobiledevice-dev libgirepository1.0-dev"
    fi
elif [ "${BUILD_SYSTEM}" == "cmake" ]; then
    ADDT_PACKAGES="autoconf automake make"
else
    echo "ERROR: Invalid build system"
    unknown_system
    exit 1
fi

# distro-specific packages required to compile upower
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
REPO_DIR=$(realpath $(dirname "$0"))
TEMP_DIR=$(mktemp -d)
cd ${TEMP_DIR}
git clone https://gitlab.freedesktop.org/upower/upower ${TEMP_DIR}
echo "-- Using branch ${BRANCH}"
git fetch --all --tags
git checkout tags/${BRANCH} -b ${BRANCH}

# Download and patch upowerd
cd src
cp ${REPO_DIR}/${PATCH} .
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
else # should never happen; tested above for a valid build system
    echo "ERROR: Invalid build system"
    unknown_system
    exit 1
fi

# Install upowerd
CUR_DATETIME=`date +%Y-%m-%d-%H%M%S`
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

# Install upower
cd ${TEMP_DIR}
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

# Restart upowerd
sudo systemctl restart upower
rm -rf ${TEMP_DIR}

# Compare versions before/after (they will likely be different, but it depends on distro defaults)
echo "---------------------------------------------------------------------------"
echo "-- Patch successfully completed! upower version BEFORE the update:"
echo "${UPOWER_ORIG_VER}"
echo
echo "upower version AFTER the update (is should be the same version, or a minor number above/below):"
upower --version
echo "---------------------------------------------------------------------------"

