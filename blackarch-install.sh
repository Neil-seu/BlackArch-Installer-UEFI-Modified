#!/usr/bin/env bash
################################################################################
#                                                                              #
# blackarch-installer - Official Installer for BlackArch Linux                 #
#                                                                              #
# AUTHOR                                                                       #
# noptrix@nullsecurity.net                                                     #
#                                                                              #
################################################################################


# blackarch-installer version
VERSION='1.2.22'

# path to blackarch-installer
BI_PATH='/usr/share/blackarch-installer'

# true / false
TRUE=0
FALSE=1

# return codes
SUCCESS=0
FAILURE=1

# verbose mode - default: quiet
VERBOSE='/dev/null'

# colors
WHITE="$(tput setaf 7)"
# WHITEB="$(tput bold ; tput setaf 7)"
# BLUE="$(tput setaf 4)"
BLUEB="$(tput bold ; tput setaf 4)"
CYAN="$(tput setaf 6)"
CYANB="$(tput bold ; tput setaf 6)"
# GREEN="$(tput setaf 2)"
# GREENB="$(tput bold ; tput setaf 2)"
RED="$(tput setaf 1)"
# REDB="$(tput bold; tput setaf 1)"
YELLOW="$(tput setaf 3)"
# YELLOWB="$(tput bold ; tput setaf 3)"
BLINK="$(tput blink)"
NC="$(tput sgr0)"

# installation mode
INSTALL_MODE=''

# install modes
INSTALL_REPO='1'
INSTALL_FULL_ISO='2'
INSTALL_BLACKMAN='3'

# chosen locale
LOCALE=''

# set locale
SET_LOCALE='1'

# list locales
LIST_LOCALE='2'

# chosen keymap
KEYMAP=''

# set keymap
SET_KEYMAP='1'

# list keymaps
LIST_KEYMAP='2'

# network interfaces
NET_IFS=''

# chosen network interface
NET_IF=''

# network configuration mode
NET_CONF_MODE=''

# network configuration modes
NET_CONF_AUTO='1'
NET_CONF_WLAN='2'
NET_CONF_MANUAL='3'
NET_CONF_SKIP='4'

# hostname
HOST_NAME=''

# host ipv4 address
HOST_IPV4=''

# gateway ipv4 address
GATEWAY=''

# subnet mask
SUBNETMASK=''

# broadcast address
BROADCAST=''

# nameserver address
NAMESERVER=''

# DualBoot flag
DUALBOOT=''

# LUKS flag
LUKS=''

# avalable hard drive
HD_DEVS=''

# chosen hard drive device
HD_DEV=''

# Partitions
PARTITIONS=''

# partition label: gpt or dos
PART_LABEL=''

# boot partition
BOOT_PART=''

# root partition
ROOT_PART=''

# crypted root
CRYPT_ROOT='r00t'

# swap partition
SWAP_PART=''

# boot fs type - default: fat
BOOT_FS_TYPE=''

# root fs type - default: ext4
ROOT_FS_TYPE=''

# chroot directory / blackarch linux installation
CHROOT='/mnt'

# normal system user
NORMAL_USER=''

# default BlackArch Linux repository URL
#BA_REPO_URL='https://www.mirrorservice.org/sites/blackarch.org/blackarch/$repo/os/$arch'
#BA_REPO_URL='https://blackarch.unixpeople.org/$repo/os/$arch'
BA_REPO_URL='https://ftp.halifax.rwth-aachen.de/blackarch/$repo/os/$arch'

# default ArchLinux repository URL
AR_REPO_URL='https://mirror.rackspace.com/archlinux/$repo/os/$arch'

# X (display + window managers ) setup - default: false
X_SETUP=$FALSE

# VirtualBox setup - default: false
VBOX_SETUP=$FALSE

# VMware setup - default: false
VMWARE_SETUP=$FALSE

# BlackArch Linux tools setup - default: false
BA_TOOLS_SETUP=$FALSE

# wlan ssid
WLAN_SSID=''

# wlan passphrase
WLAN_PASSPHRASE=''

# check boot mode
BOOT_MODE=''

# check type of ISO (Full? netinst?)
ISO_TYPE=''


# Exit on CTRL + c
ctrl_c() {
  err "Keyboard Interrupt detected, leaving..."
  exit $FAILURE
}

trap ctrl_c 2


# check exit status
check()
{
  es=$1
  func="$2"
  info="$3"

  if [ "$es" -ne 0 ]
  then
    echo
    warn "Something went wrong with $func. $info."
    sleep 5
  fi
}


# print formatted output
wprintf()
{
  fmt="${1}"

  shift
  printf "%s$fmt%s" "$WHITE" "$@" "$NC"

  return $SUCCESS
}


# print warning
warn()
{
  printf "%s[!] WARNING: %s%s\n" "$YELLOW" "$@" "$NC"

  return $SUCCESS
}


# print error and return failure
err()
{
  printf "%s[-] ERROR: %s%s\n" "$RED" "$@" "$NC"

  return $FAILURE
}

