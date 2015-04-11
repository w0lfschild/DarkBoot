#! /bin/bash

#####
#
#		Created By	:	w0lf
#		Project Page:	https://github.com/w0lfschild/DarkBoot		
#		Last Edited	:	Mar / 10 / 2015			
#			
#####

# Draw windows with pashua
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

# For root needs
ask_pass() {
	pass_window="$pass_window
*.title = Dark Boot - $curver
*.floating = 1
*.transparency = 1.00
*.autosavekey = dBoot
pw0.type = password
pw0.label = Enter your password to continue:
pw0.mandatory = 1
pw0.width = 100
pw0.x = -10
pw0.y = 4"
	pashua_run "$pass_window" 'utf8' "$pashua_directory"
	pass_window=""
	echo "$pw0" | sudo -Sv
	if [[ $pw0 = "" ]]; then echo -e "No password entered, quitting..."; exit; else pw0=""; fi
}

# Bless any efi $1 = Folder $2 = File
bless_efi() {
	ask_pass
	echo -e "$1/$2 blessed"
	pushd "$1" 1>/dev/null
	sudo bless --verbose --folder . --file "$2" --labelfile .disk_label
	popd 1>/dev/null
}

# Patch users board-ID into custom efi
patch_efi() {
	board_ID=$(ioreg -p IODeviceTree -r -n / -d 1 | grep board-id)
	board_ID=${board_ID##*<\"}
	board_ID=${board_ID%%\">}
	echo -e "Board-ID : $board_ID"

	board_HEX=$(echo -n $board_ID | xxd -ps | sed 's|[[:xdigit:]]\{2\}|\\x&|g')
	board_HEX=$(echo "$board_HEX" | sed 's|\\x||g')
	while [[ ${#board_HEX} -lt 40 ]]; do board_HEX=${board_HEX}0; done
	echo -e "Board-ID Hex : $board_HEX"
	
	echo -e "Converting boot.efi to hex"
	xxd -p "$app_dir"/boot.efi | tr -d '\n' > "$app_dir"/___boot.efi
	
	echo -e "Adding your board ID"
	sed -i -e "s|4d61632d7265706c616365207468697320747874|$board_HEX|g" "$app_dir"/___boot.efi
	
	echo -e "Moving files and cleaning up "$app_dir""
	perl -pe 'chomp if eof' "$app_dir"/___boot.efi > "$app_dir"/__boot.efi
	xxd -r -p "$app_dir"/__boot.efi "$app_dir"/_boot.efi
}

check_bless() {
	blessed=$(bless --info / | grep efi)
	blessed='/'${blessed#*/}
	if [[ "$blessed" != /System/Library/CoreServices/boot.efi ]]; then 
		efi_bless /System/Library/CoreServices boot.efi
	fi
}

# Check what current efi is installed and return either black, grey or default
check_efi() {
	res="default"
	xxd -p /System/Library/CoreServices/boot.efi | tr -d '\n' > /tmp/_boot.efi
	if ! $(grep -qa 4d61632d00000000000000000000000000000000 /tmp/_boot.efi); then 
		res="default"
	elif $(grep -qa 4d61632d7265706c616365207468697320747874 /tmp/_boot.efi); then 
		res="gray"
	else
		res="black"
	fi
	echo "$res"
}

# Backup efi file
backup_efi() {
	if [[ -e /System/Library/CoreServices/boot_stock.efi ]]; then sudo rm /System/Library/CoreServices/boot_stock.efi; fi
	sudo mv /System/Library/CoreServices/boot.efi /System/Library/CoreServices/boot_stock.efi
}

# Install custom efi
install_efi() {
	sudo rm /System/Library/CoreServices/boot.efi
	if [[ $boot_color = "black" ]]; then
		sudo cp "$app_dir"/_boot.efi /System/Library/CoreServices/boot.efi
	fi
	if [[ $boot_color = "grey" ]]; then
		sudo cp "$app_dir"/boot.efi /System/Library/CoreServices/boot.efi
	fi
}

# Restore stock efi
restore_efi() {
	if [[ -e /System/Library/CoreServices/boot_stock.efi ]]; then
		sudo rm /System/Library/CoreServices/boot.efi
		sudo mv /System/Library/CoreServices/boot_stock.efi /System/Library/CoreServices/boot.efi
	fi
}

# Clean up files and permissions
clean_up() {
	rm "$app_dir"/*boot.efi*
	rm /tmp/*boot.efi*
	sudo chmod 644 /System/Library/CoreServices/boot.efi
	sudo chown root:wheel /System/Library/CoreServices/boot.efi
	sudo chflags uchg /System/Library/CoreServices/boot.efi
}

PlistBuddy=/usr/libexec/PlistBuddy" -c"
scriptDirectory=$(cd "${0%/*}" && echo $PWD)
pashua_directory="$scriptDirectory"
for i in {1..3}; do pashua_directory=$(dirname "$pashua_directory"); done
info_directory=$(dirname "$pashua_directory")
app_dir="$HOME/Library/Application Support/dBoot"
my_plist="$HOME/Library/Preferences/org.w0lf.dBoot.plist"
dboot_efi="$pashua_directory"/boot.efi
curver=$($PlistBuddy "Print CFBundleShortVersionString" "$info_directory"/info.plist)
boot_color=$($PlistBuddy "Print color" "$my_plist" || echo -n "default")
cur_efi=$(check_efi)

if [[ $cur_efi != $boot_color ]]; then
	if [[ -e "$app_dir"/boot.efi ]]; then rm "$app_dir"/boot.efi; fi
	if [[ -e "$app_dir" ]]; then mkdir -p "$app_dir"; fi
	cp "$dboot_efi" "$app_dir"/boot.efi
	ask_pass
	sudo chflags nouchg /System/Library/CoreServices/boot.efi
	if [[ $boot_color = "default" ]]; then
		if [[ $cur_efi != "default" ]]; then
			echo -e "Restoring stock efi"
			restore_efi
		fi	
	else
		if [[ $cur_efi = "default" ]]; then
			echo -e "Backing up stock efi"
			backup_efi
		fi
		echo -e "Creating patched custom efi"
		patch_efi
		echo -e "Installing patched custom efi"
		install_efi
	fi
	echo -e "Cleaning up"
	clean_up
	echo -e "Checking bless"
	check_bless $boot_color
	bless --info / | head -2
fi

# End