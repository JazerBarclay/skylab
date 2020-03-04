#!/bin/sh

RED='\033[0;31m'
NC='\033[0m'

printRED() { printf "\n${RED}$*${NC}\n"; }

# Message to show how the command can be run
usage() {
    echo "Usage: $0 [options]..."
    echo "Installs Arch based on user input"
    echo 
    echo "Arguments:"
    echo "  -d, dry run the script with only prompts"
    echo "  -h, prints usage (like you just have)"
    echo "  -q, run with minimal prompts using my settings"
    echo ""
}

# Create a text menu from an array argument
menu_from_array () {
    select item; do
        # Check the selected menu item number
        if [ 1 -le "$REPLY" ] && [ "$REPLY" -le $# ]; then
            printf "${RED}Selected:${NC} $item"
            break;
        else
            echo "Wrong selection: Select any number from 1-$#"
        fi
    done
}

# Exit with error taking a message parameter
error() { clear; printf "Exitting: %s\\n\\n" "$1"; exit 1; }

partition_bios_drive() {

sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF | sudo fdisk $1
  g # clear the in memory partition table with GPT
  n # new partition
  1 # partition number 1
    # default - start at beginning of disk 
  +512M # 512 MB boot parttion
  t # change partition type
  4 # set to BIOS boot
  n # new partition
  2 # partition number 2
    # default, start immediately after preceding partition
    # default, extend partition to end of disk
  p # print the in-memory partition table
  w # write the partition table and quit
EOF

}

partition_efi_drive() {

sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF | sudo fdisk $1
  g # clear the in memory partition table with GPT
  n # new partition
  1 # partition number 1
    # default - start at beginning of disk 
  +512M # 512 MB boot/efi parttion
  t # change partition type
  1 # set to EFI boot
  n # new partition
  2 # partition number 2
    # default, start immediately after preceding partition
    # default, extend partition to end of disk
  p # print the in-memory partition table
  w # write the partition table and quit
EOF

}


rankMirrors() {
    cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
    sed -i 's/^#Server/Server/' /etc/pacman.d/mirrorlist.backup
    rankmirrors -n 6 /etc/pacman.d/mirrorlist.backup > /etc/pacman.d/mirrorlist
}

# Welcome greeting upon first running the script
welcomemsg() { \
	whiptail --title "Welcome!" --msgbox "Welcome to Skylab!\\n\\nThis script will automatically install Arch to your given specification!" 10 60
}

preinstallmsg() { \
	whiptail --title "Let's get started" --yes-button "Let's Go!" --no-button "Wait, nah" --yesno \
    "This script will now install Arch...\nUser: $name \nDrive: $targetDrive" 10 50 || { clear; exit; }
}

dryrunmsg() { \
	whiptail --title "Dry Run Output" --yes-button "Looks Good!" --no-button "Hmm..." --yesno \
    "This script would install on live using these settings: ...\nUser: $name \nDrive: $targetDrive" 10 50 || { clear; exit; }
}

checkUEFI() {
    [ -d "/sys/firmware/efi/efivars" ] && isUEFI=1
}

selectKeyboard() {
    keyboardDir="/usr/share/kbd/keymaps"
    keyboardList=$(find /usr/share/kbd/keymaps -name '*.map.gz' | sort -z | awk '{print substr($1,24,length($1))}' | tr '/' ' ' |  awk '{ printf " %s ",substr($NF,1,length($NF)-7) ; for (i=1; i<=NF; i++) printf "/%s", $i }' | awk '{printf "uk /i386/qwerty/uk.map.gz us /i386/qwerty/us.map.gz %s",$0}')
    keyboardSelected="$(whiptail --title "Keyboard Selection" --menu "Choose your keyboard layout" 24 100 16 $keyboardList 3>&1 1>&2 2>&3)" || error "Cancelled Keyboard Select)"
    echo $keyboardSelected
}

# Select Drive Dialog
selectDrive() {
    driveList="$(sudo lsblk -o name,model,size -d -e7 | tail -n +2 | awk '{print $1" "$2"-("$3")"}')"
    targetDrive="$(whiptail --title "Drive Selection" --menu "Choose an target drive" 14 42 6 $driveList 3>&1 1>&2 2>&3)" || error "Cancelled Drive Select"
    echo $targetDrive
}

selectDotFiles() {
    githubUsername=$(whiptail --inputbox "Enter your github username" 10 60 3>&1 1>&2 2>&3 3>&1)
    githubDotfiles=$(whiptail --inputbox "Enter your dotfiles repo name" 10 60 "dotfiles" 3>&1 1>&2 2>&3 3>&1)
    dotfiles="$githubUsername/$githubDotfiles" && git ls-remote -q "$githubUsername@github.com:$githubUsername/$githubDotfiles.git" CHECK_GIT_REMOTE_URL_REACHABILITY >/dev/null 2>&1 || echo "dotfiles failed"
}

getUsername() {
    name=$(whiptail --inputbox "First, please enter a name for the user account." 10 60 3>&1 1>&2 2>&3 3>&1) || error "Exitted username entry"
	while ! echo "$name" | grep "^[a-z_][a-z0-9_-]*$" >/dev/null 2>&1; do
		name=$(whiptail --inputbox --nocancel "Username not valid. Give a username beginning with a letter, with only lowercase letters, - or _." 10 60 3>&1 1>&2 2>&3 3>&1)
	done
}

getUserPass() {
    pass1=$(whiptail --nocancel --passwordbox "Enter a password for user '$name'." 8 60 3>&1 1>&2 2>&3 3>&1)
	pass2=$(whiptail --nocancel --passwordbox "Retype password." 8 60 3>&1 1>&2 2>&3 3>&1)
	while ! [ "$pass1" = "$pass2" ]; do
		unset pass2
		pass1=$(whiptail --nocancel --passwordbox "Passwords do not match.\\n\\nEnter password again." 8 60 3>&1 1>&2 2>&3 3>&1)
		pass2=$(whiptail --nocancel --passwordbox "Retype password." 8 60 3>&1 1>&2 2>&3 3>&1)
	done ;
}

# run parameters
while getopts "hdq" o; do case "${o}" in
	h) usage && exit ;;
	d) dryrun=1 ;;
    q) quick=1 ;;
	*) printf "Invalid option: -%s\\n" "$OPTARG" && exit ;;
