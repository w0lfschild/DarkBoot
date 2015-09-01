#! /bin/bash

# Created By	:	Wolfgang Baird
# Project Page	:	https://github.com/w0lfschild/DarkBoot

# Functions

check_bless() {
	blessed=$(bless --info / | grep efi)
	blessed='/'${blessed#*/}
	if [[ "$blessed" != /System/Library/CoreServices/boot.efi ]]; then 
		efi_bless /System/Library/CoreServices boot.efi
	fi
}

clean_up() {
	rm "$app_dir"/*boot.efi*
	# rm /tmp/*boot.efi*
	sudo chmod 644 /System/Library/CoreServices/boot.efi
	sudo chown root:wheel /System/Library/CoreServices/boot.efi
	sudo chflags uchg /System/Library/CoreServices/boot.efi
}

efi_backup() {
	if [[ -e /System/Library/CoreServices/boot_stock.efi ]]; then sudo rm /System/Library/CoreServices/boot_stock.efi; fi
	sudo mv /System/Library/CoreServices/boot.efi /System/Library/CoreServices/boot_stock.efi
}

efi_bless() {
	echo -e "$1/$2 blessed"
	pushd "$1" 1>/dev/null
	sudo bless --folder . --file "$2" --labelfile .disk_label
	popd 1>/dev/null
}

efi_check() {
	res="default"
	xxd -p /System/Library/CoreServices/boot.efi | tr -d '\n' > /tmp/_boot.efi
	if ! $(grep -qa 4d61632d00000000000000000000000000000000 /tmp/_boot.efi); then 
		res="default"
	elif $(grep -qa 4d61632d7265706c616365207468697320747874 /tmp/_boot.efi); then 
		res="gray"
	else
		res="black"
	fi
	rm /tmp/_boot.efi
	echo -n "$res"
}

efi_install() {
	sudo rm /System/Library/CoreServices/boot.efi
	if [[ $boot_color = "black" ]]; then
		sudo cp "$app_dir"/_boot.efi /System/Library/CoreServices/boot.efi
	fi
	if [[ $boot_color = "grey" ]]; then
		sudo cp "$app_dir"/boot.efi /System/Library/CoreServices/boot.efi
	fi
}

efi_patch() {
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

efi_restore() {
	if [[ -e /System/Library/CoreServices/boot_stock.efi ]]; then
		sudo rm /System/Library/CoreServices/boot.efi
		sudo mv /System/Library/CoreServices/boot_stock.efi /System/Library/CoreServices/boot.efi
	fi
}

logging() {
	log_dir="$HOME/Library/Application Support/dBoot/logs"
	if [[ ! -e "$log_dir" ]]; then mkdir -pv "$log_dir"; fi
	for (( c=1; c<6; c++ )); do if [ ! -e "$log_dir"/${c}.log ]; then touch "$log_dir"/${c}.log; fi; done
	for (( c=5; c>1; c-- )); do cat "$log_dir"/$((c - 1)).log > "$log_dir"/${c}.log; done
	> "$log_dir"/1.log
	exec &>"$log_dir"/1.log
}

login_add() {
	
	echo -e "Adding login item"
	osascript -e "tell application \"System Events\" to delete login items \"Dark Boot Agent\""
	osascript -e "tell application \"System Events\" to make new login item at end of login items with properties {path:\"$my__agent\", hidden:false}"

}

login_del() {
	
	echo -e "Removing login item"
	osascript -e "tell application \"System Events\" to delete login items \"Dark Boot Agent\""

}

# Main window

main_method() {
	my_color=$(efi_check)
	login_items=$(osascript -e 'tell application "System Events" to get the name of every login item')
	if [[ "$login_items" = *"dBoot Agent Launcher"* ]]; then login_enabled=1; else login_enabled=0; fi
	
	app_info=$(tr -d '\n' < "$app_windows"/info.txt)
	main_window=$(cat "$app_windows"/main.txt)
	main_window="$main_window
	*.title = Dark Boot - $curver
	mw_textbx0.default = $app_info
	mw_pop0.default = $my_color
	mw_chk0.default = $login_enabled
	"

	sys_isrootless=1
	if [[ $(sw_vers -productVersion | cut -f2 -d.) -gt "10" ]]; then
		# El Capitan or newer detected
		
		error_capture=$( touch /System/test 2>&1 )
		if [[ $error_capture == *"Operation not permitted"* ]]; then
			# Expected output is Permission denied on system with rootless off
			sys_isrootless=0
		fi

		main_window="$main_window
		mw_chk1.tooltip = Rootless must be disabled for Dark Boot to work on OSX 10.11+.
		mw_chk1.type = checkbox
		mw_chk1.label = Rootless disabled
		mw_chk1.x = 110
		mw_chk1.y = 4
		mw_chk1.disabled = 1
		mw_chk1.default = $sys_isrootless"
	fi

	pashua_run "$main_window" 'utf8' "$scriptDirectory"
	
	if [[ $mw_db0 = "1" ]]; then
		boot_color=$mw_pop0

		if [[ "$sys_isrootless" = "0" ]]; then

			# Show rootless window
			rootless_window=$(cat "$app_windows"/root_warning.txt)
			pashua_run "$rootless_window" 'utf8' "$scriptDirectory"
			exit

		elif [[ $(ask_pass "Dark Boot") == "_success" ]]; then

			# Got privledges
			sudo chflags nouchg /System/Library/CoreServices/boot.efi
			defaults write org.w0lf.dBoot color $boot_color
			if [[ -e "$app_dir"/boot.efi ]]; then rm "$app_dir"/boot.efi; fi
			if [[ ! -e "$app_dir" ]]; then mkdir -p "$app_dir"; fi
			cp "$dboot_efi" "$app_dir"/boot.efi
			cur_efi=$(efi_check)
			echo -e "Current efi : $cur_efi"
			echo -e "Selected efi : $boot_color"
			if [[ $boot_color = "default" ]]; then
				if [[ $cur_efi != "default" ]]; then
					echo -e "Restoring stock efi"
					efi_restore
				fi	
			else
				if [[ $cur_efi = "default" ]]; then
					echo -e "Backing up stock efi"
					efi_backup
				fi
				echo -e "Creating patched custom efi"
				efi_patch
				echo -e "Installing patched custom efi"
				efi_install
			fi
			echo -e "Cleaning up"
			clean_up
			echo -e "Checking bless"
			check_bless $boot_color
			bless --info / | head -2
			echo -e "verifying login item status"
			if [[ $mw_chk0 = "1" ]]; then
				(($login_enabled)) || login_add
			else
				(($login_enabled)) && login_del
			fi
			say "Done"

		else

			# Got nothing
			echo "Did not receive root privileges"

		fi
	fi
}

source ./functions/shared_functions.sh

logging

# Directories
scriptDirectory=$(cd "${0%/*}" && echo $PWD)
app_directory="$scriptDirectory"
for i in {1..2}; do app_directory=$(dirname "$app_directory"); done


app_windows="$scriptDirectory"/windows/en
lang=$($PlistBuddy "print AppleLanguages:0" "$home/Library/Preferences/.GlobalPreferences.plist")
if [[ $lang = "" ]]; then
	lang=$($PlistBuddy "print AppleLocale" "$home/Library/Preferences/.GlobalPreferences.plist" | cut -d_ -f1)
fi
if [[ $lang != "" ]]; then
	if [[ -e "$scriptDirectory"/windows/"$lang" ]]; then
		app_windows="$scriptDirectory"/windows/"$lang"
	fi
fi

# Variables
PlistBuddy=/usr/libexec/PlistBuddy" -c"
app_dir="$HOME/Library/Application Support/dBoot"
my_plist="$HOME/Library/Preferences/org.w0lf.dBoot.plist"
curver=$($PlistBuddy "Print CFBundleShortVersionString" "$app_directory"/Contents/Info.plist)
boot_color="default"
board_ID=""
board_HEX=""

# Agent
dboot_efi="$scriptDirectory"/boot.efi
my__agent="$scriptDirectory"/"Dark Boot Agent".sh

update_check \
"https://api.github.com/repos/w0lfschild/DarkBoot/releases/latest" \
"https://raw.githubusercontent.com/w0lfschild/DarkBoot/master/_resource/version.txt" \
"https://raw.githubusercontent.com/w0lfschild/DarkBoot/master/_resource/versionInfo.txt" \
"$my_plist" \
"$scriptDirectory"/updates/wUpdater.app/Contents/MacOS/wUpdater \
"$app_directory" \
"$curver" \
"n" \
"1" &

main_method

# End
