#! /bin/bash

check_bless() {
	blessed=$(bless --info / | grep efi)
	blessed='/'${blessed#*/}
	if [[ "$blessed" != /System/Library/CoreServices/boot.efi ]]; then 
		efi_bless /System/Library/CoreServices boot.efi
	fi
}
clean_up() {
	rm "$app_dir"/*boot.efi*
	chmod 644 /System/Library/CoreServices/boot.efi
	chown root:wheel /System/Library/CoreServices/boot.efi
	chflags uchg /System/Library/CoreServices/boot.efi
}
efi_backup() {
	if [[ -e /System/Library/CoreServices/boot_stock.efi ]]; then rm /System/Library/CoreServices/boot_stock.efi; fi
	mv /System/Library/CoreServices/boot.efi /System/Library/CoreServices/boot_stock.efi
}
efi_bless() {
	printf "$1/$2 blessed\n"
	pushd "$1" 1>/dev/null
	bless --folder . --file "$2" --labelfile .disk_label
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
	printf "$res"
}
efi_install() {
	rm /System/Library/CoreServices/boot.efi
	if [[ $boot_color = "black" ]]; then
		cp "$app_dir"/_boot.efi /System/Library/CoreServices/boot.efi
	fi
	if [[ $boot_color = "grey" ]]; then
		cp "$app_dir"/boot.efi /System/Library/CoreServices/boot.efi
	fi
}
efi_patch() {
	board_ID=$(ioreg -p IODeviceTree -r -n / -d 1 | grep board-id)
	board_ID=${board_ID##*<\"}
	board_ID=${board_ID%%\">}
	printf "Board-ID : $board_ID\n"

	board_HEX=$(printf $board_ID | xxd -ps)
	while [[ ${#board_HEX} -lt 40 ]]; do board_HEX=${board_HEX}0; done
	printf "Board-ID Hex : $board_HEX\n"
	
	printf "Converting boot.efi to hex\n"
	xxd -p "$app_dir"/boot.efi | tr -d '\n' > "$app_dir"/___boot.efi
	
	printf "Adding your board ID\n"
	sed -i -e "s|4d61632d7265706c616365207468697320747874|$board_HEX|g" "$app_dir"/___boot.efi
	
	printf "Moving files and cleaning up $app_dir\n"
	perl -pe 'chomp if eof' "$app_dir"/___boot.efi > "$app_dir"/__boot.efi
	xxd -r -p "$app_dir"/__boot.efi "$app_dir"/_boot.efi
}
efi_restore() {
	if [[ -e /System/Library/CoreServices/boot_stock.efi ]]; then
		rm /System/Library/CoreServices/boot.efi
		mv /System/Library/CoreServices/boot_stock.efi /System/Library/CoreServices/boot.efi
	fi
}
logging() {
	log_dir="$HOME/Library/Application Support/dBoot/logs"
	if [[ ! -e "$log_dir" ]]; then mkdir -pv "$log_dir"; fi
	for (( c=1; c<6; c++ )); do if [ ! -e "$log_dir"/${c}.log ]; then touch "$log_dir"/${c}.log; fi; done
	for (( c=5; c>1; c-- )); do cat "$log_dir"/$((c - 1)).log > "$log_dir"/${c}.log; done
	> "$log_dir"/root.log
	exec &>"$log_dir"/root.log
}

logging

PlistBuddy=/usr/libexec/PlistBuddy" -c"
scriptDirectory=$(cd "${0%/*}" && echo $PWD)
app_dir="$HOME/Library/Application Support/dBoot"
my_plist="$HOME/Library/Preferences/org.w0lf.dBoot.plist"
dboot_efi="$scriptDirectory"/boot.efi
boot_color=$($PlistBuddy "Print color" "$my_plist" || printf "default")
cur_efi=$(efi_check)

printf "Current efi : $cur_efi\n"
printf "Selected efi : $boot_color\n"
if [[ $cur_efi != $boot_color ]]; then
	chflags nouchg /System/Library/CoreServices/boot.efi
	if [[ -e "$app_dir"/boot.efi ]]; then rm "$app_dir"/boot.efi; fi
	if [[ -e "$app_dir" ]]; then mkdir -p "$app_dir"; fi
	cp "$dboot_efi" "$app_dir"/boot.efi
	if [[ $boot_color = "default" ]]; then
		if [[ $cur_efi != "default" ]]; then
			printf "Restoring stock efi\n"
			efi_restore
		fi	
	else
		if [[ $cur_efi = "default" ]]; then
			printf "Backing up stock efi\n"
			efi_backup
		fi
		printf "Creating patched custom efi\n"
		efi_patch
		printf "Installing patched custom efi\n"
		efi_install
	fi
	printf "Cleaning up\n"
	clean_up
	printf "Checking bless\n"
	check_bless $boot_color
	bless --info / | head -2
	printf "Done\n"
fi

# End