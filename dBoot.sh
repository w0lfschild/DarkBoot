#! /bin/bash

#####
#
#		Created By	:	w0lf
#		Project Page:	https://github.com/w0lfschild/DarkBoot		
#		Last Edited	:	Jun / 11 / 2015			
#			
#####

# Functions

ask_pass() {
	pass_window="
	*.title = dBoot
	*.floating = 1
	*.transparency = 1.00
	*.autosavekey = dBoot_pass0
	pw0.type = password
	pw0.label = Password required to continue...
	pw0.mandatory = 1
	pw0.width = 100
	pw0.x = -10
	pw0.y = 4"

	pass_fail_window="
	*.title = dBoot
	*.floating = 1
	*.transparency = 1.00
	*.autosavekey = dBoot_pass1
	pw1.type = password
	pw1.label = Incorrect password, try again...
	pw1.mandatory = 1
	pw1.width = 100
	pw1.x = -10
	pw1.y = 4"
	
	pass_attempt=1
	pass_success=1
	pass_val=""
	while [[ $pass_attempt -lt 6 ]]; do
		sudo_status=$(sudo echo _success 2>&1)
		if [[ $sudo_status != "_success" ]]; then
			if [[ $pass_attempt > 1 ]]; then
				pashua_run "$pass_fail_window" 'utf8' "$scriptDirectory"
				pass_val="$pw1"
			else
				pashua_run "$pass_window" 'utf8' "$scriptDirectory"
				pass_val="$pw0"
			fi
			echo "$pass_val" | sudo -Sv
			sudo_status=$(sudo echo _success 2>&1)
			echo ""
			echo "Password attempt : "$pass_attempt
			echo "Sudo status : "$sudo_status
			if [[ $sudo_status = "_success" ]]; then
				pass_attempt=6
				pass_success=1
			else
				pass_attempt=$(( $pass_attempt + 1 ))
				echo -e "Incorrect or no password entered"
			fi
			pass_val=""
			pw0=""
			pw1=""
		else
			pass_attempt=6
			pass_success=1
			sudo -v
		fi
	done

	if [[ $pass_success = 1 ]]; then
		echo "..."
	fi
}
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

if [[ ! -e "$helper_2" ]]; then
	sudo mkdir -p /Library/Scripts/dBoot
	sudo cp -f "$helper_1" "$helper_2"
	sudo cp "$dboot_efi" /Library/Scripts/dBoot/boot.efi
	sudo chmod 755 "$helper_2"
fi

if [[ ! -e "$app_dir"/"dBoot Agent Launcher".app ]]; then
	cp -rf "$scriptDirectory"/"dBoot Agent Launcher".app "$app_dir"/
fi

if [[ $(sudo cat /etc/sudoers | grep dBoot) = "" ]]; then
	sudo touch /etc/sudoers
	# sudo echo "%sudo ALL=NOPASSWD: /Library/Scripts/dBoot/dBoot.sh" >> /etc/sudoers
	echo "%sudo ALL=NOPASSWD: /Library/Scripts/dBoot/dBoot.sh" | sudo tee -a /etc/sudoers
fi

echo "$helper_3"

