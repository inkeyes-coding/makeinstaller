#!/bin/bash

## After building and rebuilding the same macOS Big Sur bootable installer every time Apple releases a new version 
## (which is often), I decided to automate the entire process. This script takes a disk/volume ID in the format of disk* 
## (for a disk) or disk*s* (for a volume) where * is a number from 0-99, and a custom application path (that points to the 
## .app installer file). The disk ID is required, the path is not. This script assumes that there are no duplicately named 
## disks/volumes mounted and will target which ever disk/volume with that name was mounted first. This script is provided 
## as is and with no guarantees of functionality.
##
## Any comments, questions, or bugs can be sent to inkeyes@tutanota.com
##
## ------------------------------------------------------------------------------------------

## Validates the user's input by checking to see if it matches the Disk or Volume ID format.
## Checks to see if the chosen disk/volume is mounted. If it is, it formats it.
## The if..else structure differentiates between a whole disk and an individual volume. 

function formatDrive () {

	if [[ $1 =~ ^disk[0-9]s[1-9]$ || ^disk[0-9][0-9]s[1-9][0-9]$ ]]; then
		if diskutil list | grep -q "$1$"; then
			diskutil eraseVolume JHFS+ big1 $1
		else
			echo "Target is not currently mounted. Target must be mounted to proceed."
			exit
		fi
	elif [[ $1 =~ ^disk[0-9]$ ]]; then
		if diskutil list | grep -q "$1$"; then
			diskutil eraseDisk JHFS+ big1 $1
		else
			echo "Target is not currently mounted. Target must be mounted to proceed."
			exit
		fi
	else
		echo "Invalid argument format."
		echo "Disk/Volume label argument must be in the format of disk* (for a disk) or disk*s* (for a volume) where * is a number from 0-99."
		exit
	fi
}

## Checks to see if the chosen disk/volume is mounted after the formatting process.
## This check is only really necessary on slower computers where it can take several seconds for the drive to become available.

function isDriveMounted () {

	errorCount=0;

	while true; do
		if diskutil list | grep -q "$1$"; then
			echo "Target $1 is mounted, proceeding."
			break
		elif [ $errorCount -eq 5 ]; then
			echo "Mounting target $1 has time out, exiting"
			exit
		else
			echo "Target $1 was not mounted, waiting for target to mount."
			let "errorCount++"
			sleep 2
		fi
	done	
}

## Runs the installer creation application contained within the macOS installer .app file.
## Checks to see if a custom path has been specified. If so, it uses that path. If not, it uses the defualt Applications
## folder path. If the .app file is not present at the path, it returns an error.

function buildInstaller () {

	if [[ "$1" == "" ]]; then
		if [ -d "/Applications/Install macOS Big Sur.app" ]; then
			/Applications/Install\ macOS\ Big\ Sur.app/Contents/Resources/createinstallmedia --volume /Volumes/big1 --nointeraction
		else
			echo "Installer application not found. Exiting."
			exit
		fi
	else
		if [ -d "$1" ]; then
			if [[ -d "$1/Install macOS Big Sur.app" ]]; then
				$1/Install\ macOS\ Big\ Sur.app/Contents/Resources/createinstallmedia --volume /Volumes/big1 --nointeraction
			else
				echo "Installer application not found. Exiting."
				exit
			fi
		else
			echo "Directory not found. Exiting."
		fi
	fi
}

## Sets the custom icon flag for the disk/volume that has been used. For whatever reason, Apple's own software doesn't do this
## by defualt and your drive ends up with the default system icon despite a custom .VolumeIcon.icns file being present.

function setIconFlag () {

	setFile -a C /Volumes/Install\ macOS\ Big\ Sur
}

## Force unmounts and the mounts the disk/volume. On newer versions of the operating system (especially Big Sur), creating
## a Big Sur installer results in the disk/volume being locked up by a system process. I am unsure exactly what is accessing
## it but it never finishes and the disk/volume is in use indefinitely. Mount cycling it fixes this issue.

function mountCycle () {

	diskutil unmount force /Volumes/Install\ macOS\ Big\ Sur
	diskutil mount "$(diskutil list | grep "Install macOS Big Sur" | awk '{ print $9 }')"
	echo "Drive has been mount cycled and is now free."
}

## Unmounts any of the resource disk images the installer creation process uses. For some reason this is also not cleaned
## up by Apple's software.

function cleanUp () {

	for i in $(diskutil list | grep "Shared Support" | awk '{ print $7 }'); do
		diskutil eject $i
	done
}

## Sets the disk/volume label. This is the text that appears under a drive in the disk selection menu (boot loader?)
## at boot time. This needs to be set seperately as disk utility is not consistant at changing it.

function setDriveLabel () {

	bless --folder /Volumes/Install\ macOS\ Big\ Sur/System/Library/CoreServices/ --label "$1"
}

## Renames the disk/volume generally within the OS. This is mostly done so it maches the boot label / for continuity.

function setDriveName () {

	diskutil rename /Volumes/Install\ macOS\ Big\ Sur "$1"
}

## Main program run. Calls each of the above functions in order and then checks if the user wants to use a custom 
## name/label. If they enter one, this is used in the last two function calls. If they don't, the last two functions are
## not called and the default name/label are used.

formatDrive $1
isDriveMounted $1
buildInstaller $2
setIconFlag
mountCycle
cleanUp

echo ""
echo "If you would like to enter a custom drive label, you may do so now."
echo "Press enter to use default name."
echo "This input will time out in 30 seconds."

read -t 30 -p ">> " custlabel

if [[ $custlabel != "" ]]; then
	setDriveLabel "$custlabel"
	setDriveName "$custlabel"
else
	echo "Using defualt name and label."
fi