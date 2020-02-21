#!/bin/sh

usage() {
    echo "run install.sh to install"
}

error() { clear; printf "Exitting: %s\\n\\n" "$1"; exit 1; }

# Select Drive Dialog
selectDrive() {
    driveList="$(sudo lsblk -o name,model,size -d -e7 | tail -n +2 | awk '{print $1" "$2"-("$3")"}')"
    value="$(whiptail --title "Drive Selection" --menu "Choose an target drive" 14 42 6 $driveList 3>&1 1>&2 2>&3)" || error "Cancelled Drive Select"
    echo $value
}

selectDrive
