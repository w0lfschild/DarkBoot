#! /bin/bash

#####
#
#		Created By	:	w0lf
#		Project Page:	https://github.com/w0lfschild/DarkBoot		
#		Last Edited	:	May / 09 / 2015			
#			
#####

check_bless() {
	blessed=$(bless --info / | grep efi)
	blessed='/'${blessed#*/}
	if [[ "$blessed" != /System/Library/CoreServices/boot.efi ]]; then 
		efi_bless /System/Library/CoreServices boot.efi
	fi
}
clean_up() {
	rm "$app_dir"/*boot.efi*
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
	log_dir="$HOME/Library/Application Support/dBoot/logs_agent"
	if [[ ! -e "$log_dir" ]]; then mkdir -pv "$log_dir"; fi
	for (( c=1; c<6; c++ )); do if [ ! -e "$log_dir"/${c}.log ]; then touch "$log_dir"/${c}.log; fi; done
	for (( c=5; c>1; c-- )); do cat "$log_dir"/$((c - 1)).log > "$log_dir"/${c}.log; done
	> "$log_dir"/1.log
	exec &>"$log_dir"/1.log
}

logging

PlistBuddy=/usr/libexec/PlistBuddy" -c"
scriptDirectory=$(cd "${0%/*}" && echo $PWD)
app_dir="$HOME/Library/Application Support/dBoot"
my_plist="$HOME/Library/Preferences/org.w0lf.dBoot.plist"
dboot_efi=/Library/Scripts/dBoot/boot.efi
boot_color=$($PlistBuddy "Print color" "$my_plist" || echo "default")
cur_efi=$(efi_check)
login_items=$(osascript -e 'tell application "System Events" to get the name of every login item')
if [[ "$login_items" = *"dBoot.sh"* ]]; then login_enabled=1; else login_enabled=0; fi

echo -e "Current efi : $cur_efi"
echo -e "Selected efi : $boot_color"
if [[ $cur_efi != $boot_color ]]; then
	sudo chflags nouchg /System/Library/CoreServices/boot.efi
	if [[ -e "$app_dir"/boot.efi ]]; then rm "$app_dir"/boot.efi; fi
	if [[ -e "$app_dir" ]]; then mkdir -p "$app_dir"; fi
	cp "$dboot_efi" "$app_dir"/boot.efi
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
	echo "Done"
fi

# End