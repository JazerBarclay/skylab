#!/bin/sh

RED='\033[0;31m'
NC='\033[0m'

printRED() { printf "${RED}$*${NC}\n"; }

# Message to show how the command can be run
usage() {
    echo "Usage: $0 [options]..."
    echo "Installs Arch based on user input"
    echo 
    echo "Arguments:"
    echo "  -h, prints usage (like you just have)"
    echo "  -d, dry run the script with only prompts"
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
  +512M # 512 MB efi parttion
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

# Welcome greeting upon first running the script
welcomemsg() { \
	whiptail --title "Welcome!" --msgbox "Welcome to Skylab!\\n\\nThis script will automatically install Arch to your given specification!" 10 60
}

preinstallmsg() { \
	whiptail --title "Let's get started" --yes-button "Let's Go!" --no-button "Wait, nah" --yesno \
    "This script will now install Arch...\nUEFI: $isUEFI\nHostname: $hostName\nUsername: $name \nDrive: $targetDrive" 10 50 || { clear; exit; }
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
    keyboard=$keyboardSelected
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
    userPass=$pass1
}

getHostname() {
    hostName=$(whiptail --inputbox "Enter Hostname" 10 60 3>&1 1>&2 2>&3 3>&1) || error "Exitted hostname entry"
	while ! echo "$hostName" | grep "^[a-z_][a-z0-9_-]*$" >/dev/null 2>&1; do
		hostName=$(whiptail --inputbox --nocancel "Hostname not valid. Give a hostname beginning with a letter, with only lowercase letters, - or _." 10 60 3>&1 1>&2 2>&3 3>&1)
	done
}

# --------------------------- Params --------------------------- #

while getopts "hdq" o; do case "${o}" in
	h) usage && exit ;;
	d) dryrun=1 ;;
    q) quick=1 ;;
	*) printf "Invalid option: -%s\\n" "$OPTARG" && exit ;;
esac done


# --------------------------- Setup --------------------------- #

if [ ! -z $quick ]; then
    keyboard="uk"
    name=jazer
    checkUEFI
    githubUsername="jazerbarclay"
    githubDotfiles="dotfiles"

    clear
    echo "UEFI: $isUEFI"
    echo "Username: $name"
    echo "Keyboard: $keyboard"
    echo ""

    printRED "Target Drives Available"
    sudo lsblk -o name,size,model -d -e7 | tail -n +2
    echo ""
    printRED "Please select the target drive for install"

    driveList="$(sudo lsblk -o name -d -e7 | tail -n +2 )"
    menu_from_array $driveList
    targetDrive=$item

    clear
    echo "UEFI: $isUEFI"
    echo "Selected Drive: $targetDrive"
    echo "Username: $name"
    echo "Keyboard: $keyboard"
    echo ""

    printRED "Enter password (asked once so please ensure correct)"
    read -s userPass

    clear
    echo "UEFI: $isUEFI"
    echo "Selected Drive: $targetDrive"
    echo "Username: $name"
    echo "Keyboard: $keyboard"
    echo ""

    printRED "Enter system hostname"
    read hostName
    clear

    printf "UEFI: "
    [ -z $isUEFI ] && echo "No" || echo "Yes"
    echo "Keyboard: $keyboard"
    echo "Hostname: " $hostName
    echo "Username: $name"
    echo "Drive: /dev/$targetDrive"
    echo
    read -n 1 -s -r -p "Press any key to continue or CTRL+C to exit"

else
    welcomemsg
    checkUEFI

    selectKeyboard
    selectDrive
    getUsername
    getUserPass

    getHostname
    selectDotFiles

    preinstallmsg
fi

if [ ! -z ${dryrun} ]; then
    printf "\nDry Run Complete\n" && exit 0
else
    clear
    echo "Please press CTRL+C within the next 5 seconds to cancel"
    sleep 5
fi

# --------------------------- Install --------------------------- #

printRED "Updating Install Packages"
pacman -Sy
pacman --noconfirm -S reflector
sleep 3s

