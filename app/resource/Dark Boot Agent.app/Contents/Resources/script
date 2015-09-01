#! /bin/bash

efi_check() 
{
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

logging() 
{
	log_dir="$HOME/Library/Application Support/dBoot/logs"
	if [[ ! -e "$log_dir" ]]; then mkdir -pv "$log_dir"; fi
	for (( c=1; c<6; c++ )); do if [ ! -e "$log_dir"/${c}.log ]; then touch "$log_dir"/${c}.log; fi; done
	for (( c=5; c>1; c-- )); do cat "$log_dir"/$((c - 1)).log > "$log_dir"/${c}.log; done
	> "$log_dir"/agent.log
	exec &>"$log_dir"/agent.log
}

logging
PlistBuddy=/usr/libexec/PlistBuddy" -c"
scriptDirectory=$(cd "${0%/*}" && echo $PWD)
my_plist="$HOME/Library/Preferences/org.w0lf.dBoot.plist"
boot_color=$($PlistBuddy "Print color" "$my_plist" || printf "default")
cur_efi=$(efi_check)

echo "Current efi : $cur_efi"
echo "Selected efi : $boot_color"
if [[ $cur_efi != $boot_color ]]; then
	open "$scriptDirectory"/"Dark Boot Root".app
fi

# End