#!/bin/sh
# Gentoo Server Install Start
## was falkland-installer
## PvSA, 24.6.2013
###################
#### TODO
## b1
# portage: http://distfiles.gentoo.org/snapshots/portage-latest.tar.bz2 - OK
# resolv.conf - OK
# mtab in chroot - OK
## b2
# chroot-script -OK
# -quiet /-interactive Option -OK
# quiet: IP/dhcp -OK
## RC1
# ch_install -OK
# paramter einlesen ohne reihenfolge
# fertig vorbereitete Disks (z.B. mdadm oder mit swap)
# part a already parted disk
## RC2
# ch_install in install_falkland
# multi chroot cmds
# NET aus chvar
# - dhcp - OK
# - IP - OK
# ssh re-emerge wegen falkland bug
# chavar.in ersetzten
## RC3
# own mirror
# hostname
# default bei read ="" /mnt/falkland
# select profile (/bin/bash: -c: line 0: syntax error near unexpected token `>') -> kein env-update etc, wenn es in die var geht !
# boot ist leer
# Warnung fuer 32-bit booted OS/System"
# mtab/fstab leer
# grub timeout = 5
# Quiet und feste IP: werte werden nicht in conf.d/net gesetzt
#######
# TODO
## Gentoo-Fork Changes
# Swap Parition anlegen
## falkland-Features
# emerge -j CPU#
# -> obsolet wg udev dev/pts sauber in die fstab (nicht aus dem live-system) oder das nehmen, das drin ist
# TEST: modules fuer hdd/net in kernel pruefen
# udev renaming eth to enp ln /dev/null /etc/udev/rules.d/80-net-name-slot.rules
# parted anstatt fdisk: parted /dev/... mkpart primary 0% 200MiB 
# keymap de/us
# rc-update sshd (abfrage in cmd), wenn angegeben ja ansonsten nix
# Prozessorkerne und emerge -j Option
### DEBUG
#set -x
#

# Set cefault editor
EDITOR=${EDITOR=vim}
# assuming disk(s) are not defnied
PD=0
# and using default mirror
OWNMIRROR=0
# color mapping
cred="\033[31m"
cgreen="\033[32m"
cyellow="\033[33m"
creset="\033[m"