printRED "Updating Pacman Mirrorlist"
reflector --latest 200 --protocol http --protocol https --sort rate --save /etc/pacman.d/mirrorlist
sleep 3s

printRED "Setting keyboard..." && loadkeys $keyboard
sleep 3s

printRED "Setting time-date..." && timedatectl set-ntp true
sleep 3s

printRED "Unmounting /dev/$targetDrive"
umount /dev/${targetDrive}?*
sleep 3s

printRED "Wiping disk"
sgdisk --zap-all /dev/$targetDrive
sleep 3s

printRED "Partitioning Drive..."
if [ -z $isUEFI ]; then
    partition_bios_drive /dev/$targetDrive
else 
    partition_efi_drive /dev/$targetDrive
fi
sleep 3s

printRED "Generating Filesystems"
yes | mkfs.fat -F 32 /dev/${targetDrive}1
sleep 3s

yes | mkfs.ext4 -F /dev/${targetDrive}2
sleep 3s

printRED "Mounting partitions"
mount /dev/${targetDrive}2 /mnt
sleep 3s

if [ -z $isUEFI ]; then
    mkdir -p /mnt/boot && mount /dev/${targetDrive}1 /mnt/boot
else 
    mkdir -p /mnt/boot/efi && mount /dev/${targetDrive}1 /mnt/boot/efi
fi
sleep 3s

printRED "Installing Base Packages"
yes '' | pacstrap /mnt base base-devel sudo vim zsh linux-lts linux-firmware linux-lts-headers --ignore linux
sleep 3s

printRED "Generating fstab"
genfstab -U -p /mnt >> /mnt/etc/fstab
sleep 3s

printRED "Setting System Settings"
arch-chroot /mnt /bin/bash <<EOF
hwclock --systohc
ln -sf /usr/share/zoneinfo/Europe/London /etc/localtime
sed -i '1s/^/en_GB.UTF-8 UTF-8\n/' /etc/locale.gen
echo "LANG=en_GB.UTF-8" > /etc/locale.conf
locale-gen
echo "KEYMAP=$keyboard" > /etc/vconsole.conf
echo $hostName > /etc/hostname
echo "127.0.0.1     localhost" >> /etc/hosts
echo "127.0.0.1     $hostName" >> /etc/hosts
echo "root:${userPass}" | chpasswd
sleep 3s
echo "Installing wifi packages"
pacman --noconfirm -S netctl dhcpcd wpa_supplicant dialog
sleep 3s
echo "Installing grub bootloader"
pacman --noconfirm -S grub efibootmgr dosfstools os-prober mtools
sleep 3s
echo "Installing recommended packages"
pacman --noconfirm -S git wget curl openssh nmap ddrescue
systemctl enable sshd.service
sleep 3s
EOF

printRED "Installing GRUB"
if [ -z $isUEFI ]; then

printRED "BIOS BOOT"
arch-chroot /mnt /bin/bash <<EOF
grub-install --target=i386-pc --recheck /dev/${targetDrive}
grub-mkconfig -o /boot/grub/grub.cfg
EOF

else

printRED "UEFI BOOT"
arch-chroot /mnt /bin/bash <<EOF
echo "Installing Grub boot loader"
pacman --noconfirm -S grub
grub-install --target=x86_64-efi --bootloader-id=SkyLab --recheck /dev/${targetDrive}
mkdir -p /boot/grub/locale && cp /usr/share/locale/en\@quot/LC_MESSAGES/grub.mo /boot/grub/locale/en.mo
grub-mkconfig -o /boot/grub/grub.cfg
EOF

fi
sleep 3s

printRED "Setting up user ${name}"
arch-chroot /mnt /bin/bash <<EOF