# leet banner (very important)
banner()
{
  columns="$(tput cols)"
  str="--==[ blackarch-installer v$VERSION ]==--"

  printf "${BLUEB}%*s${NC}\n" "${COLUMNS:-$(tput cols)}" | tr ' ' '-'

  echo "$str" |
  while IFS= read -r line
  do
    printf "%s%*s\n%s" "$CYANB" $(( (${#line} + columns) / 2)) \
      "$line" "$NC"
  done

  printf "${BLUEB}%*s${NC}\n\n\n" "${COLUMNS:-$(tput cols)}" | tr ' ' '-'

  return $SUCCESS
}


# check boot mode
check_boot_mode()
{
  if [ "$(efivar --list 2> /dev/null)" ]
  then
     BOOT_MODE="uefi"
  fi

  return $SUCCESS
}


# check type of iso
check_iso_type()
{
  if [ "$(which dnsspider 2> /dev/null)" ]
  then
    ISO_TYPE='full'
  else
    ISO_TYPE='net'
  fi

  return $SUCCESS
}


# sleep and clear
sleep_clear()
{
  sleep "$1"
  clear

  return $SUCCESS
}


# confirm user inputted yYnN
confirm()
{
  header="$1"
  ask="$2"

  while true
  do
    title "$header"
    wprintf "$ask"
    read -r input
    case $input in
      y|Y|yes|YES|Yes) return $TRUE ;;
      n|N|no|NO|No) return $FALSE ;;
      *) clear ; continue ;;
    esac
  done

  return $SUCCESS
}


# print menu title
title()
{
  banner
  printf "${CYAN}>> %s${NC}\n\n\n" "${@}"

  return "${SUCCESS}"
}


# check for environment issues
check_env()
{
  if [ -f '/var/lib/pacman/db.lck' ]
  then
    err 'pacman locked - Please remove /var/lib/pacman/db.lck'
  fi
}


# check user id
check_uid()
{
  if [ "$(id -u)" != '0' ]
  then
    err 'You must be root to run the BlackArch installer!'
  fi

  return $SUCCESS
}


# welcome and ask for installation mode
ask_install_mode()
{
  while
    [ "$INSTALL_MODE" != "$INSTALL_REPO" ] && \
    [ "$INSTALL_MODE" != "$INSTALL_BLACKMAN" ] && \
    [ "$INSTALL_MODE" != "$INSTALL_FULL_ISO" ]
  do
    title 'Welcome to the BlackArch Linux installer!'
    wprintf '[+] Available installation modes:'
    printf "\n
  1. Install from BlackArch repository (online)
  2. Install from BlackArch Full-ISO (offline)
  3. Install from sources using blackman (online)\n\n"
    wprintf '[?] Choose an installation mode: '
    read -r INSTALL_MODE
    if [ "$INSTALL_MODE" = "$INSTALL_FULL_ISO" ]
    then
      if [ "$ISO_TYPE" = "net" ]
      then
        err 'WTF, Full-ISO mode with Netinstall? Nope!'
        ask_install_mode
        INSTALL_MODE=''
      fi
    fi
    clear
  done

  return $SUCCESS
}


# ask for output mode
ask_output_mode()
{
  title 'Environment > Output Mode'
  wprintf '[+] Available output modes:'
  printf "\n
  1. Quiet (default)
  2. Verbose (output of system commands: mkfs, pacman, etc.)\n\n"
  wprintf "[?] Make a choice: "
  read -r output_opt
  if [ "$output_opt" = 2 ]
  then
    VERBOSE='/dev/stdout'
  fi

  return $SUCCESS
}


# ask for locale to use
ask_locale()
{
  while [ "$locale_opt" != "$SET_LOCALE" ] && \
    [ "$locale_opt" != "$LIST_LOCALE" ]
  do
    title 'Environment > Locale Setup'
    wprintf '[+] Available locale options:'
    printf "\n
  1. Set a locale
  2. List available locales\n\n"
    wprintf "[?] Make a choice: "
    read -r locale_opt
    if [ "$locale_opt" = "$SET_LOCALE" ]
    then
      break
    elif [ "$locale_opt" = "$LIST_LOCALE" ]
    then
      less /etc/locale.gen
      echo
    else
      clear
      continue
    fi
    clear
  done

  clear

  return $SUCCESS
}


# set locale to use
set_locale()
{
  title 'Environment > Locale Setup'
  wprintf '[?] Set locale [en_US.UTF-8]: '
  read -r LOCALE

  # default locale
  if [ -z "$LOCALE" ]
  then
    echo
    warn 'Setting default locale: en_US.UTF-8'
    sleep 1
    LOCALE='en_US.UTF-8'
  fi
  localectl set-locale "LANG=$LOCALE"
  check $? 'setting locale'

  return $SUCCESS
}


# ask for keymap to use
ask_keymap()
{
  while [ "$keymap_opt" != "$SET_KEYMAP" ] && \
    [ "$keymap_opt" != "$LIST_KEYMAP" ]
  do
    title 'Environment > Keymap Setup'
    wprintf '[+] Available keymap options:'
    printf "\n
  1. Set a keymap
  2. List available keymaps\n\n"
    wprintf '[?] Make a choice: '
    read -r keymap_opt

    if [ "$keymap_opt" = "$SET_KEYMAP" ]
    then
      break
    elif [ "$keymap_opt" = "$LIST_KEYMAP" ]
    then
      localectl list-keymaps
      echo
    else
      clear
      continue
    fi
    clear
  done

  clear

  return $SUCCESS
}


# set keymap to use
set_keymap()
{
  title 'Environment > Keymap Setup'
  wprintf '[?] Set keymap [us]: '
  read -r KEYMAP

  # default keymap
  if [ -z "$KEYMAP" ]
  then
    echo
    warn 'Setting default keymap: us'
    sleep 1
    KEYMAP='us'
  fi
  localectl set-keymap --no-convert "$KEYMAP"
  loadkeys "$KEYMAP" > $VERBOSE 2>&1
  check $? 'setting keymap'

  return $SUCCESS
}


# enable multilib in pacman.conf if x86_64 present
enable_pacman_multilib()
{
  path="$1"

  if [ "$path" = 'chroot' ]
  then
    path="$CHROOT"
  else
    path=""
  fi

  title 'Pacman Setup > Multilib'

  if [ "$(uname -m)" = "x86_64" ]
  then
    wprintf '[+] Enabling multilib support'
    printf "\n\n"
    if grep -q "#\[multilib\]" "$path/etc/pacman.conf"
    then
      # it exists but commented
      sed -i '/\[multilib\]/{ s/^#//; n; s/^#//; }' "$path/etc/pacman.conf"
    elif ! grep -q "\[multilib\]" "$path/etc/pacman.conf"
    then
      # it does not exist at all
      printf "[multilib]\nInclude = /etc/pacman.d/mirrorlist\n" \
        >> "$path/etc/pacman.conf"
    fi
  fi

  return $SUCCESS
}


# enable color mode in pacman.conf
enable_pacman_color()
{
  path="$1"

  if [ "$path" = 'chroot' ]
  then
    path="$CHROOT"
  else
    path=""
  fi

  title 'Pacman Setup > Color'

  wprintf '[+] Enabling color mode'
  printf "\n\n"

  sed -i 's/^#Color/Color/' "$path/etc/pacman.conf"

  return $SUCCESS
}


# enable misc options in pacman.conf
enable_pacman_misc()
{
  path="$1"

  if [ "$path" = 'chroot' ]
  then
    path="$CHROOT"
  else
    path=""
  fi

  title 'Pacman Setup > Misc Options'

  wprintf '[+] Enabling DisableDownloadTimeout'
  printf "\n\n"
  sed -i '37a DisableDownloadTimeout' "$path/etc/pacman.conf"

  # put here more misc options if necessary

  return $SUCCESS
}


# update pacman package database
update_pkg_database()
{
  title 'Pacman Setup > Package Database'

  wprintf '[+] Updating pacman database'
  printf "\n\n"

  pacman -Syy --noconfirm > $VERBOSE 2>&1

  return $SUCCESS
}


# update pacman.conf and database
update_pacman()
{
  enable_pacman_multilib
  sleep_clear 1

  enable_pacman_color
  sleep_clear 1

  enable_pacman_misc
  sleep_clear 1

  update_pkg_database
  sleep_clear 1

  return $SUCCESS
}


# ask user for hostname
ask_hostname()
{
  while [ -z "$HOST_NAME" ]
  do
    title 'Network Setup > Hostname'
    wprintf '[?] Set your hostname: '
    read -r HOST_NAME
  done

  return $SUCCESS
}

# get available network interfaces
get_net_ifs()
{
  NET_IFS="$(ip -o link show | awk -F': ' '{print $2}' |grep -v 'lo')"

  return $SUCCESS
}


# ask user for network interface
ask_net_if()
{
  while true
  do
    title 'Network Setup > Network Interface'
    wprintf '[+] Available network interfaces:'
    printf "\n\n"
    for i in $NET_IFS
    do
      echo "    > $i"
    done
    echo
    wprintf '[?] Please choose a network interface: '
    read -r NET_IF
    if echo "$NET_IFS" | grep "\<$NET_IF\>" > /dev/null
    then
      clear
      break
    fi
    clear
  done

  return $SUCCESS
}


# ask for networking configuration mode
ask_net_conf_mode()
{
  while [ "$NET_CONF_MODE" != "$NET_CONF_AUTO" ] && \
    [ "$NET_CONF_MODE" != "$NET_CONF_WLAN" ] && \
    [ "$NET_CONF_MODE" != "$NET_CONF_MANUAL" ] && \
    [ "$NET_CONF_MODE" != "$NET_CONF_SKIP" ]
  do
    title 'Network Setup > Network Interface'
    wprintf '[+] Network interface configuration:'
    printf "\n
  1. Auto DHCP (use this for auto connect via dhcp on selected interface)
  2. WiFi WPA Setup (use if you need to connect to a wlan before)
  3. Manual (use this if you are 1337)
  4. Skip (use this if you are already connected)\n\n"
    wprintf "[?] Please choose a mode: "
    read -r NET_CONF_MODE
    clear
  done

  return $SUCCESS
}


# ask for network addresses
ask_net_addr()
{
  while [ "$HOST_IPV4" = "" ] || \
    [ "$GATEWAY" = "" ] || [ "$SUBNETMASK" = "" ] || \
    [ "$BROADCAST" = "" ] || [ "$NAMESERVER" = "" ]
  do
    title 'Network Setup > Network Configuration (manual)'
    wprintf "[+] Configuring network interface $NET_IF via USER: "
    printf "\n
  > Host ipv4
  > Gateway ipv4
  > Subnetmask
  > Broadcast
  > Nameserver
    \n"
    wprintf '[?] Host IPv4: '
    read -r HOST_IPV4
    wprintf '[?] Gateway IPv4: '
    read -r GATEWAY
    wprintf '[?] Subnetmask: '
    read -r SUBNETMASK
    wprintf '[?] Broadcast: '
    read -r BROADCAST
    wprintf '[?] Nameserver: '
    read -r NAMESERVER
    clear
  done

  return $SUCCESS
}


# manual network interface configuration
net_conf_manual()
{
  title 'Network Setup > Network Configuration (manual)'
  wprintf "[+] Configuring network interface '$NET_IF' manually: "
  printf "\n\n"

  ip addr flush dev "$NET_IF"
  ip link set "$NET_IF" up
  ip addr add "$HOST_IPV4/$SUBNETMASK" broadcast "$BROADCAST" dev "$NET_IF"
  ip route add default via "$GATEWAY"
  echo "nameserver $NAMESERVER" > /etc/resolv.conf

  return $SUCCESS
}


# auto (dhcp) network interface configuration
net_conf_auto()
{
  opts='-h noleak -i noleak -v ,noleak -I noleak -t 10'

  title 'Network Setup > Network Configuration (auto)'
  wprintf "[+] Configuring network interface '$NET_IF' via DHCP: "
  printf "\n\n"

  dhcpcd "$opts" -i "$NET_IF" > $VERBOSE 2>&1

  sleep 10

  return $SUCCESS
}


# ask for wlan data (ssid, wpa passphrase, etc.)
ask_wlan_data()
{
  while [ "$WLAN_SSID" = "" ] || [ "$WLAN_PASSPHRASE" = "" ]
  do
    title 'Network Setup > Network Configuration (WiFi)'
    wprintf "[+] Configuring network interface $NET_IF via W-LAN + DHCP: "
    printf "\n
  > W-LAN SSID
  > WPA Passphrase (will not echo)
    \n"
    wprintf "[?] W-LAN SSID: "
    read -r WLAN_SSID
    wprintf "[?] WPA Passphrase: "
    read -rs WLAN_PASSPHRASE
    clear
  done

  return $SUCCESS
}


# wifi and auto dhcp network interface configuration
net_conf_wlan()
{
  wpasup="$(mktemp)"
  dhcp_opts='-h noleak -i noleak -v ,noleak -I noleak -t 10'

  title 'Network Setup > Network Configuration (WiFi)'
  wprintf "[+] Configuring network interface $NET_IF via W-LAN + DHCP: "
  printf "\n\n"

  wpa_passphrase "$WLAN_SSID" "$WLAN_PASSPHRASE" > "$wpasup"
  wpa_supplicant -B -c "$wpasup" -i "$NET_IF" > $VERBOSE 2>&1

  warn 'We need to wait a bit for wpa_supplicant and dhcpcd'

  sleep 10

  dhcpcd "$dhcp_opts" -i "$NET_IF" > $VERBOSE 2>&1

  sleep 10

  return $SUCCESS
}


# check for internet connection
check_inet_conn()
{
  title 'Network Setup > Connection Check'
  wprintf '[+] Checking for Internet connection...'

  if ! curl -s http://www.yahoo.com/ > $VERBOSE
  then
    err 'No Internet connection! Check your network (settings).'
    exit $FAILURE
  fi

}


# ask user for dualboot install
ask_dualboot()
{
  while [ "$DUALBOOT" = '' ]
  do
    if confirm 'Hard Drive Setup > DualBoot' '[?] Install BlackArch Linux with Windows/Other OS [y/n]: '
    then
      DUALBOOT=$TRUE
    else
      DUALBOOT=$FALSE
    fi
  done
  return $SUCCESS
}


# ask user for luks encrypted partition
ask_luks()
{
  while [ "$LUKS" = '' ]
  do
    if confirm 'Hard Drive Setup > Crypto' '[?] Full encrypted root [y/n]: '
    then
      LUKS=$TRUE
    else
      LUKS=$FALSE
      echo
      warn 'The root partition will NOT be encrypted'
    fi
    sleep_clear 2
  done
  return $SUCCESS
}


# get available hard disks
get_hd_devs()
{
  HD_DEVS="$(lsblk | grep disk | awk '{print $1}')"

  return $SUCCESS
}


# ask user for device to format and setup
ask_hd_dev()
{
  while true
  do
    title 'Hard Drive Setup'

    wprintf '[+] Available hard drives for installation:'
    printf "\n\n"

    for i in $HD_DEVS
    do
      echo "    > ${i}"
    done
    echo
    wprintf '[?] Please choose a device: '
    read -r HD_DEV
    if echo "$HD_DEVS" | grep "\<$HD_DEV\>" > /dev/null
    then
      HD_DEV="/dev/$HD_DEV"
      clear
      break
    fi
    clear
  done


  return $SUCCESS
}

# get available partitions on hard drive
get_partitions()
{
  PARTITIONS=$(fdisk -l "${HD_DEV}" -o device,size,type | \
    grep "${HD_DEV}[[:alnum:]]" |awk '{print $1;}')

  return $SUCCESS
}


# ask user to create partitions using cfdisk
ask_cfdisk()
{
  if confirm 'Hard Drive Setup > Partitions' '[?] Create partitions with cfdisk (root and boot, optional swap) [y/n]: '
  then
    clear
    zero_part
  else
    echo
    warn 'No partitions chosed? Make sure you have them already configured.'
    get_partitions
  fi

  return $SUCCESS
}


# zero out partition if needed/chosen
zero_part()
{
  local zeroed_part=0;
  if confirm 'Hard Drive Setup' '[?] Start with an in-memory zeroed partition table [y/n]: '
  zeroed_part=1;
  then
    cfdisk -z "$HD_DEV"
    sync
  else
    cfdisk "$HD_DEV"
    sync
  fi
  get_partitions
  if [ ${#PARTITIONS[@]} -eq 0 ] && [ $zeroed_part -eq 1 ] ; then
    err 'You have not created partitions on your disk, make sure to write your changes before quiting cfdisk. Trying again...'
    zero_part
  fi
  if [ "$BOOT_MODE" = 'uefi' ] && ! fdisk -l "$HD_DEV" -o type | grep -i 'EFI' ; then
    err 'You are booting in UEFI mode but not EFI partition was created, make sure you select the "EFI System" type for your EFI partition.'
    zero_part
  fi
  return $SUCCESS
}


# get partition label
get_partition_label()
{
  PART_LABEL="$(fdisk -l "$HD_DEV" |grep "Disklabel" | awk '{print $3;}')"

  return $SUCCESS
}


# get partitions
ask_partitions()
{
  while [ "$BOOT_PART" = '' ] || \
    [ "$ROOT_PART" = '' ] || \
    [ "$BOOT_FS_TYPE" = '' ] || \
    [ "$ROOT_FS_TYPE" = '' ]
  do
    title 'Hard Drive Setup > Partitions'
    wprintf '[+] Created partitions:'
    printf "\n\n"

    fdisk -l "${HD_DEV}" -o device,size,type |grep "${HD_DEV}[[:alnum:]]"

    echo

    if [ "$BOOT_MODE" = 'uefi' ]  && [ "$PART_LABEL" = 'gpt' ]
    then
      while [ -z "$BOOT_PART" ]; do
        wprintf "[?] EFI System partition (${HD_DEV}X): "
        read -r BOOT_PART
        until [[ "$PARTITIONS" =~ $BOOT_PART ]]; do
          wprintf "[?] Your partition $BOOT_PART is not in the partitions list.\n"
          wprintf "[?] EFI System partition (${HD_DEV}X): "
          read -r BOOT_PART
        done
      done
      BOOT_FS_TYPE="fat"
    else
      while [ -z "$BOOT_PART" ]; do
        wprintf "[?] Boot partition (${HD_DEV}X): "
        read -r BOOT_PART
        until [[ "$PARTITIONS" =~ $BOOT_PART ]]; do
          wprintf "[?] Your partition $BOOT_PART is not in the partitions list.\n"
          wprintf "[?] Boot partition (${HD_DEV}X): "
          read -r BOOT_PART
        done
      done
      wprintf '[?] Choose a filesystem to use in your boot partition (ext2, ext3, ext4, fat)? (default: fat): '
      read -r BOOT_FS_TYPE
      if [ -z "$BOOT_FS_TYPE" ]; then
        BOOT_FS_TYPE="fat32"
      fi
    fi
    while [ -z "$ROOT_PART" ]; do
      wprintf "[?] Root partition (${HD_DEV}X): "
      read -r ROOT_PART
      until [[ "$PARTITIONS" =~ $ROOT_PART ]]; do
          wprintf "[?] Your partition $ROOT_PART is not in the partitions list.\n"
          wprintf "[?] Root partition (${HD_DEV}X): "
          read -r ROOT_PART
      done
    done
    wprintf '[?] Choose a filesystem to use in your root partition (ext2, ext3, ext4, btrfs)? (default: ext4): '
    read -r ROOT_FS_TYPE
    if [ -z "$ROOT_FS_TYPE" ]; then
      ROOT_FS_TYPE="ext4"
    fi
    wprintf "[?] Swap partition (${HD_DEV}X - empty for none): "
    read -r SWAP_PART
    if [ -n "$SWAP_PART" ]; then
        until [[ "$PARTITIONS" =~ $SWAP_PART ]]; do
          wprintf "[?] Your partition $SWAP_PART is not in the partitions list.\n"
          wprintf "[?] Swap partition (${HD_DEV}X): "
          read -r SWAP_PART
        done
    fi

    if [ "$SWAP_PART" = '' ]
    then
      SWAP_PART='none'
    fi
    clear
  done

  return $SUCCESS
}


# print partitions and ask for confirmation
print_partitions()
{
  i=""

  while true
  do
    title 'Hard Drive Setup > Partitions'
    wprintf '[+] Current Partition table'
    printf "\n
  > /boot   : %s (%s)
  > /       : %s (%s)
  > swap    : %s (swap)
  \n" "$BOOT_PART" "$BOOT_FS_TYPE" \
      "$ROOT_PART" "$ROOT_FS_TYPE" \
      "$SWAP_PART"
    wprintf '[?] Partition table correct [y/n]: '
    read -r i
    if [ "$i" = 'y' ] || [ "$i" = 'Y' ]
    then
      clear
      break
    elif [ "$i" = 'n' ] || [ "$i" = 'N' ]
    then
      echo
      err 'Hard Drive Setup aborted.'
      exit $FAILURE
    else
      clear
      continue
    fi
    clear
  done

  return $SUCCESS
}


# ask user and get confirmation for formatting
ask_formatting()
{
  if confirm 'Hard Drive Setup > Partition Formatting' '[?] Formatting partitions. Are you sure? No crying afterwards? [y/n]: '
  then
    return $SUCCESS
  else
    echo
    err 'Seriously? No formatting no fun! Please format to continue or CTRL + c to cancel...'
    ask_formatting
  fi

}


# create LUKS encrypted partition
make_luks_partition()
{
  part="$1"

  title 'Hard Drive Setup > Partition Creation (crypto)'

  wprintf '[+] Creating LUKS partition'
  printf "\n\n"

  cryptsetup -q -y -v luksFormat "$part" \
    > $VERBOSE 2>&1 || { err 'Could not LUKS format, trying again.'; make_luks_partition "$@"; }

}


# open LUKS partition
open_luks_partition()
{
  part="$1"
  name="$2"

  title 'Hard Drive Setup > Partition Creation (crypto)'

  wprintf '[+] Opening LUKS partition'
  printf "\n\n"
  cryptsetup open "$part" "$name" > $VERBOSE 2>&1 ||
    { err 'Could not open LUKS device, please try again and make sure that your password is correct.'; open_luks_partition "$@"; }

}


# create swap partition
make_swap_partition()
{
  title 'Hard Drive Setup > Partition Creation (swap)'

  wprintf '[+] Creating SWAP partition'
  printf "\n\n"
  mkswap $SWAP_PART > $VERBOSE 2>&1 || { err 'Could not create filesystem'; exit $FAILURE; }

}


# make and format root partition
make_root_partition()
{
  if [ $LUKS = $TRUE ]
  then
    make_luks_partition "$ROOT_PART"
    sleep_clear 1
    open_luks_partition "$ROOT_PART" "$CRYPT_ROOT"
    sleep_clear 1
    title 'Hard Drive Setup > Partition Creation (root crypto)'
    wprintf '[+] Creating encrypted ROOT partition'
    printf "\n\n"
    if [ "$ROOT_FS_TYPE" = 'btrfs' ]
    then
      mkfs.$ROOT_FS_TYPE -f "/dev/mapper/$CRYPT_ROOT" > $VERBOSE 2>&1 ||
        { err 'Could not create filesystem'; exit $FAILURE; }
    else
      mkfs.$ROOT_FS_TYPE -F "/dev/mapper/$CRYPT_ROOT" > $VERBOSE 2>&1 ||
        { err 'Could not create filesystem'; exit $FAILURE; }
    fi
    sleep_clear 1
  else
    title 'Hard Drive Setup > Partition Creation (root)'
    wprintf '[+] Creating ROOT partition'
    printf "\n\n"
    if [ "$ROOT_FS_TYPE" = 'btrfs' ]
    then
      mkfs.$ROOT_FS_TYPE -f "$ROOT_PART" > $VERBOSE 2>&1 ||
        { err 'Could not create filesystem'; exit $FAILURE; }
    else
      mkfs.$ROOT_FS_TYPE -F "$ROOT_PART" > $VERBOSE 2>&1 ||
        { err 'Could not create filesystem'; exit $FAILURE; }
    fi
    sleep_clear 1
  fi

  return $SUCCESS
}


# make and format boot partition
make_boot_partition()
{
  if [ "$BOOT_MODE" = 'uefi' ] && [ "$PART_LABEL" = 'gpt' ] && [ $DUALBOOT = $TRUE ]
  then
    return $SUCCESS
  fi

  title 'Hard Drive Setup > Partition Creation (boot)'

  wprintf '[+] Creating BOOT partition'
  printf "\n\n"
  if [ "$BOOT_MODE" = 'uefi' ] && [ "$PART_LABEL" = 'gpt' ]
  then
    mkfs.fat -F32 "$BOOT_PART" > $VERBOSE 2>&1 ||
      { err 'Could not create filesystem'; exit $FAILURE; }
  else
    mkfs.$BOOT_FS_TYPE -F32 "$BOOT_PART" > $VERBOSE 2>&1 ||
      { err 'Could not create filesystem'; exit $FAILURE; }
  fi

  return $SUCCESS
}


# make and format partitions
make_partitions()
{
  make_boot_partition
  sleep_clear 1

  make_root_partition
  sleep_clear 1

  if [ "$SWAP_PART" != "none" ]
  then
    make_swap_partition
    sleep_clear 1
  fi

  return $SUCCESS
}


# mount filesystems
mount_filesystems()
{
  title 'Hard Drive Setup > Mount'

  wprintf '[+] Mounting filesystems'
  printf "\n\n"

  # ROOT
  if [ $LUKS = $TRUE ]; then
    if ! mount "/dev/mapper/$CRYPT_ROOT" $CHROOT; then
      err "Error mounting root filesystem, leaving."
      exit $FAILURE
    fi
  else
    if ! mount "$ROOT_PART" $CHROOT; then
      err "Error mounting root filesystem, leaving."
      exit $FAILURE
    fi
  fi

  # BOOT
  mkdir "$CHROOT/boot" > $VERBOSE 2>&1
  if ! mount "$BOOT_PART" "$CHROOT/boot"; then
    err "Error mounting boot partition, leaving."
    exit $FAILURE
  fi

  # SWAP
  if [ "$SWAP_PART" != "none" ]
  then
    swapon $SWAP_PART > $VERBOSE 2>&1
  fi

  return $SUCCESS
}


# unmount filesystems
umount_filesystems()
{
  routine="$1"

  if [ "$routine" = 'harddrive' ]
  then
    title 'Hard Drive Setup > Unmount'

    wprintf '[+] Unmounting filesystems'
    printf "\n\n"

    umount -Rf /mnt > /dev/null 2>&1; \
    umount -Rf "$HD_DEV"{1..128} > /dev/null 2>&1 # gpt max - 128
  else
    title 'Game Over'

    wprintf '[+] Unmounting filesystems'
    printf "\n\n"

    umount -Rf $CHROOT > /dev/null 2>&1
    cryptsetup luksClose "$CRYPT_ROOT" > /dev/null 2>&1
    swapoff $SWAP_PART > /dev/null 2>&1
  fi

  return $SUCCESS
}


# check for necessary space
check_space()
{
  if [ $LUKS -eq $TRUE ]
  then
    avail_space=$(df -m | grep "/dev/mapper/$CRYPT_ROOT" | awk '{print $4}')
  else
    avail_space=$(df -m | grep "$ROOT_PART" | awk '{print $4}')
  fi

  if [ "$avail_space" -le 40960 ]
  then
    warn 'BlackArch Linux requires at least 40 GB of free space to install!'
  fi

  return $SUCCESS
}


# install ArchLinux base and base-devel packages
install_base_packages()
{
  title 'Base System Setup > ArchLinux Packages'

  wprintf '[+] Installing ArchLinux base packages'
  printf "\n\n"
  warn 'This can take a while, please wait...'
  printf "\n"

  pacstrap $CHROOT base base-devel btrfs-progs linux linux-firmware \
    terminus-font terminus-font-ttf > $VERBOSE 2>&1
  chroot $CHROOT pacman -Syy --noconfirm --overwrite='*' > $VERBOSE 2>&1

  return $SUCCESS
}


# setup /etc/resolv.conf
setup_resolvconf()
{
  title 'Base System Setup > Etc'

  wprintf '[+] Setting up /etc/resolv.conf'
  printf "\n\n"

  mkdir -p "$CHROOT/etc/" > $VERBOSE 2>&1
  cp -L /etc/resolv.conf "$CHROOT/etc/resolv.conf" > $VERBOSE 2>&1

  return $SUCCESS
}


# setup fstab
setup_fstab()
{
  title 'Base System Setup > Etc'

  wprintf '[+] Setting up /etc/fstab'
  printf "\n\n"

  if [ "$PART_LABEL" = "gpt" ]
  then
    genfstab -U $CHROOT >> "$CHROOT/etc/fstab"
  else
    genfstab -L $CHROOT >> "$CHROOT/etc/fstab"
  fi

  sed 's/relatime/noatime/g' -i "$CHROOT/etc/fstab"

  return $SUCCESS
}


# setup locale and keymap
setup_locale()
{
  title 'Base System Setup > Locale'

  wprintf "[+] Setting up $LOCALE locale"
  printf "\n\n"
  sed -i "s/^#en_US.UTF-8/en_US.UTF-8/" "$CHROOT/etc/locale.gen"
  sed -i "s/^#$LOCALE/$LOCALE/" "$CHROOT/etc/locale.gen"
  chroot $CHROOT locale-gen > $VERBOSE 2>&1
  echo "LANG=$LOCALE" > "$CHROOT/etc/locale.conf"
  echo "KEYMAP=$KEYMAP" > "$CHROOT/etc/vconsole.conf"

  return $SUCCESS
}


# setup timezone
setup_time()
{
  if confirm 'Base System Setup > Timezone' '[?] Default: UTC. Choose other timezone [y/n]: '
  then
    for t in $(timedatectl list-timezones)
    do
      echo "    > $t"
    done

    wprintf "\n[?] What is your (Zone/SubZone): "
    read -r timezone
    chroot $CHROOT ln -sf "/usr/share/zoneinfo/$timezone" /etc/localtime \
      > $VERBOSE 2>&1

    if [ $? -eq 1 ]
    then
      warn 'Do you live on Mars? Setting default time zone...'
      sleep 1
      default_time
    else
      wprintf "\n[+] Time zone setup correctly\n"
    fi
  else
    wprintf "\n[+] Setting up default time and timezone\n"
    sleep 2
    default_time
  fi

  printf "\n"

  return $SUCCESS
}


# default time and timezone
default_time()
{
  echo
  warn 'Setting up default time and timezone: UTC'
  printf "\n\n"
  chroot $CHROOT ln -sf /usr/share/zoneinfo/UTC /etc/localtime > $VERBOSE 2>&1

  return $SUCCESS
}


# setup initramfs
setup_initramfs()
{
  title 'Base System Setup > InitramFS'

  wprintf '[+] Setting up InitramFS'
  printf "\n\n"

  cp -f "$BI_PATH/data/etc/mkinitcpio.conf" "$CHROOT/etc/mkinitcpio.conf"
  cp -fr "$BI_PATH/data/etc/mkinitcpio.d" "$CHROOT/etc/"

  if [ "$INSTALL_MODE" = "$INSTALL_FULL_ISO" ]
  then
    cp /run/archiso/bootmnt/blackarch/boot/x86_64/vmlinuz-linux \
      "$CHROOT/boot/vmlinuz-linux"
  fi

  # terminus font
  sed -i 's/keyboard fsck/keyboard fsck consolefont/g' \
    "$CHROOT/etc/mkinitcpio.conf"
  echo 'FONT=ter-114n' >> "$CHROOT/etc/vconsole.conf"

  if [ $LUKS = $TRUE ]
  then
    sed -i 's/block filesystems/block keymap encrypt filesystems/g' \
      "$CHROOT/etc/mkinitcpio.conf"
  fi

  warn 'This can take a while, please wait...'
  printf "\n"
  chroot $CHROOT mkinitcpio -P > $VERBOSE 2>&1

  return $SUCCESS
}


# mount /proc, /sys and /dev
setup_proc_sys_dev()
{
  title 'Base System Setup > Proc Sys Dev'

  wprintf '[+] Setting up /proc, /sys and /dev'
  printf "\n\n"

  mkdir -p "${CHROOT}/"{proc,sys,dev} > $VERBOSE 2>&1

  mount -t proc proc "$CHROOT/proc" > $VERBOSE 2>&1
  mount --rbind /sys "$CHROOT/sys" > $VERBOSE 2>&1
  mount --make-rslave "$CHROOT/sys" > $VERBOSE 2>&1
  mount --rbind /dev "$CHROOT/dev" > $VERBOSE 2>&1
  mount --make-rslave "$CHROOT/dev" > $VERBOSE 2>&1

  return $SUCCESS
}


# setup hostname
setup_hostname()
{
  title 'Base System Setup > Hostname'

  wprintf '[+] Setting up hostname'
  printf "\n\n"

  echo "$HOST_NAME" > "$CHROOT/etc/hostname"

  return $SUCCESS
}


# setup boot loader for UEFI/GPT or BIOS/MBR
setup_bootloader()
{
  title 'Base System Setup > Boot Loader'

  if [ "$BOOT_MODE" = 'uefi' ] && [ "$PART_LABEL" = 'gpt' ]
  then
    wprintf '[+] Setting up EFI boot loader'
    printf "\n\n"

    chroot $CHROOT bootctl install > $VERBOSE 2>&1
    uuid="$(blkid "$ROOT_PART" | cut -d ' ' -f 2 | cut -d '"' -f 2)"

    if [ $LUKS = $TRUE ]
    then
      cat >> "$CHROOT/boot/loader/entries/arch.conf" << EOF
title   BlackArch Linux
linux   /vmlinuz-linux
initrd    /initramfs-linux.img
options   cryptdevice=UUID=$uuid:$CRYPT_ROOT root=/dev/mapper/$CRYPT_ROOT rw
EOF

    else
      cat >> "$CHROOT/boot/loader/entries/arch.conf" << EOF
title   BlackArch Linux
linux   /vmlinuz-linux
initrd    /initramfs-linux.img
options   root=UUID=$uuid rw
EOF
    fi
  else
    wprintf '[+] Setting up GRUB boot loader'
    printf "\n\n"

    uuid="$(lsblk -o UUID "$ROOT_PART" | sed -n 2p)"

    if [ "$INSTALL_MODE" != "$INSTALL_FULL_ISO" ]
    then
      chroot $CHROOT pacman -S grub --noconfirm --overwrite='*' --needed \
        > $VERBOSE 2>&1
    else
      mkdir -p "$CHROOT/boot/grub"
    fi

    if [ $DUALBOOT = $TRUE ]
    then
      chroot $CHROOT pacman -S os-prober --noconfirm --overwrite='*' --needed \
        > $VERBOSE 2>&1
    fi

    if [ $LUKS = $TRUE ]
    then
      sed -i "s|quiet|cryptdevice=UUID=$uuid:$CRYPT_ROOT root=/dev/mapper/$CRYPT_ROOT quiet|" \
        "$CHROOT/etc/default/grub"
    fi
    sed -i 's/Arch/BlackArch/g' "$CHROOT/etc/default/grub"
    echo "GRUB_BACKGROUND=\"/boot/grub/splash.png\"" >> \
      "$CHROOT/etc/default/grub"

    sed -i 's/#GRUB_COLOR_/GRUB_COLOR_/g' "$CHROOT/etc/default/grub"

    chroot $CHROOT grub-install --target=i386-pc "$HD_DEV" > $VERBOSE 2>&1

    cp -f "$BI_PATH/data/boot/grub/splash.png" "$CHROOT/boot/grub/splash.png"

    chroot $CHROOT grub-mkconfig -o /boot/grub/grub.cfg > $VERBOSE 2>&1

  fi

  return $SUCCESS
}


# ask for normal user account to setup
ask_user_account()
{
  if confirm 'Base System Setup > User' '[?] Setup a normal user account [y/n]: '
  then
    wprintf '[?] User name: '
    read -r NORMAL_USER
  fi

  return $SUCCESS
}


# setup blackarch test user (not active + lxdm issue)
setup_testuser()
{
  title 'Base System Setup > Test User'

  wprintf '[+] Setting up test user blackarchtest account'
  printf "\n\n"
  warn 'Remove this user after you added a normal system user account'
  printf "\n"

  chroot $CHROOT groupadd blackarchtest > $VERBOSE 2>&1
  chroot $CHROOT useradd -g blackarchtest -d /home/blackarchtest/ \
    -s /sbin/nologin -m blackarchtest > $VERBOSE 2>&1
}


# setup user account, password and environment
setup_user()
{
  user="$(echo "$1" | tr -dc '[:alnum:]_' | tr '[:upper:]' '[:lower:]' |
    cut -c 1-32)"

  title 'Base System Setup > User'

  wprintf "[+] Setting up $user account"
  printf "\n\n"

  # normal user
  if [ -n "$NORMAL_USER" ]
  then
    chroot $CHROOT groupadd "$user" > $VERBOSE 2>&1
    chroot $CHROOT useradd -g "$user" -d "/home/$user" -s "/bin/bash" \
      -G "$user,wheel,users,video,audio" -m "$user" > $VERBOSE 2>&1
    chroot $CHROOT chown -R "$user":"$user" "/home/$user" > $VERBOSE 2>&1
    wprintf "[+] Added user: $user"
    printf "\n\n"
  # environment
  elif [ -z "$NORMAL_USER" ]
  then
    cp -r "$BI_PATH/data/root/." "$CHROOT/root/." > $VERBOSE 2>&1
  else
    cp -r "$BI_PATH/data/user/." "$CHROOT/home/$user/." > $VERBOSE 2>&1
    chroot $CHROOT chown -R "$user":"$user" "/home/$user" > $VERBOSE 2>&1
  fi

  # password
  res=1337
  wprintf "[?] Set password for $user: "
  printf "\n\n"
  while [ $res -ne 0 ]
  do
    if [ "$user" = "root" ]
    then
      chroot $CHROOT passwd
    else
      chroot $CHROOT passwd "$user"
    fi
    res=$?
  done

  return $SUCCESS
}

reinitialize_keyring()
{
  title 'Base System Setup > Keyring Reinitialization'

  wprintf '[+] Reinitializing keyrings'
  printf "\n"
  sleep 2

  chroot $CHROOT pacman -S --overwrite='*' --noconfirm archlinux-keyring \
    > $VERBOSE 2>&1

  return $SUCCESS
}

# install extra (missing) packages
setup_extra_packages()
{
  arch='arch-install-scripts pkgfile'

  bluetooth='bluez bluez-hid2hci bluez-tools bluez-utils'

  browser='chromium elinks firefox'

  editor='hexedit nano vim'

  filesystem='cifs-utils dmraid dosfstools exfat-utils f2fs-tools
  gpart gptfdisk mtools nilfs-utils ntfs-3g partclone parted partimage'

  fonts='ttf-dejavu ttf-indic-otf ttf-liberation xorg-fonts-misc'

  hardware='amd-ucode intel-ucode'

  kernel='linux-headers'

  misc='acpi alsa-utils b43-fwcutter bash-completion bc cmake ctags expac
  feh git gpm haveged hdparm htop inotify-tools ipython irssi
  linux-atm lsof mercurial mesa mlocate moreutils mpv p7zip rsync
  rtorrent screen scrot smartmontools strace tmux udisks2 unace unrar
  unzip upower usb_modeswitch usbutils zip zsh'

  network='atftp bind-tools bridge-utils curl darkhttpd dhclient dhcpcd dialog
  dnscrypt-proxy dnsmasq dnsutils fwbuilder gnu-netcat ipw2100-fw ipw2200-fw iw
  iwd lftp nfs-utils ntp openconnect openssh openvpn ppp pptpclient rfkill
  rp-pppoe socat vpnc wget wireless_tools wpa_supplicant wvdial xl2tpd'

  xorg='rxvt-unicode xf86-video-amdgpu xf86-video-ati
  xf86-video-dummy xf86-video-fbdev xf86-video-intel xf86-video-nouveau
  xf86-video-openchrome xf86-video-sisusb xf86-video-vesa xf86-video-vmware
  xf86-video-voodoo xorg-server xorg-xbacklight xorg-xinit xterm'

  all="$arch $bluetooth $browser $editor $filesystem $fonts $hardware $kernel"
  all="$all $misc $network $xorg"

  title 'Base System Setup > Extra Packages'

  wprintf '[+] Installing extra packages'
  printf "\n"

  printf "
  > ArchLinux   : $(echo "$arch" | wc -w) packages
  > Browser     : $(echo "$browser" | wc -w) packages
  > Bluetooth   : $(echo "$bluetooth" | wc -w) packages
  > Editor      : $(echo "$editor" | wc -w) packages
  > Filesystem  : $(echo "$filesystem" | wc -w) packages
  > Fonts       : $(echo "$fonts" | wc -w) packages
  > Hardware    : $(echo "$hardware" | wc -w) packages
  > Kernel      : $(echo "$kernel" | wc -w) packages
  > Misc        : $(echo "$misc" | wc -w) packages
  > Network     : $(echo "$network" | wc -w) packages
  > Xorg        : $(echo "$xorg" | wc -w) packages
  \n"

  warn 'This can take a while, please wait...'
  printf "\n"
  sleep 2

  chroot $CHROOT pacman -S --needed --overwrite='*' --noconfirm $all \
    > $VERBOSE 2>&1

  return $SUCCESS
}


# perform system base setup/configurations
setup_base_system()
{
  if [ "$INSTALL_MODE" = "$INSTALL_FULL_ISO" ]
  then
    dump_full_iso
    sleep_clear 1
  fi

  if [ "$INSTALL_MODE" != "$INSTALL_FULL_ISO" ]
  then
    pass_mirror_conf # copy mirror list to chroot env

    setup_resolvconf
    sleep_clear 1

    install_base_packages
    sleep_clear 1

    setup_resolvconf
    sleep_clear 1
  fi

  setup_fstab
  sleep_clear 1

  setup_proc_sys_dev
  sleep_clear 1

  setup_locale
  sleep_clear 1

  setup_initramfs
  sleep_clear 1

  setup_hostname
  sleep_clear 1

  setup_user "root"
  sleep_clear 1

  ask_user_account
  sleep_clear 1

  if [ -n "$NORMAL_USER" ]
  then
    setup_user "$NORMAL_USER"
    sleep_clear 1
  else
    setup_testuser
    sleep_clear 2
  fi

  if [ "$INSTALL_MODE" != "$INSTALL_FULL_ISO" ]
  then
    reinitialize_keyring
    sleep_clear 1
    setup_extra_packages
    sleep_clear 1
  fi

  setup_bootloader
  sleep_clear 1

  return $SUCCESS
}


# enable systemd-networkd services
enable_iwd_networkd()
{
  title 'BlackArch Linux Setup > Network'

  wprintf '[+] Enabling Iwd and Networkd'
  printf "\n\n"

  chroot $CHROOT systemctl enable iwd systemd-networkd > $VERBOSE 2>&1

  return $SUCCESS
}


# update /etc files and set up iptables
update_etc()
{
  title 'BlackArch Linux Setup > Etc files'

  wprintf '[+] Updating /etc files'
  printf "\n\n"

  # /etc/*
  cp -r "$BI_PATH/data/etc/"{arch-release,issue,motd,\
os-release,sysctl.d,systemd} "$CHROOT/etc/." > $VERBOSE 2>&1

  return $SUCCESS
}


# ask for blackarch linux mirror
ask_mirror()
{
  title 'BlackArch Linux Setup > BlackArch Mirror'

  local IFS='|'
  count=1
  mirror_url='https://raw.githubusercontent.com/BlackArch/blackarch/master/mirror/mirror.lst'
  mirror_file='/tmp/mirror.lst'

  wprintf '[+] Fetching mirror list'
  printf "\n\n"
  curl -s -o $mirror_file $mirror_url > $VERBOSE

  while read -r country url mirror_name
  do
    wprintf " %s. %s - %s" "$count" "$country" "$mirror_name"
    printf "\n"
    wprintf "   * %s" "$url"
    printf "\n"
    count=$((count + 1))
  done < "$mirror_file"

  printf "\n"
  wprintf '[?] Select a mirror number (enter for default): '
  read -r a
  printf "\n"

  # bugfix: detected chars added sometimes - clear chars
  _a=$(printf "%s" "$a" | sed 's/[a-z]//Ig' 2> /dev/null)

  if [ -z "$_a" ]
  then
    wprintf "[+] Choosing default mirror: %s " $BA_REPO_URL
  else
    BA_REPO_URL=$(sed -n "${_a}p" $mirror_file | cut -d "|" -f 2)
    wprintf "[+] Mirror from '%s' selected" \
      "$(sed -n "${_a}p" $mirror_file | cut -d "|" -f 3)"
    printf "\n\n"
  fi

  rm -f $mirror_file

  return $SUCCESS
}

# ask for archlinux server
ask_mirror_arch()
{
  local mirrold='cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup'

  if confirm 'Pacman Setup > ArchLinux Mirrorlist' \
    "[+] Worldwide mirror will be used\n\n[?] Look for the best server [y/n]: "
  then
    printf "\n"
    warn 'This may take time depending on your connection'
    printf "\n"
    $mirrold
    pacman -Sy --noconfirm > $VERBOSE 2>&1
    pacman -S --needed --noconfirm reflector > $VERBOSE 2>&1
    yes | pacman -Scc > $VERBOSE 2>&1
    reflector --verbose --latest 5 --protocol https --sort rate \
      --save /etc/pacman.d/mirrorlist > $VERBOSE 2>&1
  else
    printf "\n"
    warn 'Using Worldwide mirror server'
    $mirrold
    echo -e "## Arch Linux repository Worldwide mirrorlist\n\n" \
      > /etc/pacman.d/mirrorlist

    for wore in $AR_REPO_URL
    do
      echo "Server = $wore" >> /etc/pacman.d/mirrorlist
    done
  fi

}

# pass correct config
pass_mirror_conf()
{
  mkdir -p "$CHROOT/etc/pacman.d/" > $VERBOSE 2>&1
  cp -f /etc/pacman.d/mirrorlist "$CHROOT/etc/pacman.d/mirrorlist" \
    > $VERBOSE 2>&1
}


# run strap.sh
run_strap_sh()
{
  strap_sh='/tmp/strap.sh'
  orig_sha1="$(curl -s https://blackarch.org/checksums/strap | awk '{print $1}')"

  title 'BlackArch Linux Setup > Strap'

  wprintf '[+] Downloading and executing strap.sh'
  printf "\n\n"
  warn 'This can take a while, please wait...'
  printf "\n"

  curl -s -o $strap_sh 'https://www.blackarch.org/strap.sh' > $VERBOSE 2>&1
  sha1="$(sha1sum $strap_sh | awk '{print $1}')"

  if [ "$sha1" = "$orig_sha1" ]
  then
    mv $strap_sh "${CHROOT}${strap_sh}"
    chmod a+x "${CHROOT}${strap_sh}"
    chroot $CHROOT echo "$BA_REPO_URL" | sh ${CHROOT}${strap_sh} > $VERBOSE 2>&1
  else
    { err "Wrong SHA1 sum for strap.sh: $sha1 (orig: $orig_sha1). Aborting!"; exit $FAILURE; }
  fi

  # add blackarch linux mirror if we are in chroot
  if ! grep -q 'blackarch' "$CHROOT/etc/pacman.conf"
  then
    printf '[blackarch]\nServer = %s\n' "$BA_REPO_URL" \
      >> "$CHROOT/etc/pacman.conf"
  else
    sed -i "/\[blackarch\]/{ n;s?Server.*?Server = $BA_REPO_URL?; }" \
      "$CHROOT/etc/pacman.conf"
  fi

  return $SUCCESS
}


# ask user for X (display + window manager) setup
ask_x_setup()
{
  if confirm 'BlackArch Linux Setup > X11' '[?] Setup X11 + window managers [y/n]: '
  then
    X_SETUP=$TRUE
    printf "\n"
    printf "${BLINK}NOOB! NOOB! NOOB! NOOB! NOOB! NOOB! NOOB!${NC}\n\n"
  fi

  return $SUCCESS
}


# setup display manager
setup_display_manager()
{
  title 'BlackArch Linux Setup > Display Manager'

  wprintf '[+] Setting up LXDM'
  printf "\n\n"

  # install lxdm packages
  chroot $CHROOT pacman -S lxdm --needed --overwrite='*' --noconfirm \
    > $VERBOSE 2>&1

  # config files
  cp -r "$BI_PATH/data/etc/X11" "$CHROOT/etc/."
  cp -r "$BI_PATH/data/etc/xprofile" "$CHROOT/etc/."
  cp -r "$BI_PATH/data/etc/lxdm/." "$CHROOT/etc/lxdm/."
  cp -r "$BI_PATH/data/usr/share/lxdm/." "$CHROOT/usr/share/lxdm/."
  cp -r "$BI_PATH/data/usr/share/gtk-2.0/." "$CHROOT/usr/share/gtk-2.0/."
  mkdir -p "$CHROOT/usr/share/xsessions"

  # enable in systemd
  chroot $CHROOT systemctl enable lxdm > $VERBOSE 2>&1

  return $SUCCESS
}


# setup window managers
setup_window_managers()
{
  title 'BlackArch Linux Setup > Window Managers'

  wprintf '[+] Setting up window managers'
  printf "\n\n"

  while true
  do
    printf "
  1. Awesome
  2. Fluxbox
  3. I3-wm
  4. Openbox
  5. Spectrwm
  6. All of the above
  \n"
    wprintf '[?] Choose an option [6]: '
    read -r choice
    echo
    case $choice in
      1)
        chroot $CHROOT pacman -S awesome --needed --overwrite='*' --noconfirm \
          > $VERBOSE 2>&1
        cp -r "$BI_PATH/data/etc/xdg/awesome/." "$CHROOT/etc/xdg/awesome/."
        cp -r "$BI_PATH/data/usr/share/awesome/." "$CHROOT/usr/share/awesome/."
        # fix bullshit exit() issue
        sed -i 's|local visible, action = cmd(item, self)|local visible, action = cmd(0, 0)|' \
          "$CHROOT/usr/share/awesome/lib/awful/menu.lua"
        cp -r "$BI_PATH/data/usr/share/xsessions/awesome.desktop" "$CHROOT/usr/share/xsessions"
        break
        ;;
      2)
        chroot $CHROOT pacman -S fluxbox --needed --overwrite='*' --noconfirm \
          > $VERBOSE 2>&1
        cp -r "$BI_PATH/data/usr/share/fluxbox/." "$CHROOT/usr/share/fluxbox/."
        cp -r "$BI_PATH/data/usr/share/xsessions/fluxbox.desktop" "$CHROOT/usr/share/xsessions"
        break
        ;;
      3)
        chroot $CHROOT pacman -S i3 dmenu rofi --needed --overwrite='*' \
          --noconfirm > $VERBOSE 2>&1
        cp -r "$BI_PATH/data/root/"{.config,.i3status.conf} "$CHROOT/root/."
        cp -r "$BI_PATH/data/usr/share/xsessions/i3.desktop" "$CHROOT/usr/share/xsessions"
        break
        ;;
      4)
        chroot $CHROOT pacman -S openbox --needed --overwrite='*' --noconfirm \
          > $VERBOSE 2>&1
        cp -r "$BI_PATH/data/etc/xdg/openbox/." "$CHROOT/etc/xdg/openbox/."
        cp -r "$BI_PATH/data/usr/share/themes/blackarch" \
          "$CHROOT/usr/share/themes/i3lock/."
        cp -r "$BI_PATH/data/usr/share/xsessions/openbox.desktop" "$CHROOT/usr/share/xsessions"
        break
        ;;
      5)
        chroot $CHROOT pacman -S spectrwm --needed --overwrite='*' --noconfirm \
          > $VERBOSE 2>&1
        cp -r "$BI_PATH/data/etc/spectrwm.conf" "$CHROOT/etc/spectrwm.conf"
        cp -r "$BI_PATH/data/usr/share/xsessions/spectrwm.desktop" "$CHROOT/usr/share/xsessions"
        break
        ;;
      *)
        chroot $CHROOT pacman -S fluxbox openbox awesome i3 spectrwm --needed \
          --overwrite='*' --noconfirm > $VERBOSE 2>&1

        # awesome
        cp -r "$BI_PATH/data/etc/xdg/awesome/." "$CHROOT/etc/xdg/awesome/."
        cp -r "$BI_PATH/data/usr/share/awesome/." "$CHROOT/usr/share/awesome/."
        sed -i 's|local visible, action = cmd(item, self)|local visible, action = cmd(0, 0)|' \
          "$CHROOT/usr/share/awesome/lib/awful/menu.lua"

        # fluxbox
        cp -r "$BI_PATH/data/usr/share/fluxbox/." "$CHROOT/usr/share/fluxbox/."

        # i3
        cp -r "$BI_PATH/data/root/"{.config,.i3status.conf} "$CHROOT/root/."

        # openbox
        cp -r "$BI_PATH/data/etc/xdg/openbox/." "$CHROOT/etc/xdg/openbox/."
        cp -r "$BI_PATH/data/usr/share/themes/blackarch" \
          "$CHROOT/usr/share/themes/."

        # spectrwm
        cp -r "$BI_PATH/data/etc/spectrwm.conf" "$CHROOT/etc/spectrwm.conf"

        # xsessions
        cp -r "$BI_PATH/data/usr/share/xsessions" "$CHROOT/usr/share/xsessions"

        break
        ;;
    esac
  done

  # wallpaper
  cp -r "$BI_PATH/data/usr/share/blackarch" "$CHROOT/usr/share/blackarch"

  # remove wrong xsession entries
  chroot $CHROOT rm /usr/share/xsessions/openbox-kde.desktop > $VERBOSE 2>&1
  chroot $CHROOT rm /usr/share/xsessions/i3-with-shmlog.desktop > $VERBOSE 2>&1

  return $SUCCESS
}


