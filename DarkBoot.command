#! /bin/bash

#####
#
#		Yosemite dark boot for unsupported machines
#
#		Created By	:	w0lf
#		Project Page:	https://github.com/w0lfschild/DarkBoot		
#		Last Edited	:	12/17/2014			
#		About		:	Adds your board ID to boot.efi to get new dark boot screen.
#		Changes		:	-
#		Notes		:	Use this script at your own risk. 
#					:	Backups located @ /System/Library/CoreServices/efi_backups/*			
#			
#####

# Reset boot.efi permissions, owner and lock
reset_efi() {
	sudo chmod 644 /System/Library/CoreServices/boot.efi
	sudo chown root:wheel /System/Library/CoreServices/boot.efi
	sudo chflags uchg /System/Library/CoreServices/boot.efi
}

# Determine if your ID already exists in boot
analyze_efi() {
	echo -e "Your ID : $board_ID"
	echo -e "hex  ID : $board_HEX\n"
	
	echo -e "Converting boot.efi to hex"
	xxd -p /System/Library/CoreServices/boot.efi | tr -d '\n' > /tmp/___boot.efi
	
	echo -e "Checking boot.efi hex for your ID"
	if ! $(grep -q "$board_HEX" /tmp/___boot.efi); then 
		echo -e "Your board ID couldn't be found in boot.efi"
		echo -e "Your board ID will now be added"
		use_dp2efi
	else
		id_removed=true
		echo -e "Your board ID already exists in boot.efi"
		echo -n "Would you like to REMOVE your ID? (y/n): "	
		read rm_ID
		if [[ $rm_ID = "y" ]]; then
			echo -e "Your board ID will now be nulled"
			sed -i -e "s|$board_HEX|4d61632d00000000000000000000000000000000|g" /tmp/___boot.efi
		else
			echo -e "Canceling..."
			rm /tmp/___boot.efi
			reset_efi
			exit
		fi
	fi
}

# Download and edit last know working boot.efi
use_dp2efi() {
	echo -e "Downloading working boot.efi"
	if [[ -e /tmp/boot.efi ]]; then sudo rm /tmp/boot.efi; fi
	curl -\# -L -o /tmp/boot.efi https://raw.githubusercontent.com/w0lfschild/DarkBoot/master/boot.efi
	
	echo -e "Moving working boot.efi"
	sudo rm /System/Library/CoreServices/boot.efi
	sudo mv /tmp/boot.efi /System/Library/CoreServices/boot.efi

	echo -e "Converting new boot.efi to hex"
	xxd -p /System/Library/CoreServices/boot.efi | tr -d '\n' > /tmp/___boot.efi

	echo -e "Finding ID to replace\n"
	replace_HEX=$(perl -p -e 's/^.*?4d61632d/4d61632d/' /tmp/___boot.efi)
	replace_HEX=${replace_HEX:0:40}
	replace_ID=$(echo -n $replace_HEX | xxd -r -ps)

	echo -e "Your ID : $board_ID"
	echo -e "Old  ID : $replace_ID\n"
	
	echo -e "Your hex ID : $board_HEX"
	echo -e "Old  hex ID : $replace_HEX\n"
	
	echo -e "Replacing ID"
	sed -i -e "s|$replace_HEX|$board_HEX|g" /tmp/___boot.efi
}

# Main method
main_method() {
	echo -e "First you will need to enter your password for some sudo commands"
	echo -e "You won't see your password as you type it, just enter it and press return\n"
	sudo -v
	echo -e ""

	# Unlock EFI
	echo -e "Unlocking boot.efi"
	sudo chflags nouchg /System/Library/CoreServices/boot.efi
	
	# Backup EFI
	local cur_time=$(date +%y%m%d%H%M%S)
	echo -e "Backing up boot.efi to /System/Library/CoreServices/efi_backups/boot_${cur_time}.efi\n"
	if [[ ! -e /System/Library/CoreServices/efi_backups/ ]]; then sudo mkdir /System/Library/CoreServices/efi_backups; fi
	sudo cp /System/Library/CoreServices/boot.efi /System/Library/CoreServices/efi_backups/boot_${cur_time}.efi
	
	# Determine what to do
	analyze_efi
	
	# Remove trailiing newline and convert hex back to standard boot.efi
	perl -pe 'chomp if eof' /tmp/___boot.efi > /tmp/__boot.efi
	xxd -r -p /tmp/__boot.efi /tmp/_boot.efi
	
	echo -e "Replacing boot.efi and cleaning up /tmp"
	sudo mv /tmp/_boot.efi /System/Library/CoreServices/boot.efi 
	rm /tmp/*boot.efi*

	echo -e "Adjusting permissions and locking boot.efi\n"
	reset_efi

	export LANG=C
	if $(cat /System/Library/CoreServices/boot.efi | tr -d '\n' | grep -q $board_ID); then
		echo -en "Success"'!'"\nNow all you need to do is reboot twice.\nWould you like to reboot now? (y/n): "	
		read rb_now
		if [[ $rb_now = "y" ]]; then sudo reboot; fi
	else
		if ($id_removed); then
			echo -e "Your ID has been removed."
		else
			echo -en "Hmmm... something went wrong your ID is not in boot.efi\nTry adding it manually, you can find out how here:\n\nhttp://forums.macrumors.com/showthread.php?t=1751446\n"
		fi
	fi
}

id_removed=false

# Clear term screen and show welcome
clear && printf '\e[3J'
echo -e "Welcome\n"

# Get device board-ID
board_ID=$(ioreg -p IODeviceTree -r -n / -d 1 | grep board-id)
board_ID=${board_ID##*<\"}
board_ID=${board_ID%%\">}

# Get device board-ID hex representation
board_HEX=$(echo -n $board_ID | xxd -ps | sed 's|[[:xdigit:]]\{2\}|\\x&|g')
board_HEX=$(echo "$board_HEX" | sed 's|\\x||g')
while [[ ${#board_HEX} -lt 40 ]]; do board_HEX=${board_HEX}0; done

# Get OSX version
osx_ver=$(sw_vers -productVersion)
mainVersion=$(echo "$osx_ver" | cut -d '.' -f 1)
subVersion=$(echo "$osx_ver" | cut -d '.' -f 2)

# OSX version check
if [[ $mainVersion -eq "10" && $subVersion -gt "9" ]]; then
	if [[ ${#board_ID} -lt 21 ]]; then
		main_method
	fi
else
	echo -en "Warning this has only been tested on OSX Yosemite.\nProceed with caution"'!'"\nWould you like to continue: (y/n): "
	if [[ ${#board_ID} -lt 21 ]]; then
		read _cont
		if [[ $_cont = "y" ]]; then main_method; fi
	fi
fi

# End