chsh -s /usr/bin/zsh root
useradd -m -G wheel,audio,docker -s /usr/bin/zsh ${name}
echo "${name}:${userPass}" | chpasswd
echo "# One sudo login authorises all other terminals a free upgrade" >> /etc/sudoers
echo "Defaults !tty_tickets" >> /etc/sudoers
echo "" >> /etc/sudoers
echo "# Uncomment below to allow sudo without password on wheel users" >> /etc/sudoers
echo "%wheel ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
echo "" >> /etc/sudoers
su $name -c "git clone --bare https://github.com/${githubUsername}/${githubDotfiles}.git /home/${name}/dotfiles"
su $name -c "/usr/bin/git --git-dir=/home/${name}/dotfiles/ --work-tree=/home/${name} checkout -f"
su $name -c "/usr/bin/git --git-dir=/home/${name}/dotfiles/ --work-tree=/home/${name} config --local status.showUntrackedFiles no"
su $name -c "ssh-keygen -o -a 100 -t ed25519 -f /home/${name}/.ssh/id_ed25519 -C '${name}@${hostName}'"
EOF
sleep 3s

printRED "Installing yay"
arch-chroot /mnt /bin/bash <<EOF

pushd /tmp
git clone https://aur.archlinux.org/yay.git
chown -R $name:$name yay
cd yay
su ${name} -c "makepkg -si --noconfirm"
popd

EOF
sleep 3s

printRED "Installing Core Packages"
arch-chroot /mnt /bin/bash <<EOF

# xorg and lightdm
pacman --noconfirm -S xorg-server xorg-xrandr xorg-xbacklight lightdm lightdm-gtk-greeter xf86-video-intel
# i3, dmenu and system stats
pacman --noconfirm -S i3-gaps i3status i3blocks dmenu nitrogen brightnessctl alsa-utils alsa-firmware pulseaudio
# System Stats
pacman --noconfig -S sysstat acpi lm_sensors scrot neofetch
# Core Terminal Utils
pacman --noconfirm -S libnewt dosfstools unzip unrar nmap ddrescue rsync
# Core Window Utils
pacman --noconfirm -S termite thunar gvfs-smb findutils gparted feh redshift lxappearance
# Fonts
pacman --noconfirm -S ttf-dejavu ttf-hack ttf-font-awesome noto-fonts-emoji adobe-source-code-pro-fonts adobe-source-han-sans-jp-fonts
# Developer Stuff
pacman --noconfirm -S code docker docker-compose chromium firefox tor torbrowser-launcher vlc obs-studio transmission-gtk


sudo systemctl enable lightdm
sudo systemctl enable dhcpcd
sudo systemctl enable netctl-auto@wlp3s0
sudo systemctl enable dhcpcd@enp0s25
sudo ip link set enp0s3 up

pushd /home/${name}
mkdir -p Documents Downloads Pictures/Wallpapers Videos projects
popd

EOF

printRED "Installing AUR Packages"
arch-chroot /mnt /bin/bash <<EOF

yes '' | yay -Syu

yes '' | yay -S gtkpod

yes '' | yay -S discord

# Setup new gpg key for spotify
curl -sS https://download.spotify.com/debian/pubkey_0D811D58.gpg | gpg --import -
yes '' | yay -S spotify

yes '' | yay -S virtualbox-bin

yes '' | yay -S intel-undervolt

# Thinkpad fan
yes '' | yay -S thinkfan-git
echo "options thinkpad_acpi fan_control=1" > /etc/modprobe.d/modprobe.conf
echo "options thinkpad_acpi fan_control=1" > /usr/lib/modprobe.d/thinkpad_acpi.conf
modprobe thinkpad_acpi

echo "tp_fan /proc/acpi/ibm/fan\n" > /etc/thinkfan.conf
hwmon /sys/devices/platform/coretemp.0/hwmon/hwmon4/temp1_input
hwmon /sys/devices/platform/coretemp.0/hwmon/hwmon4/temp2_input
hwmon /sys/devices/platform/coretemp.0/hwmon/hwmon4/temp3_input
hwmon /sys/devices/virtual/thermal/thermal_zone0/hwmon0/temp1_input

(0,     0,      49)
(1,     30,     59)
(2,     35,     69)
(3,     40,     79)
(4,     45,     89)
(5,     50,     99)
(7,     60,     32767)" > /etc/thinkfan.conf

sudo modprobe thinkpad_acpi

sudo systemctl enable thinkfan


EOF

echo ""
printRED "Skylab Installation Complete"
echo ""
