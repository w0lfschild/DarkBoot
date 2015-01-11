#! /bin/bash

#####
#
#		Created By	:	w0lf
#		Project Page:	https://github.com/w0lfschild/DarkBoot		
#		Last Edited	:	Jan / 11 / 2015			
#			
#####

pashua_run() {

	# Write config file
	pashua_configfile=`/usr/bin/mktemp /tmp/pashua_XXXXXXXXX`
	echo "$1" > $pashua_configfile

	# Find Pashua binary. We do search both . and dirname "$0"
	# , as in a doubleclickable application, cwd is /
	bundlepath="Pashua.app/Contents/MacOS/Pashua"
	if [ "$3" = "" ]
	then
		mypath=$(dirname "$0")
		for searchpath in "$mypath/Pashua" "$mypath/$bundlepath" "./$bundlepath" \
						  "/Applications/$bundlepath" "$HOME/Applications/$bundlepath"
		do
			if [ -f "$searchpath" -a -x "$searchpath" ]
			then
				pashuapath=$searchpath
				break
			fi
		done
	else
		# Directory given as argument
		pashuapath="$3/$bundlepath"
	fi

	if [ ! "$pashuapath" ]
	then
		echo "Error: Pashua could not be found"
		exit 1
	fi

	# Manage encoding
	if [ "$2" = "" ]
	then
		encoding=""
	else
		encoding="-e $2"
	fi

	# Get result
	result=$("$pashuapath" $encoding $pashua_configfile | perl -pe 's/ /;;;/g;')

	# Remove config file
	rm $pashua_configfile

	# Parse result
	for line in $result
	do
		key=$(echo $line | sed 's/^\([^=]*\)=.*$/\1/')
		value=$(echo $line | sed 's/^[^=]*=\(.*\)$/\1/' | sed 's/;;;/ /g')
		varname=$key
		varvalue="$value"
		eval $varname='$varvalue'
	done

}

# root needed to bless and create /dboot
ask_pass() {
	pass_window="$pass_window
				*.title = Dark Boot - $curver
				*.floating = 1
				*.transparency = 1.00
				*.autosavekey = dBoot"
	
	pass_window="$pass_window
				pw0.type = password
				pw0.label = Enter your password to continue
				pw0.width = 100
				pw0.x = -10
				pw0.y = 4"
	
	pashua_run "$pass_window" 'utf8'
	pass_window=""
	echo "$pw0" | sudo -Sv
	echo ""
	if [[ $pw0 = "" ]]; then echo -e "No password entered, quitting..."; exit; else pw0=""; fi
}

