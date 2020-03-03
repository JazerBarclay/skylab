#!/bin/sh

# Message to show how the command can be run
usage() {
    echo "Usage: $0 [options]..."
    echo "Installs Arch based on user input"
    echo 
    echo "Arguments:"
    echo "  -d, dry run the script with only prompts"
    echo "  -h, prints usage (like you just have)"
    echo "  -q, run with minimal prompts (uses my settings)"
    echo ""
}

# Exit with error taking a message parameter
error() { clear; printf "Exitting: %s\\n\\n" "$1"; exit 1; }

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

if [ ! -z ${quick+x} ]; then 
    keyboard="/usr/share/kbd/keymaps/i386/qwerty/uk.map.gz"
    loadkeys $keyboard
    checkUEFI

    echo $isUEFI
    name=jazer

    selectDrive
    getUserPass
    dryrunmsg

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
        #echo "Unmounting Target Device" && sudo umount /dev/$targetDrive?* >/dev/null 2>&1
        #echo "Setting disk to GPT" && sgdisk -z /dev/$targetDrive  >/dev/null 2>&1
        #
    else
        echo "Dry Run"
        sleep 5


    fi

fi