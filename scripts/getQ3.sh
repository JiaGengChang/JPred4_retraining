#!/usr/bin/bash

if [[ $# -ne 2 ]]; then
	echo "wrong number of arguments. expect path to the .csv score file, and path to output file. Exiting."
	exit;
fi

file=$1
out=$2

cat $file | while IFS="," read -ra line; do
		
	if [[ ${line[0]} =~ 'seqID' ]]; then
		# do nothing
		echo "${line[@]} Q3_accuracy H_content E_content C_content" >> $out
		continue

	fi
	
	# OBTAIN VALUES	
	Q3=$(echo "scale=5; ${line[7]} / ${line[8]} "|bc)
	H_content=$(echo "scale=5; ${line[2]} / ${line[8]} "|bc) 
	E_content=$(echo "scale=5; ${line[4]} / ${line[8]} "|bc)
	C_content=$(echo "scale=5; ${line[6]} / ${line[8]} "|bc)

	echo "${line[@]} $Q3 $H_content $E_content $C_content" >> $out
	
	

done
