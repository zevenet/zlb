#!/bin/bash

# It applies format to the tpl directory files.
# Review:
# 	remove tail comma
#   replace valid_format by regex
#	replace single quote by double quote
#	replace => by :
if [[ -s $1 && $1 != "-f" ]]; then
	echo "Option not valid"
	echo "Usage: $0 [-f]"
	echo "  -f, do not ask for confirmation to apply files"
	exit 1;
fi
dir="./tpl"
tmp="/tmp/jq"
tmp2="/tmp/jq2"
for file in `ls $dir`
do

f="$dir/$file"
echo "$f"

cat $f | tr -d '\n'| sed -E 's/,\s*\}/\}/g' | sed -E 's/,\s*\]/\]/g' >$tmp
if [[ $? -ne 0 || -z $tmp ]]; then
	echo "Error: $f removing tail comma"
	exit 1
fi

# replace '
sed -i "s,',\",g" $tmp

# replace =>
sed -i 's,=>,:,g' $tmp

# replace valid_format by regex
sed -E -i 's/"valid_format"\s*:\s*"/"regex" : "\$/g' $tmp

# tab properly
cat $tmp | jq --tab . > $tmp2
if [[ $? -eq 0 && -s $tmp2 ]]; then
	mv $tmp2 $tmp
else
	echo "Error: $f does not have valid JSON format"
	if [[ -s $tmp2 ]]; then
		cat $tmp2
	else
		cat $tmp
	fi

	exit 1
fi

diff $f $tmp
if [[ $? -ne 0 ]]; then
	if [[ $1 == "-f" ]]; then
		mv $tmp $f
	else
		echo -n "The file $f has changes, do you want to apply them? [y/N] "
		read input
		if [[ $input =~ y|Y ]]; then
			echo "Replaced!"
			mv $tmp $f
		fi
	fi
fi

done

exit 0