osascript <<EOD
tell application "System Events"
make new login item at end of login items with properties {path:"$helper_3", hidden:false}
end tell
EOD

}
login_del() {
	
echo -e "Removing login item"

if [[ -e "$helper_2" ]]; then
	sudo rm -r /Library/Scripts/dBoot
fi

if [[ ! -e "$app_dir"/"dBoot Agent Launcher".app ]]; then
	rm -r "$app_dir"/"dBoot Agent Launcher".app
fi

if [[ $(sudo cat /etc/sudoers | grep dBoot) != "" ]]; then
	sudo touch /etc/sudoers
	# sudo echo "%sudo ALL=NOPASSWD: /Library/Scripts/dBoot/dBoot.sh" >> /etc/sudoers
fi

osascript <<EOD
tell application "System Events"
delete login item "dBoot Agent Launcher"
end tell
EOD

}	
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
update_check() {
	cur_date=$(date "+%y%m%d")
	lastupdateCheck=$($PlistBuddy "Print lastupdateCheck:" "$app_plist" 2>/dev/null || defaults write org.w0lf.dBoot "lastupdateCheck" 0 2>/dev/null)
	
	# Testing
	# curver=0
	# cur_date=0
	# lastupdateCheck=1
	
	# If we haven't already checked for updates today
	if [[ "$lastupdateCheck" != "$cur_date" ]]; then	
		results=$(ping -c 1 -t 5 "https://www.github.com" 2>/dev/null || echo "Unable to connect to internet")
		if [[ $results = *"Unable to"* ]]; then
			echo "ping failed : $results"
		else
			echo "ping success"
			beta_updates=$($PlistBuddy "Print betaUpdates:" "$app_plist" 2>/dev/null || echo -n 0)
			update_auto_install=$($PlistBuddy "Print autoInstall:" "$app_plist" 2>/dev/null || { defaults write org.w0lf.dBoot "autoInstall" 0; echo -n 0; } )
			update_auto_install=0
			
			# Stable urls
			dlurl=$(curl -s https://api.github.com/repos/w0lfschild/DarkBoot/releases/latest | grep 'browser_' | cut -d\" -f4)
			verurl="https://raw.githubusercontent.com/w0lfschild/DarkBoot/master/_resource/version.txt"
			logurl="https://raw.githubusercontent.com/w0lfschild/DarkBoot/master/_resource/versionInfo.txt"
		
			defaults write org.w0lf.dBoot "lastupdateCheck" "${cur_date}"
			./updates/wUpdater.app/Contents/MacOS/wUpdater c "$app_directory" org.w0lf.dBoot $curver $verurl $logurl $dlurl $update_auto_install &
		fi
	fi
}
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

	# OSX El Capitan Rootless
	OSX_version=$(sw_vers -productVersion)
	OSX_version=$(verres $OSX_version 10.11)
	if [[ $OSX_version != "<" ]]; then
		nvram_bootargs=$(nvram boot-args)
		are_we_rootless=0
		if [[ "$nvram_bootargs" = *"rootless=0"* ]]; then are_we_rootless=1; fi
		main_window="$main_window
mw_chk1.tooltip = Rootless must be disabled for Dark Boot to work on OSX 10.11+.
mw_chk1.type = checkbox
mw_chk1.label = Rootless disabled
mw_chk1.x = 110
mw_chk1.y = 4
mw_chk1.disabled = 1
mw_chk1.default = $are_we_rootless"
	fi

	pashua_run "$main_window" 'utf8' "$scriptDirectory"
	
	if [[ $mw_db0 = "1" ]]; then
		boot_color=$mw_pop0
		ask_pass
		if [[ $OSX_version != "<" ]]; then
			if [[ "$are_we_rootless" = "0" ]]; then
				draw_rootless_window
			fi
		fi
		sudo chflags nouchg /System/Library/CoreServices/boot.efi
		defaults write org.w0lf.dBoot color $boot_color
		if [[ -e "$app_dir"/boot.efi ]]; then rm "$app_dir"/boot.efi; fi
		if [[ -e "$app_dir" ]]; then mkdir -p "$app_dir"; fi
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
		echo -e "verigfying login item staus"
		if [[ $mw_chk0 = "1" ]]; then
			(($login_enabled)) || login_add
		else
			(($login_enabled)) && login_del
		fi
		echo "Done"
	fi
}
draw_rootless_window() {
	rootless_window=$(cat "$app_windows"/root_warning.txt)
	pashua_run "$rootless_window" 'utf8' "$scriptDirectory"
	
	if [[ $rw_db0 = "1" ]]; then
		# Add rootless=0 to nvram boot-args and reboot
		ba=$(nvram boot-args | sed -E "s/boot-args//g")
		sudo nvram boot-args="rootless=0 $(echo $ba)"
		sudo reboot
	else
		exit
	fi
}

logging

# Directories
scriptDirectory=$(cd "${0%/*}" && echo $PWD)
app_directory="$scriptDirectory"
for i in {1..2}; do app_directory=$(dirname "$app_directory"); done

lang=$(locale | grep LANG | cut -d\" -f2 | cut -d_ -f1)
if [[ -e "$scriptDirectory"/windows/"$lang" ]]; then
	app_windows="$scriptDirectory"/windows/"$lang"
else
	app_windows="$scriptDirectory"/windows/en
fi

# Variables
PlistBuddy=/usr/libexec/PlistBuddy" -c"
app_dir="$HOME/Library/Application Support/dBoot"
my_plist="$HOME/Library/Preferences/org.w0lf.dBoot.plist"
curver=$($PlistBuddy "Print CFBundleShortVersionString" "$app_directory"/Contents/Info.plist)
boot_color="default"
board_ID=""
board_HEX=""

# Files
dboot_efi="$scriptDirectory"/boot.efi
helper_1="$scriptDirectory"/"dBoot Agent".sh
helper_2=/Library/Scripts/dBoot/dBoot.sh
helper_3="$app_dir"/"dBoot Agent Launcher".app

# Run
update_check &
# draw_rootless_window
# exit
main_method

# End