# ask user for VirtualBox modules+utils setup
ask_vbox_setup()
{
  if confirm 'BlackArch Linux Setup > VirtualBox' '[?] Setup VirtualBox modules [y/n]: '
  then
    VBOX_SETUP=$TRUE
  fi

  return $SUCCESS
}


# setup virtualbox utils
setup_vbox_utils()
{
  title 'BlackArch Linux Setup > VirtualBox'

  wprintf '[+] Setting up VirtualBox utils'
  printf "\n\n"

  chroot $CHROOT pacman -S virtualbox-guest-utils --overwrite='*' --needed \
    --noconfirm > $VERBOSE 2>&1

  chroot $CHROOT systemctl enable vboxservice > $VERBOSE 2>&1

  #printf "vboxguest\nvboxsf\nvboxvideo\n" \
  #  > "$CHROOT/etc/modules-load.d/vbox.conf"

  cp -r "$BI_PATH/data/etc/xdg/autostart/vboxclient.desktop" \
    "$CHROOT/etc/xdg/autostart/." > $VERBOSE 2>&1

  return $SUCCESS
}


# ask user for VirtualBox modules+utils setup
ask_vmware_setup()
{
  if confirm 'BlackArch Linux Setup > VMware' '[?] Setup VMware modules [y/n]: '
  then
    VMWARE_SETUP=$TRUE
  fi

  return $SUCCESS
}