# Check what is currently blessed and then bless proper efi
check_bless() {
	blessed=$(bless --info | grep "Blessed System File")
	blessed='/'${blessed#*/}
	if [[ $1 = default ]]; then
		if [[ "$blessed" != /System/Library/CoreServices/boot.efi ]]; then bless_efi /System/Library/CoreServices boot.efi; fi
	else
		if [[ "$blessed" != /dboot/$1_boot.efi ]]; then bless_efi /dboot $1_boot.efi; fi
	fi
}

# Patch users board-ID into our custom efi
patch_efi() {
	echo -e "Getting board-ID"
	board_ID=$(ioreg -p IODeviceTree -r -n / -d 1 | grep board-id)
	board_ID=${board_ID##*<\"}
	board_ID=${board_ID%%\">}

	echo -e "Converting board-ID to hex"
	board_HEX=$(echo -n $board_ID | xxd -ps | sed 's|[[:xdigit:]]\{2\}|\\x&|g')
	board_HEX=$(echo "$board_HEX" | sed 's|\\x||g')
	while [[ ${#board_HEX} -lt 40 ]]; do board_HEX=${board_HEX}0; done
	
	echo -e "Converting boot.efi to hex"
	xxd -p /dboot/boot.efi | tr -d '\n' > /tmp/___boot.efi
	
	if ! $(grep -q "$board_HEX" /tmp/___boot.efi); then
		sudo mv /dboot/boot.efi /dboot/gray_boot.efi
		echo -e "Finding ID to replace"
		replace_HEX=$(perl -p -e 's/^.*?4d61632d/4d61632d/' /tmp/___boot.efi)
		replace_HEX=${replace_HEX:0:40}
		replace_ID=$(echo -n $replace_HEX | xxd -r -ps)
		echo -e "Replacing ID\nNew $board_HEX\nOld $replace_HEX"
		sed -i -e "s|$replace_HEX|$board_HEX|g" /tmp/___boot.efi
	else
		sudo mv /dboot/boot.efi /dboot/black_boot.efi
		sed -i -e "s|$board_HEX|4d61632d00000000000000000000000000000000|g" /tmp/___boot.efi
	fi
	
	echo -e "Creating custom boot.efi and cleaning up /tmp"
	perl -pe 'chomp if eof' /tmp/___boot.efi > /tmp/__boot.efi
	xxd -r -p /tmp/__boot.efi /tmp/_boot.efi
	if [[ -e /dboot/gray_boot.efi ]]; then
		sudo mv /tmp/_boot.efi /dboot/black_boot.efi
	else
		sudo mv /tmp/_boot.efi /dboot/gray_boot.efi
	fi
	rm /tmp/*boot.efi*
}

# Install custom efi (only happens if we don't already have one)
install_efi() {
	if [[ -e /dboot ]]; then sudo rm -r /dboot; fi
	sudo mkdir /dboot
	sudo cp "$dboot_efi" /dboot/boot.efi
	sudo cp /System/Library/CoreServices/.disk_label /dboot
	patch_efi
}

# Bless any efi $1 = Directory $2 = Efi name
bless_efi() {
	echo -e "$1/$2 blessed"
	pushd "$1" 1>/dev/null
	sudo bless --folder . --file "$2" --labelfile .disk_label
	popd 1>/dev/null
}

main() {
	my_color=$(defaults read org.w0lf.dBoot color || echo -n "default")
	login_items=$(osascript -e 'tell application "System Events" to get the name of every login item')
	if [[ "$login_items" = *"dBoot Agent"* ]]; then login_enabled=1; else login_enabled=0; fi
	
	main_window="$main_window
				*.title = Dark Boot - $curver
				*.floating = 1
				*.transparency = 1.00
				*.autosavekey = dBoot"
	
	main_window="$main_window
				db0.type = defaultbutton"
	
	main_window="$main_window
				tb0.type = text
				tb0.height = 0
				tb0.width = 150
				tb0.default = Boot Color : 
				tb0.x = 0
				tb0.y = 40"

	main_window="$main_window	
				pop0.type = popup
				pop0.width = 120
				pop0.option = default
				pop0.option = gray
				pop0.option = black
				pop0.default = $my_color
				pop0.x = 80
				pop0.y = 34"
				
	main_window="$main_window
				chk0.tooltip = Check to make sure your selected option is enforced at every startup/login.
				chk0.type = checkbox
				chk0.label = Check at login
				chk0.default = $login_enabled
				chk0.x = 0
				chk0.y = 4"
	
	pashua_run "$main_window" 'utf8'
	
	if [[ $db0 = "1" ]]; then
		ask_pass
		defaults write org.w0lf.dBoot color $pop0
		if [[ ! -e /dboot/${pop0}_boot.efi ]]; then install_efi; fi
		check_bless $pop0
		if [[ $chk0 = "1" ]]; then
			if [[ $login_enabled = 0 ]]; then
osascript <<EOD
tell application "System Events"
make new login item at end of login items with properties {path:"$helper", hidden:false}
end tell
EOD
			fi
		else
			if [[ $login_enabled = 1 ]]; then
osascript <<EOD
tell application "System Events"
delete login item "Dark Boot"
end tell
EOD
			fi
		fi
	fi
}

# Directories
scriptDirectory=$(cd "${0%/*}" && echo $PWD)
dboot_efi="$scriptDirectory"/boot.efi
app_directory="$scriptDirectory"
for i in {1..2}; do app_directory=$(dirname "$app_directory"); done
helper="$app_directory"/Contents/Resources/"dBoot Agent".app

# Variables
curver=$(defaults read "$app_directory"/Contents/Info.plist CFBundleShortVersionString)
boot_color="Default"

# Run
main

# End
