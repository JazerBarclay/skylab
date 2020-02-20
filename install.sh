#!/bin/sh

# Example Menu from Drive Output
# value="$(dialog --backtitle "test" --radiolist "Select" 10 40 4 `(fdisk -l | grep "Disk /dev" | awk '{print $2}' | tr -d ':' | head -n -1 | awk '{print $1" "$1" on"}' ORS=" ")` 3>&1 1>&2 2>&3 )"

usage() {
    echo "run install.sh to install"
}

# Select Drive Dialog
selectDrive() {
    drive=$()
    dialog --backtitle "CPU Selection" --radiolist "Select CPU type:" 10 40 4 \
    1 386SX off 2 386DX on  3 486SX off 4 486DX off
}

prepDrive() {
    # 
}

sgdisk -z /dev/sda