# setup vmware utils
setup_vmware_utils()
{
  title 'BlackArch Linux Setup > VMware'

  wprintf '[+] Setting up VMware utils'
  printf "\n\n"

  chroot $CHROOT pacman -S open-vm-tools xf86-video-vmware \
    xf86-input-vmmouse --overwrite='*' --needed --noconfirm \
    > $VERBOSE 2>&1

  chroot $CHROOT systemctl enable vmware-vmblock-fuse.service > $VERBOSE 2>&1
  chroot $CHROOT systemctl enable vmtoolsd.service > $VERBOSE 2>&1

  return $SUCCESS
}


# ask user for BlackArch tools setup
ask_ba_tools_setup()
{
  if confirm 'BlackArch Linux Setup > Tools' '[?] Setup BlackArch Linux tools [y/n]: '
  then
    BA_TOOLS_SETUP=$TRUE
  fi

  return $SUCCESS
}


# setup blackarch tools from repository (binary) or via blackman (source)
setup_blackarch_tools()
{
  foo=5

  if [ "$VERBOSE" = '/dev/null' ]
  then
    noconfirm='--noconfirm'
  fi

  title 'BlackArch Linux Setup > Tools'

  wprintf '[+] Installing BlackArch Linux packages (grab a coffee)'
  printf "\n\n"

  if [ "$INSTALL_MODE" = $INSTALL_REPO ]
  then
    wprintf "[+] All available BlackArch tools groups:\n\n"
    printf "    > blackarch blackarch-anti-forensic blackarch-automation
    > blackarch-backdoor blackarch-binary blackarch-bluetooth blackarch-code-audit
    > blackarch-cracker blackarch-crypto blackarch-database blackarch-debugger
    > blackarch-decompiler blackarch-defensive blackarch-disassembler
    > blackarch-dos blackarch-drone blackarch-exploitation blackarch-fingerprint
    > blackarch-firmware blackarch-forensic blackarch-fuzzer blackarch-hardware
    > blackarch-honeypot blackarch-ids blackarch-keylogger blackarch-malware
    > blackarch-misc blackarch-mobile blackarch-networking blackarch-nfc
    > blackarch-packer blackarch-proxy blackarch-recon blackarch-reversing
    > blackarch-scanner blackarch-sniffer blackarch-social blackarch-spoof
    > blackarch-threat-model blackarch-tunnel blackarch-unpacker blackarch-voip
    > blackarch-webapp blackarch-windows blackarch-wireless \n\n"
    wprintf "[?] BlackArch groups to install (space for multiple) [blackarch]: "
    read -r BA_GROUPS
    printf "\n"
    warn 'This can take a while, please wait...'
    if [ -z "$BA_GROUPS" ]
    then
      printf "\n"
      check_space
      printf "\n\n"
      chroot $CHROOT pacman -S --needed --noconfirm --overwrite='*' blackarch \
        > $VERBOSE 2>&1
    else
      chroot $CHROOT pacman -S --needed --noconfirm --overwrite='*' "$BA_GROUPS" \
        > $VERBOSE 2>&1
    fi
  else
    warn 'Installing all tools from source via blackman can take hours'
    printf "\n"
    wprintf '[+] <Control-c> to abort ... '
    while [ $foo -gt 0 ]
    do
      wprintf "$foo "
      sleep 1
      foo=$((foo - 1))
    done
    printf "\n"
    chroot $CHROOT pacman -S --needed --overwrite='*' $noconfirm blackman \
      > $VERBOSE 2>&1
    chroot $CHROOT blackman -a > $VERBOSE 2>&1
  fi

  return $SUCCESS
}


