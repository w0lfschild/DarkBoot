#! /bin/bash

#####
#
#		Created By	:	w0lf
#		Project Page:	https://github.com/w0lfschild/DarkBoot		
#		Last Edited	:	Feb / 01 / 2015			
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

# Setup log files
logging() {
	log_dir="$HOME/Library/Application Support/dBoot/logs"
	if [[ ! -e "$log_dir" ]]; then mkdir -pv "$log_dir"; fi
	for (( c=1; c<6; c++ )); do if [ ! -e "$log_dir"/${c}.log ]; then touch "$log_dir"/${c}.log; fi; done
	for (( c=5; c>1; c-- )); do cat "$log_dir"/$((c - 1)).log > "$log_dir"/${c}.log; done
	> "$log_dir"/1.log
	exec &>"$log_dir"/1.log
}

# For root needs
ask_pass() {
	pass_window="$pass_window
	*.title = Dark Boot - $curver
	*.floating = 1
	*.transparency = 1.00
	*.autosavekey = dBoot
	pw0.type = password
	pw0.label = Enter your password to continue
	pw0.mandatory = 1
	pw0.width = 100
	pw0.x = -10
	pw0.y = 4"
	
	pashua_run "$pass_window" 'utf8' "$scriptDirectory"
	pass_window=""
	echo "$pw0" | sudo -Sv
	echo ""
	if [[ $pw0 = "" ]]; then echo -e "No password entered, quitting..."; exit; else pw0=""; fi
}

# Bless any efi 
# $1 = Folder
# $2 = File
bless_efi() {
	echo -e "$1/$2 blessed"
	pushd "$1" 1>/dev/null
	sudo bless --folder . --file "$2" --labelfile .disk_label
	popd 1>/dev/null
}

# Check what is currently blessed and then bless proper efi
check_bless() {
	blessed=$(bless --info / | grep efi)
	blessed='/'${blessed#*/}
	if [[ "$blessed" != /System/Library/CoreServices/boot.efi ]]; then 
		bless_efi /System/Library/CoreServices boot.efi
	fi
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

# Command line
cmd() {
	# -c COLOR
	# default, gray, black
	
	# -l LOGIN ITEM
	# yes, no
	
	echo "Sample Text"
}

main_method() {
	my_color=$($PlistBuddy "Print color" "$my_plist" || echo -n "default")
	login_items=$(osascript -e 'tell application "System Events" to get the name of every login item')
	if [[ "$login_items" = *"dBoot Agent"* ]]; then login_enabled=1; else login_enabled=0; fi
	main_window="$main_window
*.title = Dark Boot - $curver
*.floating = 1
*.transparency = 1.00
*.autosavekey = dBoot

db0.type = defaultbutton
db0.label = Apply

cb0.type = cancelbutton
cb0.label = Quit

textbx0.type = textbox
textbx0.width = 480
textbx0.height = 150
textbx0.disabled = 1
textbx0.rely = 10
textbx0.default = This application enables the black boot screen on unsupported Macs.[return]\
Confirmed working on OS X 10.10 to 10.10.2[return]\
Support for systems below Yosemite is currently unknown.[return][return]\
How to use:[return][return]\
• Select your desired Boot Color and press Apply[return]\
• Enter your password and press OK[return]\
• Reboot twice for changes to take effect[return][return]\
How to use command line:[return][return]\
• The following options are available:[return][return]\
	-c		Must be folowed by boot color -- black, grey, or default[return][return]\
	-l 		Login Item must be folowed by -- yes or no[return][return]\
• /Dark Boot.app/Contents/Resource/script -c black -l yes


tb0.type = text
tb0.height = 0
tb0.width = 150
tb0.default = Boot Color : 
tb0.x = 0
tb0.y = 25

pop0.type = popup
pop0.width = 120
pop0.option = default
pop0.option = gray
pop0.option = black
pop0.default = $my_color
pop0.x = 80
pop0.y = 21

chk0.tooltip = Check to make sure your selected option is enforced at every startup/login.
chk0.type = checkbox
chk0.label = Check at login
chk0.default = $login_enabled
chk0.x = 0
chk0.y = 4"
	pashua_run "$main_window" 'utf8' "$scriptDirectory"
	if [[ $db0 = "1" ]]; then
		boot_color=$pop0
		ask_pass
		sudo chflags nouchg /System/Library/CoreServices/boot.efi
		defaults write org.w0lf.dBoot color $boot_color
		if [[ -e "$app_dir"/boot.efi ]]; then rm "$app_dir"/boot.efi; fi
		if [[ -e "$app_dir" ]]; then mkdir -p "$app_dir"; fi
		cp "$dboot_efi" "$app_dir"/boot.efi
		cur_efi=$(check_efi)
		echo -e "Current efi : $cur_efi"
		echo -e "Selected efi : $boot_color"
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
		check_bless $pop0
		bless --info / | head -2
		echo -e "verigfying login item staus"
		if [[ $chk0 = "1" ]]; then
			if [[ $login_enabled = 0 ]]; then
				echo -e "Adding login item"
osascript <<EOD
tell application "System Events"
make new login item at end of login items with properties {path:"$helper", hidden:false}
end tell
EOD
			fi
		else
			if [[ $login_enabled = 1 ]]; then
				echo -e "Removing login item"
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
PlistBuddy=/usr/libexec/PlistBuddy" -c"
app_dir="$HOME/Library/Application Support/dBoot"
my_plist="$HOME/Library/Preferences/org.w0lf.dBoot.plist"
curver=$($PlistBuddy "Print CFBundleShortVersionString" "$app_directory"/Contents/Info.plist)
boot_color="default"
board_ID=""
board_HEX=""

# Run
logging
main_method

# End
