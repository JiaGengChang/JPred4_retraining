#!/bin/bash
# this line allows use of hash tables

if [[ $# -ne 1 ]] ; then
	echo "Error, require exactly 1 argument which is the path to .sec file. Exiting script..."
	exit
fi

arg1=$1 # get the first (and only) argument
filename=${arg1##*/} # remove file path up to [seqID].sec
seqID=${filename::-4} # remove .sec extension from [seqID]

cat $1 | while read line; do 
	if [[ ${line::4} == "DSSP" ]] ; then 
		declare -A counts=( ["E"]=0 ["H"]=0 ["T"]=0 ["S"]=0 ["G"]=0 ["B"]=0 ["I"]=0 ["-"]=0);
		DSSP=${line:5:${#line}}; 
		n=${#DSSP};
		for (( i = 0; i < n; i++ )); do
			char=${DSSP:$i:1};
			if [[ $char =~ ',' ]] ; then
				continue;
			fi
			counts[$char]=$(( counts[$char]+1 ));
		done
		echo "$seqID ${counts[@]}" # output to stdout
		# echo "debuggin: ${!counts[@]}" # for debugging only
	fi
done