# add user to newly created groups
update_user_groups()
{
  title 'BlackArch Linux Setup > User'

  wprintf "[+] Adding user $user to groups and sudoers"
  printf "\n\n"

  # TODO: more to add here
  if [ $VBOX_SETUP -eq $TRUE ]
  then
    chroot $CHROOT usermod -aG 'vboxsf,audio,video' "$user" > $VERBOSE 2>&1
  fi

  # sudoers
  echo "$user ALL=(ALL) ALL" >> $CHROOT/etc/sudoers > $VERBOSE 2>&1

  return $SUCCESS
}


# dump data from the full-iso
dump_full_iso()
{
  full_dirs='/bin /sbin /etc /home /lib /lib64 /opt /root /srv /usr /var /tmp'
  total_size=0 # no cheat

  title 'BlackArch Linux Setup'

  wprintf '[+] Dumping data from Full-ISO. Grab a coffee and pop shells!'
  printf "\n\n"

  wprintf '[+] Fetching total size to transfer, please wait...'
  printf "\n"

  for d in $full_dirs
  do
    part_size=$(du -sm "$d" 2> /dev/null | awk '{print $1}')
    ((total_size+=part_size))
    printf "
  > $d $part_size MB"
  done
  printf "\n
  [ Total size = $total_size MB ]
  \n\n"

  check_space

  wprintf '[+] Installing the backdoors to /'
  printf "\n\n"
  warn 'This can take a while, please wait...'
  printf "\n"
  rsync -aWx --human-readable --info=progress2 / $CHROOT > $VERBOSE 2>&1
  wprintf "[+] Installation done!\n"

  # clean up files
  wprintf '[+] Cleaning Full Environment files, please wait...'
  sed -i 's/Storage=volatile/#Storage=auto/' ${CHROOT}/etc/systemd/journald.conf
  rm -rf "$CHROOT/etc/udev/rules.d/81-dhcpcd.rules"
  rm -rf "$CHROOT/etc/systemd/system/"{choose-mirror.service,pacman-init.service,etc-pacman.d-gnupg.mount,getty@tty1.service.d}
  rm -rf "$CHROOT/etc/systemd/scripts/choose-mirror"
  rm -rf "$CHROOT/etc/systemd/system/getty@tty1.service.d/autologin.conf"
  rm -rf "$CHROOT/root/"{.automated_script.sh,.zlogin}
  rm -rf "$CHROOT/etc/mkinitcpio-archiso.conf"
  rm -rf "$CHROOT/etc/initcpio"
  #rm -rf ${CHROOT}/etc/{group*,passwd*,shadow*,gshadow*}
  wprintf "done\n"

  return $SUCCESS
}


