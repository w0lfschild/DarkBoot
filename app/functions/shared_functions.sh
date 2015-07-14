#! /bin/bash

# Shared Functions

# Update check required args
#
# 1 dlurl
# 2 verurl
# 3 logurl
# 4 app plist
# 5 wupdater_path
# 6 app_directory
# 7 curver
# 8 update_interval >> n(ow) / d(aily) / w(eekly)
# 9 github >> 0 / 1

ask_pass() {
	pass_window="
	*.title = $1
	*.floating = 1
	*.autosavekey = ask_pass_window

	apw_0.type = password
	apw_0.label = Password required to continue.
	apw_0.mandatory = 1

	apw_1.type = cancelbutton
	apw_1.label = Cancel"

	pass_fail_window="
	*.title = $1
	*.floating = 1
	*.autosavekey = ask_pass_fail

	apw_0.type = password
	apw_0.label = Password required to continue.
	apw_0.mandatory = 1

	apw_1.type = cancelbutton
	apw_1.label = Cancel"

	pass_attempt=0
	pass_success=0
	apw_1=0
	while [[ $pass_attempt -lt 5 ]]; do
		sudo_status=$(sudo echo null 2>&1)
		if [[ $sudo_status != "null" ]]; then
			if [[ $pass_attempt > 0 ]]; then
				pashua_run "$pass_fail_window" 'utf8' "$scriptDirectory"
			else
				pashua_run "$pass_window" 'utf8' "$scriptDirectory"
			fi
			if [[ "$apw_1" = 1 ]]; then
				echo -e "No password entered, canceled"
				break
			fi
			echo "$apw_0" | sudo -Sv
			sudo_status=$(sudo echo null 2>&1)
			if [[ $sudo_status = "null" ]]; then
				pass_attempt=5
				pass_success=1
			else
				pass_attempt=$(( $pass_attempt + 1 ))
				echo -e "Incorrect password entered"
			fi
			apw_0=""
		else
			pass_attempt=5
			pass_success=1
			sudo -v
		fi
	done

	if [[ $pass_success = 1 ]]; then
		echo "_success"
	fi
}

update_check() {
	cur_date=$(date "+%y%m%d")
  	lastupdateCheck=$($PlistBuddy "Print lastupdateCheck:" "$4" 2>/dev/null || { defaults write "$4" "lastupdateCheck" 0 2>/dev/null; echo -n 0; })
	if [[ "$8" = "w" ]]; then
  		weekly=$((lastupdateCheck + 7))
    	if [[ "$weekly" = "$cur_date" ]]; then
    		update_check_step2 "$@"
    	fi
  	elif [[ "$8" = "n" ]]; then
  		update_check_step2 "$@"
	else
		if [[ "$lastupdateCheck" != "$cur_date" ]]; then
  			update_check_step2 "$@"
  		fi
  	fi
}

update_check_step2() {
	cur_date=$(date "+%y%m%d")
	results=$(ping -c 1 -t 5 "https://www.github.com" 2>/dev/null || echo "Unable to connect to internet")
  	if [[ $results = *"Unable to"* ]]; then
		echo "Ping Failed : $results"
  	else
    	echo "Checking for updates..."
    	beta_updates=$($PlistBuddy "Print betaUpdates:" "$4" 2>/dev/null || { defaults write "$4" "betaUpdates" 0; echo -n 0; })
	    auto_install=$($PlistBuddy "Print autoInstall:" "$4" 2>/dev/null || { defaults write "$4" "autoInstall" 0; echo -n 0; })

	    # Stable urls

	    if [[ "$9" == "1" ]]; then
	    	dlurl=$(curl -s "$1" | grep 'browser_' | cut -d\" -f4)
	    else
	    	dlurl="$1"
	    fi

	    defaults write "$4" "lastupdateCheck" "${cur_date}"
	    "$5" c "$6" "$4" "$7" "$2" "$3" "$dlurl" "$auto_install" &
  	fi
}

pashua_run() {
	# Write config file
	pashua_configfile=`/usr/bin/mktemp /tmp/pashua_XXXXXXXXX`
	echo "$1" > $pashua_configfile

	# Find Pashua binary. We do search both . and dirname "$0"
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

plistbud() {
	pb=/usr/libexec/PlistBuddy" -c"
	# $1 - Set or Delete
	# $2 - name
	# $3 - type
	# $4 - value
	# $5 - plist
	if [[ $1 = "Set" ]]; then
		$pb "Set $2 $4" "$5" 2>/dev/null || $pb "Add $2 $3 $4" "$5"
	elif [[ $1 = "Delete" ]]; then
		$pb "Delete $2" "$5"
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