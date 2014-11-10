#! /bin/bash

#####
#
#		Yosemite dark boot for unsupported machines
#
#		Created By	:	w0lf
#		Project Page:	https://github.com/w0lfschild/DarkBoot		
#		Last Edited	:	11/08/2014			
#		Project Page:	https://github.com/w0lfschild/DarkBoot		
#		About		:	Adds your board ID to boot.efi to get new dark boot screen.
#		Last Edited	:	11/08/2014	
#		Version		:	1.0.1
#		Changes		:	10.10.1+ support.
#		Notes		:	Use this script at your own risk. 
#						Backups located @ /System/Library/CoreServices/efi_backups/*
#			
#####

vercomp() {
    if [[ $1 == $2 ]]
    then
        return 0
    fi
    local IFS=.
    local i ver1=($1) ver2=($2)
    # fill empty fields in ver1 with zeros
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++))
    do
        ver1[i]=0
    done
    for ((i=0; i<${#ver1[@]}; i++))
    do
        if [[ -z ${ver2[i]} ]]
        then
            # fill empty fields in ver2 with zeros
            ver2[i]=0
        fi
        if ((10#${ver1[i]} > 10#${ver2[i]}))
        then
            return 1
        fi
        if ((10#${ver1[i]} < 10#${ver2[i]}))
        then
            return 2
        fi
    done
    return 0
}

verres() {
	vercomp "$1" "$2"
	case $? in
		0) output='=';;
        1) output='>';;
        2) output='<';;
	esac
	echo $output
}

do_work()
{
	echo -e "First you will need to enter your password for some sudo commands"
	echo -e "You won't see your password as you type it, just enter it and press return\n"
	sudo -v
	echo -e ""

	echo -e "Unlocking boot.efi"
	sudo chflags nouchg /System/Library/CoreServices/boot.efi
	
	cur_time=$(date +%y%m%d%H%M%S)
	echo -e "Backing up boot.efi to /System/Library/CoreServices/efi_backups/boot_${cur_time}.efi"
	if [[ ! -e /System/Library/CoreServices/efi_backups/ ]]; then sudo mkdir /System/Library/CoreServices/efi_backups; fi
	sudo cp /System/Library/CoreServices/boot.efi /System/Library/CoreServices/efi_backups/boot_${cur_time}.efi
	#sudo cp /System/Library/CoreServices/boot.efi ~/Desktop/boot${cur_time}.efi
	
	echo -e "Downloading working boot.efi"
	if [[ -e /tmp/boot.efi ]]; then sudo rm /tmp/boot.efi; fi
	curl -\# -L -o /tmp/boot.efi http://sourceforge.net/projects/darkboot/files/boot.efi/download
	
	echo -e "Moving working boot.efi"
	sudo rm /System/Library/CoreServices/boot.efi
	sudo mv /tmp/boot.efi /System/Library/CoreServices/boot.efi

	echo -e "Getting boot.efi hex\n"
	xxd -p /System/Library/CoreServices/boot.efi | tr -d '\n' > /tmp/___boot.efi

	echo -e "Finding ID to replace\n"
	#ohex_ID=$(sed -e 's|^.*4d61632d|4d61632d|' /tmp/___boot.efi)
	ohex_ID=$(perl -p -e 's/^.*?4d61632d/4d61632d/' /tmp/___boot.efi)
	ohex_ID=${ohex_ID:0:40}
	old_ID=$(echo -n $ohex_ID | xxd -r -ps)

	echo -e "Your ID : $new_ID"
	echo -e "Old  ID : $old_ID\n"

	echo -e "Converting ID to hex\n"
	nhex_ID=$(echo -n $new_ID | xxd -ps | sed 's|[[:xdigit:]]\{2\}|\\x&|g')
	nhex_ID=$(echo "$nhex_ID" | sed 's|\\x||g')
	while [[ ${#nhex_ID} -lt 40 ]]; do nhex_ID=${nhex_ID}0; done
	
	echo -e "Your ID : $nhex_ID"
	echo -e "Old  ID : $ohex_ID\n"	

	echo -e "Editing boot.efi hex\n"
	if ! $(grep -q "$nhex_ID" /tmp/___boot.efi); then 
		echo -e "Your board ID couldn't be found in boot.efi"
		echo -e "Your board ID will now be added\n"
		sed -i -e "s|$ohex_ID|$nhex_ID|g" /tmp/___boot.efi
	else
		a_test=true
		echo -e "Your board ID already exists in boot.efi"
		echo -n "Would you like to REMOVE your ID? (y/n): "	
		read rm_ID
		if [[ $rm_ID = "y" ]]; then
			echo -e "Your board ID will now be nulled\n"
			sed -i -e "s|$nhex_ID|4d61632d00000000000000000000000000000000|g" /tmp/___boot.efi
		else
			echo -e "Canceling..."
			rm /tmp/___boot.efi
			sudo chmod 644 /System/Library/CoreServices/boot.efi
			sudo chown root:wheel /System/Library/CoreServices/boot.efi
			sudo chflags uchg /System/Library/CoreServices/boot.efi
			sleep 1
			exit
		fi
	fi
	
	perl -pe 'chomp if eof' /tmp/___boot.efi > /tmp/__boot.efi
	xxd -r -p /tmp/__boot.efi /tmp/_boot.efi
	
	echo -e "Replacing boot.efi and cleaning up /tmp"
	sudo mv /tmp/_boot.efi /System/Library/CoreServices/boot.efi 
	rm /tmp/___boot.efi-e
	rm /tmp/___boot.efi
	rm /tmp/__boot.efi
	#rm /tmp/_boot.efi

	echo -e "Adjusting permissions and locking boot.efi\n"
	sudo chmod 644 /System/Library/CoreServices/boot.efi
	sudo chown root:wheel /System/Library/CoreServices/boot.efi
	sudo chflags uchg /System/Library/CoreServices/boot.efi

	export LANG=C
	if $(cat /System/Library/CoreServices/boot.efi | tr -d '\n' | grep -q $new_ID); then
		echo -e "Success!"
		echo -e "Now all you need to do is reboot twice.\n"
		echo -n "Would you like to reboot now? (y/n): "	
		read rb_now
		if [[ $rb_now = "y" ]]; then sudo reboot; fi
	else
		if ($a_test); then
			echo -e "Your ID has been removed."
		else
			echo -e "Hmmm... something went wrong your ID is not in boot.efi\n"
			echo -e "Try adding it manually, you can find out how here:\n\n"
			echo -e "http://forums.macrumors.com/showthread.php?t=1751446\n"
		fi
	fi
}

clear
echo -e "Welcome\n"
a_test=false
new_ID=$(ioreg -p IODeviceTree -r -n / -d 1 | grep board-id)
new_ID=${new_ID##*<\"}
new_ID=${new_ID%%\">}
osx_ver=$(sw_vers -productVersion)
testres=$(verres "$osx_ver" 10.10)

if [[ $testres = ">" || $testres = "=" ]]; then
	if [[ ${#new_ID} -lt 21 ]]; then
		do_work
	fi
else
	echo -e "Sorry this only works on OSX Yosemite\n"
fi

# End