# setup blackarch related stuff
setup_blackarch()
{
  update_etc
  sleep_clear 1

  enable_iwd_networkd
  sleep_clear 1

  ask_mirror
  sleep_clear 1

  run_strap_sh
  sleep_clear 1

  ask_x_setup
  sleep_clear 3

  if [ $X_SETUP -eq $TRUE ]
  then
    setup_display_manager
    sleep_clear 1
    setup_window_managers
    sleep_clear 1
  fi

  ask_vbox_setup
  sleep_clear 1

  if [ $VBOX_SETUP -eq $TRUE ]
  then
    setup_vbox_utils
    sleep_clear 1
  fi

  ask_vmware_setup
  sleep_clear 1

  if [ $VMWARE_SETUP -eq $TRUE ]
  then
    setup_vmware_utils
    sleep_clear 1
  fi

  sleep_clear 1

  enable_pacman_multilib 'chroot'
  sleep_clear 1

  enable_pacman_color 'chroot'
  sleep_clear 1

  ask_ba_tools_setup
  sleep_clear 1

  if [ $BA_TOOLS_SETUP -eq $TRUE ]
  then
    setup_blackarch_tools
    sleep_clear 1
  fi

  if [ -n "$NORMAL_USER" ]
  then
    update_user_groups
    sleep_clear 1
  fi

  return $SUCCESS
}