if [ "$1" != '-q' ] && [ "$1" != "-i" ] || [ $# = 0 ]; then
	echo "install-gentoo_srv.sh - Script for Installing Gentoo-Server"
	echo "USAGE: sh install-gentoo_srv.sh -i|-q dhcp,IPs [-pd] [-om]"
	echo "-h : help"
	echo "-q : quiet Installation with defaults (for quiet you have to set >IP,gateway< or >dhcp<)"
        #echo "-n=hostname : Name of the host aka. hostname or hostname.domnain.tld (FQDN)"
	echo "-i : interactive"
	#echo "The mode (-q/-i/-h) is the first argument." # nicht mehr
	echo "-om: own mirror. You can specify altenativ mirror interactivly"
	echo "-pd : Predefined disks (Expecting:"
	echo "		already mounted disks (/mnt/xxx/ and /mnt/xxx/boot) "
	echo "      with empty filesystem on it "
	echo "		and not chrooted." 
	echo "		This is recommend for md or additional swap usage"
	echo "		For md-devices respect the metadata=0.9 for grub(1)"
	echo "THIS IS BETA STUFF. Please use only empty systems. Script erase disk to install !"
	exit 1
fi

if [ `uname -m |grep -c 64` = 0 ]; then
	echo "No 64-bit system booted or available. Installer not supporting 32-bit enviroment."
	exit 1
fi

for i in "$@"
do
	if [ "$i" = "-q" ]; then
		MODE="Q"
	elif [ "$i" = "-i" ]; then
		MODE="I"
	elif [ "$i" = "-pd" ]; then
	# disks ARE predefinied
		PD=1
	elif [ "$i" = "dhcp" ]; then
		NET="dhcp"
	elif [ "$i" = "-om" ]; then
		OWNMIRROR=1
       # elif [ `echo "$i" || grep '-n='` ]; then
       # HNAME="` echo ${i:4}`"
	else
		# only IP is now left
		NET="$i"
	fi
done

if [ $HNAME = "" ]; then
	$HNAME="localhost"
fi

if [ "$MODE" = 'Q' ]; then
	if [ "$2" != "dhcp" ] && [ "$2" = "" ]; then
		echo 'You have to set IP,gateway or dhcp for quiet-Mode and respect order'
		exit 1
	fi
fi
	

#STG3="stage3-20130329.tar.bz2"
STG3="stage3-latest.tar.bz2"

if [ $OWNMIRROR = 0 ]; then
	INSTSRV="distfiles.gentoo.org"
	FLURL="http://$INSTSRV//releases/amd64/autobuilds/current-stage3-amd64/stage3-amd64-20*.tar.bz2"
	#PURL="http://git.nitso.org/falkland-portage.git"
	PURL="rsync://rsync8.de.gentoo.org/gentoo-portage"
else
	echo "Assuming stage3 and portage are on the same dir on URL"
	echo "Which protocoll you want to use ? [http,ftp]"
	read PROTO
	echo "What is the name or IP of the mirror-server you want to use ? (example: distfiles.nitso.org or 192.168.0.1)"
	read INSTSRV
	echo "In which directory are the files on this server ?"
	echo "(example: mirror for 192.168.0.1/mirror/[stage3-latest|portage-latest] )"
	read RPATH
	FLURL="$PROTO://$INSTSRV/$RPATH/$STG3"
	PURL="$PROTO://$INSTSRV/$RPATH/portage-latest.tar.bz2"
	echo "Assuming stage3-URL: $FLURL"
	echo "Assuming portage-URL: $PURL"	
fi

MNTRT="/mnt/gentoosrv"
ADIR="`pwd`"

#check ram
echo -e "${cgreen}Checking ram size${creset}" 
RAMSZ="`cat /proc/meminfo |grep MemTotal |cut -d ':' -f 2|tr -d ' ' |tr -d 'kB'`"
if [ $RAMSZ -lt 128000 ]; then
        echo -e "${cred}RAM ist too small (<128MB)${creset}"
        exit 1
else
		echo -e "${cgreen}RAM size OK${creset}"
		#sleep 3
fi


# check network (-> mirror reachable ?)
echo -e "${cgreen}Checking mirror reachable${creset}" 
#ping -q -c 2 $INSTSRV >/dev/null
#if [ "$?" != "0" ]; then
curl -Is $INSTSRV |grep -q 'HTTP/1.1 200 OK'
if [ $? != 0 ]; then
        echo -e "${cred}Server or network down. Not reaching $INSTSRV, exiting${creset}"
        exit 1
else
		echo -e "${cgreen}Mirror reachable${creset}"
		#sleep 3
fi



# ssh starten
if [ "`netstat -tan|grep -c ':22 '`" = "0" ]; then
        echo -e "${cgreen}SSH is down. Try to activate now${creset}"
        /etc/init.d/ssh start
fi

if [ $PD = 0 ]; then
if [ "$MODE" = "I" ]; then

	# checking for usable disks
	echo "--------------------"
	fdisk -l |grep "/dev/" |cut -d " " -f 2 |sed 's/:/ /g' |sed 's/\/dev\///g'
	echo "--------------------"

	# dselect disk
	echo -e "${cyellow}Wich Disk is for the new system ?${creset}"
	read DISK

	# part. the disk
	echo 'Normaly two partitions are enough (no swap) /boot (256MB) und / (rest) [Enter]'
	read IT
	cfdisk $DISK
	
elif [ "$MODE" = "Q" ]; then
	## http://www.gentoo-wiki.info/Gentoo_Install_Script
	# Default is 2 partitons on the only disk device
	# select disk (vda, hda, sda) and not a partition
	DISK="`find /dev/ | grep -E [s:h:v]da |grep -v da[0-9]`"

	# delete partition table
	#parted -s $DISK mklabel msdos
	#dd if=/dev/zero of=$DISK count=512
	#sfdisk -R $DISK
	echo "d" 	>> fdisc.in	# Delete old Part
	echo "1" 	>> fdisc.in	# Delete old Part
	echo "d" 	>> fdisc.in	# Delete old Part
	echo "2" 	>> fdisc.in	# Delete old Part
	echo "d" 	>> fdisc.in	# Delete old Part
	echo "3" 	>> fdisc.in	# Delete old Part
	echo "d" 	>> fdisc.in	# Delete old Part
	# Create fdisc auto file
	echo "n" 	>> fdisc.in	# New Partiton
	echo "p" 	>> fdisc.in	# Primary
	echo "1" 	>> fdisc.in	# Partion 1
	echo "" 	>> fdisc.in	# default
	echo "+256M" 	>> fdisc.in	# 256 MB size - boot
	echo "a" 	>> fdisc.in	# Set flag
	echo "1" 	>> fdisc.in	# bootable
	echo -n "."
	echo "n" 	>> fdisc.in	# New Partion
	echo "p" 	>> fdisc.in	# Primary
	echo "2" 	>> fdisc.in	# Partion 2
	echo "" 	>> fdisc.in	# default
	echo "" 	>> fdisc.in	# rest (default)
	echo -n "."
	echo "w" 	>> fdisc.in	# Write partion table
	echo "q" 	>> fdisc.in	# Quit
	echo ". Done"
	# Execute file
	echo "Executing fdisk script ..."
	echo
	fdisk $DISK < fdisc.in 
	#clean up
	rm -f fdisc.in
	echo ""
	echo -e "${cgreen}Partions created${creset}"
fi
	# reload parttiontable
	sfdisk -R $DISK
	
	#Defining disks
	BDISK="${DISK}1"
	RDISK="${DISK}2"

	# formating filesystem (sys und boot)
	echo -e "${cgreen}Formating partitions${creset}"
	mkfs.ext2 -q $BDISK 
	mkfs.ext4 -q $RDISK

	# create SYS 
	echo -e "${cgreen}Mounting system${creset}"
	mkdir -p $MNTRT
	mount $RDISK $MNTRT

elif [ $PD = 1 ]; then
	echo "Which mount point (e.g. /mnt/gentoosrv) shell be used for Root-System (/)"
	# override VAR default
	read MNTRT
	echo "Which is boot device for grub (Grub Version 0.9)"
	read BOOTDEV
fi

#stage 3 extracting
echo -e "${cgreen}Getting stage3${creset}"
cd $MNTRT
#wget -q $FLURL
curl -# -O $FLURL
echo -e "${cgreen}Unpacking stage3${creset}"
tar -xf $STG3
mv $STG3 $MNTRT/root/

#portage extracting
#! websync
echo -e "${cgreen}Getting portage${creset}"
rsync $PURL/ $MNTRT/usr/portage/
#wget -q $PURL
#$GRUEN && echo "Unpacking portage"
#$NRML
#tar -xf portage-latest.tar.bz2
#mv portage-latest.tar.bz2 $MNTRT/root/


# mount /boot etc
echo -e "${cgreen}Mounting boot and dependings${creset}"
if [ $PD = 0 ]; then
	mount $BDISK $MNTRT/boot
fi
mount -t proc none $MNTRT/proc
mount --bind /dev $MNTRT/dev
mount --bind /dev/pts $MNTRT/dev/pts
mount -t sysfs none $MNTRT/sys

# mounts /mtab (s.u.)
#grep -v rootfs /etc/mtab > $MNTRT/etc/mtab


## Chroot-commands following ...
cp $ADIR/install_falkland* $MNTRT/root/

# only grub-install device is DISK
if [ $PD = 0 ]; then
	BOOTDEV="$DISK"
	# PD=1 set this above
fi

# setting passwd
echo -e "${cyellow}Set password:${creset}"
if [ "$MODE" = "I" ]; then
	chroot $MNTRT /bin/passwd 
else
	echo "falkland" > .pw-file
	echo "falkland" >> .pw-file
	chroot $MNTRT /bin/passwd < .pw-file
	rm -f .pw-file
	echo -e "${cyellow}Password set to: falkland${creset}"
fi

# Network config
if [ "$MODE"  = "I" ]; then
	echo -e "${cyellow}Folgende NIC sind verfuegbar: [Enter = Weiter]${creset}"
	chroot $MNTRT ifconfig -a |grep "Link encap" |cut -d " " -f 1
	read NETDEV
	echo "Netzwerk-config - Editor: $EDITOR, File: /etc/conf.d/net (in Chroot)"
	echo 'config_eth0="IP netmask 255.255.255.0"' >>  $MNTRT/etc/conf.d/net
	echo 'routes_eth0="default via GW"' >>  $MNTRT/etc/conf.d/net
	$EDITOR $MNTRT/etc/conf.d/net
    echo "Setting hostname (conf.d)"
    echo "hostname=\"$HNAME\" " > $MNTRT/etc/conf.d/hostname
    echo "Please setup hosts-file [Enter]"
    $EDITOR $MNTRT/etc/hosts

elif [ "$MODE" = "Q" ]; then
	# assume it is eth0
	NETDEV="eth0"
	if [ "$NET" = "dhcp" ]; then
		echo 'config_eth0="dhcp"' >> $MNTRT/etc/conf.d/net
	else
		IP="`echo $NET| cut -d ',' -f 1`"
		GW="`echo $NET| cut -d ',' -f 2`"
		echo "config_$NETDEV=\"$IP netmask 255.255.255.0\"" >>  $MNTRT/etc/conf.d/net
		echo "routes_$NETDEV=\"default via $GW\"" >>  $MNTRT/etc/conf.d/net
	fi
    echo "hostname=\"$HNAME\" " > /etc/conf.d/hostname
    echo "$IP $HNAME" >> /etc/hosts
fi

chroot $MNTRT ln -s /etc/init.d/net.lo /etc/init.d/net.$NETDEV
chroot $MNTRT rc-update add net.$NETDEV default

#Namesever
## CCC Berlin
echo "nameserver 213.73.91.35" > $MNTRT/etc/resolv.conf
## Google
echo "nameserver 8.8.8.8" >> $MNTRT/etc/resolv.conf

#!layman
echo -e "${cgreen}Activating Layman and Overlay Falkland${creset}"
cat $MNTRT/etc/layman/layman.cfg |grep -v "overlays  :" > /tmp/layman.cfg
echo "overlays  : http://www.gentoo.org/proj/en/overlays/repositories.xml
               http://distfiles.nitso.org/linux/falkland/repositories.xml" >> /tmp/layman.cfg
cp /tmp/layman.cfg $MNTRT/etc/layman/layman.cfg 
echo "source /var/lib/layman/make.conf" >> $MNTRT/etc/portage/make.conf

chroot $MNTRT /bin/bash -c "env-update;source /etc/profile;layman -S" > /dev/null
chroot $MNTRT /bin/bash -c "env-update;source /etc/profile;layman -L" > /dev/null
chroot $MNTRT /bin/bash -c "env-update;source /etc/profile;layman -a falkland"

# Profile 
echo -e "${cgreen}Setting eselect to profile falkland${creset}"
chroot $MNTRT /bin/bash -c "env-update;source /etc/profile"
PROFIL="`chroot $MNTRT /bin/bash -c \"eselect profile list |grep falkland |grep server |cut -d ' ' -f 3|sed 's/\[//g' |sed 's/\]//g'\"`"
chroot $MNTRT /bin/bash -c "env-update;source /etc/profile;eselect profile set $PROFIL"
chroot $MNTRT /bin/bash -c "env-update;source /etc/profile;layman -S" > /dev/null

# base-extras (grub etc)
#!
echo -e "${cgreen}Installing package falkland-kernel and portage${creset}"
chroot $MNTRT /bin/bash -c "env-update;source /etc/profile;emerge sys-kernel/falkland"
chroot $MNTRT /bin/bash -c "env-update;source /etc/profile;emerge sys-apps/portage"
chroot $MNTRT /bin/bash -c "env-update;source /etc/profile;emerge --sync" 2&1>/dev/null


# base-extras (grub etc)
echo -e "${cgreen}Installing grub${creset}"
#chroot $MNTRT /bin/bash -c "env-update;source /etc/profile;emerge base-extras"
chroot $MNTRT /bin/bash -c "env-update;source /etc/profile;emerge sys-boot/grub:0"

# grub-config
if [ "$MODE" = "I" ]; then
	echo -e "${cgreen}Configure GRUB - menu.lst (Editor: nano)  [Enter]${creset}"
	$EDITOR $MNTRT/boot/grub/menu.lst
elif [ "$MODE" = "Q" ]; then
	echo -e "${cgreen}Configure GRUB - menu.lst${creset}"
	HEREP="`pwd`"
	cd $MNTRT
	KERNVER="`find boot/ |grep vmlinuz |sed 's/boot\/vmlinuz-//g'`"
	echo "title Falkland Linux - Kernel $KERNVER" >> $MNTRT/boot/grub/menu.lst
	echo "root (hd0,0)"  >> $MNTRT/boot/grub/menu.lst
	echo "kernel /vmlinuz-$KERNVER root=$RDISK" >> $MNTRT/boot/grub/menu.lst
	sed 's/timeout 30/timeout 5/' -i $MNTRT/boot/grub/menu.lst
	cd $HEREP
fi

# fstab etc
echo -e "${cgreen}Generating mtab/fstab${creset}"
## mounts holen mit korrektem Pfad
chroot $MNTRT /bin/bash -c "cat /proc/mounts > /tmp/mounts"
# mtab
cat $MNTRT/tmp/mounts |grep -v rootfs > $MNTRT/etc/mtab
# fstab
echo "#Genrated by falkland installer" > $MNTRT/etc/fstab
cat $MNTRT/tmp/mounts |grep $RDISK >> $MNTRT/etc/fstab
cat $MNTRT/tmp/mounts |grep $BDISK >> $MNTRT/etc/fstab
## Anstatt fremd-kernel-config -> statische aus der source  
# devpts kann mehr als einmal vorkommen, also das letzte nehmen
#cat $MNTRT/tmp/mounts |grep devpts |tail -n 1 >> $MNTRT/etc/fstab

#grub-install
echo -e "${cgreen}Installing grub to $BOOTDEV${creset}"
# otherwise grub fails with no BIOS drive found
if [ "`cat $MNTRT/boot/grub/device.map|grep $BOOTDEV`" = "" ]; then
	echo "(hd0) $BOOTDEV" >> $MNTRT/boot/grub/device.map
fi
chroot $MNTRT /sbin/grub-install --no-floppy $BOOTDEV

# re-emerge sshd - falkland bug
echo -e "${cgreen}Re-emerge openSSHd${creset}"
chroot $MNTRT /bin/bash -c "env-update;source /etc/profile;emerge openssh"
chroot $MNTRT /bin/bash -c "env-update;source /etc/profile;rc-update add sshd"

echo -e "${cyellow}"
# needed net modules check
NETMOD="`lsmod|grep net|cut -d ' ' -f 1`"
#NETINKERN="`cat $MNTRT/boot/config-$KERNVER |grep -i net`"
echo -e "Needed net modules loaded: \n $NETMOD"
#echo "Needed net device in (new) kernel-config: $NETINKERN"
# needed hdd modules check
HDDMOD="`lsmod|grep ata|cut -d ' ' -f 1`"
#HDDINKERN="`cat $MNTRT/boot/config-$KERNVER |grep -i ata`"
echo -e "Needed net modules loaded: \n $HDDMOD"
#echo "Needed net device in (new) kernel-config: $HDDINKERN"
echo -e "${cyellow}"
echo "Please double check the listed modules and there corresponding kernel-config-option \ 
 to be sure, the new system is booting properly and reach the network"
echo -e "${creset}"

echo -e "${cgreen}Installation finished. You may now check the system or reboot."
echo -e "${cyellow}root password is falkland, hostname ist not yet set and keymap is set to US."
echo "For further question write to falkland@pilarkto.org"
echo " or visit Projekt-Wiki: http://wiki.open-laboratory.de/Intern:IT:HowTo:Gentoo_Install"
echo "Have fun"
echo -e "${creset}"
