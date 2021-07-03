#!/bin/bash

function formatDrive () {

	if [[ $1 =~ ^disk[0-9]s[1-9]$ ]]; then
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
		echo "Disk/Volume label argument must be in the format of disk* (for a disk) or disk*s* (for a volume) where * is a number from 0-9."
		exit
	fi
}

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

function setDriveName () {

	diskutil rename /Volumes/Install\ macOS\ Big\ Sur "Install Big Sur"
}

function setDriveLabel () {

	bless --folder /Volumes/Install\ Big\ Sur/System/Library/CoreServices/ --label "Install Big Sur"
}

function setIconFlag () {

	setFile -a C /Volumes/Install\ Big\ Sur
}

function mountCycle () {

	diskutil unmount force /Volumes/Install\ Big\ Sur
	diskutil mount "$(diskutil list | grep "Install Big Sur" | awk '{ print $8 }')"
	echo "Drive has been mount cycled and is now ready for use."
}

function cleanUp () {

	for i in $(diskutil list | grep "Shared Support" | awk '{ print $7 }'); do
		diskutil eject $i
	done
}

formatDrive $1
isDriveMounted $1
buildInstaller $2
setDriveName
setDriveLabel
setIconFlag
mountCycle
cleanUp

echo "DEBUG: application finished"
