# for fun and lulz
easter_backdoor()
{
  bar=0

  title 'Game Over'

  wprintf '[+] BlackArch Linux installation successfull!'
  printf "\n\n"

  wprintf 'Yo n00b, b4ckd00r1ng y0ur sy5t3m n0w '
  while [ $bar -ne 5 ]
  do
    wprintf "."
    sleep 1
    bar=$((bar + 1))
  done
  printf " >> ${BLINK}${WHITE}HACK THE PLANET! D00R THE PLANET!${NC} <<"
  printf "\n\n"

  return $SUCCESS
}


# perform sync
sync_disk()
{
  title 'Game Over'

  wprintf '[+] Syncing disk'
  printf "\n\n"

  sync

  return $SUCCESS
}


# check if new version available. perform self-update and exit
self_updater()
{
  title 'Self Updater'
  wprintf '[+] Checking for a new version of myself...'
  printf "\n\n"

  pacman -Syy > $VERBOSE 2>&1
  repo="$(pacman -Ss blackarch-installer | head -1 | cut -d ' ' -f 2 |
    cut -d '-' -f 1 | tr -d '.')0"
  this="$(echo $VERSION | tr -d '.')0"

  if [ "$this" -lt "$repo" ]
  then
    printf "\n\n"
    warn 'A new version is available! Going to fuck, err, update myself.'
    pacman -S --overwrite='*' --noconfirm blackarch-installer > $VERBOSE 2>&1
    yes | pacman -Scc > $VERBOSE 2>&1
    wprintf "\n[+] Updated successfully. Please restart the installer now!\n"
    chmod +x /usr/share/blackarch-installer/blackarch-install
    exit $SUCCESS
  fi

  return $SUCCESS
}


