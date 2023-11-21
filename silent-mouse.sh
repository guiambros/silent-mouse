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

declare -A tested_versions

# list of all versions tested
PATH_UPOWER="/usr/bin"
PATH_UPOWERD="/usr/libexec"
tested_versions["ubuntu_18.04"]="BRANCH='UPOWER_0_99_7' PATCH='up-device-0_99_11.patch' PATH_UPOWERD='/usr/lib/upower'"
tested_versions["ubuntu_20.04"]="BRANCH='UPOWER_0_99_11' PATCH='up-device-0_99_11.patch' PATH_UPOWERD='/usr/lib/upower'"
tested_versions["ubuntu_22.04"]="BRANCH='UPOWER_0_99_17' PATCH='up-device-0_99_13.patch'"
#u23.10 moves to 1.90.2
# this will likely require new patches
# tested_versions["ubuntu_23.10"]="BRANCH='UPOWER_0_99_xx' PATCH='up-device-0_99_xx.patch'"

tested_versions["debian_10"]="BRANCH='UPOWER_0_99_10' PATCH='up-device-0_99_11.patch' PATH_UPOWERD='/usr/lib/upower'"
tested_versions["debian_11"]="BRANCH='UPOWER_0_99_11' PATCH='up-device-0_99_13.patch'"
tested_versions["debian_12"]="BRANCH='UPOWER_0_99_20' PATCH='up-device-0_99_13.patch'"

tested_versions["majaro_*"]="BRANCH='UPOWER_0_99_13' PATCH='up-device-0_99_13.patch' PATH_UPOWER='/usr/sbin/' PATH_UPOWERD='/usr/lib'"

set_upower_branch() {
    local key="${1}_${2}"
    local found=0
    local values=${tested_versions[$key]}
    if [[ -n ${tested_versions[$key]} ]]; then
        eval "${tested_versions[$key]}"
        found=1
    else
        for k in "${!tested_versions[@]}"; do
            if [[ $k == "$1_"* ]]; then
                eval "${tested_versions[$k]}"
                found=1
                break
            fi
        done
    fi

    if [[ $found -eq 0 ]]; then
        echo "No entry found for $1 with $2"
    fi
}

echo -e "OS detected:\n--- OS = ${OS}\n--- OS_VER = ${OS_VER}\n\n"

if [ "$OS" == "manjaro" ]
then
    echo -e "-- Manjaro detected; installing required libraries\n\n"
    sudo pacman -Syu --noconfirm base-devel gtk-doc gobject-introspection git libtool meson autoconf automake make 

elif [ "$OS" == "ubuntu" ]
then
    echo -e "-- Ubuntu detected; installing required libraries\n\n"
    sudo apt install -y git gtk-doc-tools gobject-introspection libgudev-1.0-dev libusb-1.0-0-dev autoconf libtool autopoint

elif [ "$OS" == "debian" ]
then
    echo -e "-- Debian detected; installing required libraries\n\n"
    sudo apt install -y git gtk-doc-tools gobject-introspection libgudev-1.0-dev libusb-1.0-0-dev autoconf libtool autopoint
else
    echo "-- Unknown system; this script was only tested on ubuntu, debian and manjaro."
    exit 1
fi
set_upower_branch $OS $OS_VER
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
echo "upower version AFTER the update (likely same version, or a minor number above/below):"
upower --version
echo "-------------------------------------"
