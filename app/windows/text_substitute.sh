#!/bin/bash

# replace eng with translation
# required arg = lang

scriptDirectory=$(cd "${0%/*}" && echo $PWD)
lang_="$1"
fold_="$scriptDirectory"/"$lang_"
file_=("$fold_"/donors.txt "$fold_"/main.txt "$fold_"/settings.txt "$fold_"/welcome.txt)

for i in "${file_[@]}"
do
   :
   while read p; do
   	if [[ $p != "" ]]; then
   		#echo $p
   		text_tag=$(echo "$p" | cut -d= -f1)
   		#echo $text_tag
   		sed -i.bak s/"$text_tag.*"/"$p"/g "$i"
   	fi
   done <"$fold_"/"$lang_"_strings.txt
done