# controller and program flow
main()
{
  # do some ENV checks
  sleep_clear 0
  check_uid
  check_env
  check_boot_mode
  check_iso_type

  # install mode
  ask_install_mode

  # output mode
  ask_output_mode
  sleep_clear 0

  # locale
  ask_locale
  set_locale
  sleep_clear 0

  # keymap
  ask_keymap
  set_keymap
  sleep_clear 0

  # network
  ask_hostname
  sleep_clear 0

  if [ "$INSTALL_MODE" != "$INSTALL_FULL_ISO" ]
  then
    get_net_ifs
    ask_net_conf_mode
    if [ "$NET_CONF_MODE" != "$NET_CONF_SKIP" ]
    then
      ask_net_if
    fi
    case "$NET_CONF_MODE" in
      "$NET_CONF_AUTO")
        net_conf_auto
        ;;
      "$NET_CONF_WLAN")
        ask_wlan_data
        net_conf_wlan
        ;;
      "$NET_CONF_MANUAL")
        ask_net_addr
        net_conf_manual
        ;;
      "$NET_CONF_SKIP")
        ;;
      *)
        ;;
    esac
    sleep_clear 1
    check_inet_conn
    sleep_clear 1

    # self updater
    self_updater
    sleep_clear 1

    # pacman
    ask_mirror_arch
    sleep_clear 1
    update_pacman
  fi

  # hard drive
  get_hd_devs
  ask_hd_dev
  ask_dualboot
  sleep_clear 1
  umount_filesystems 'harddrive'
  sleep_clear 1
  ask_cfdisk
  sleep_clear 3
  ask_luks
  get_partition_label
  ask_partitions
  print_partitions
  ask_formatting
  clear
  make_partitions
  clear
  mount_filesystems
  sleep_clear 1

  # arch linux
  setup_base_system
  sleep_clear 1
  setup_time
  sleep_clear 1

  # blackarch Linux
  if [ "$INSTALL_MODE" != "$INSTALL_FULL_ISO" ]
  then
    setup_blackarch
    sleep_clear 1
  fi

  # epilog
  umount_filesystems
  sleep_clear 1
  sync_disk
  sleep_clear 1
  easter_backdoor

  return $SUCCESS
}


# we start here
main "$@"


# EOF