esac done

if [ ! -z $quick ]; then 
    clear

    keyboard="uk"
    name=jazer
    checkUEFI

    printRED "Target Drives Available"
    sudo lsblk -o name,size,model -d -e7 | tail -n +2
    printf "\n${RED}Please select the target drive for install${NC}\n"

    driveList="$(sudo lsblk -o name -d -e7 | tail -n +2 )"
    menu_from_array $driveList
    targetDrive=$item

    printRED "Enter password (asked once so please ensure correct)"
    read -s userPass

    echo "UEFI: "
    [ -z isUEFI ] && echo "No" || echo "Yes"
    echo "Keyboard: $keyboard"
    echo "Username: $name"
    echo "Password: ****"
    echo "Drive: /dev/$targetDrive"
    echo
    read -n 1 -s -r -p "Press any key to continue or CTRL+C to exit"
    

    if [ ! -z ${dryrun} ]; then
        printf "\nDry Run Complete\n" && exit 1
    else
        clear
        echo "Please press CTRL+C within the next 5 seconds to cancel"
        sleep 5
    fi

    echo "Setting keyboard..." && loadkeys $keyboard
    echo "Setting time-date..." && timedatectl set-ntp true
    echo "Partitioning Drive..."
    if [ -z $isUEFI ]; then
        partition_bios_drive /dev/$targetDrive
        mkfs.fat -F 32 /dev/${targetDrive}1
        mkfs.ext4 /dev/${targetDrive}2
    else 
        partition_efi_drive /dev/$targetDrive
        mkfs.fat -F 32 /dev/${targetDrive}1
        mkfs.ext4 /dev/${targetDrive}2
    fi
    
    mount /dev/${targetDrive}2 /mnt
    mkdir /mnt/efi && mount /dev/${targetDrive}2 /mnt/efi


    rankMirrors

else
    welcomemsg
    checkUEFI

    selectKeyboard
    selectDrive
    getUsername
    getUserPass

    preinstallmsg
    if [ -z ${dryrun+x} ]; then 
        echo "Please press CTRL+C within the next 5 seconds to cancel"
        sleep 5
        echo "Unmounting target disk" && sudo umount /dev/$targetDrive?* >/dev/null 2>&1
        echo "Setting disk to GPT" && sgdisk -z /dev/$targetDrive  >/dev/null 2>&1 || echo "Failed to set GPT"
        echo "Formatting disk"

    else
        echo "Dry Run"
        sleep 5


    fi

fi