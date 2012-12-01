#!/bin/bash

echo "Hello. Please provide the path to the production."
read prod_path

if [[ -d "$prod_path" ]]
	then cd "$prod_path"
	else echo "The production path you provided does not exist.  Process terminated."
			 exit
fi

path_2_opt=`find . -maxdepth 3 -type f | grep -i opt$`

if [[ -e "$path_2_opt" ]]
	then exec /home/ubuntu/bin/litrpt_opt.sh "$path_2_opt"
	else
		path_2_lfp=`find . -maxdepth 3 -type f | grep -i lfp$`
		if [[ -e "$path_2_lfp" ]]
			then exec /home/ubuntu/bin/litrpt_lfp.sh "$path_2_lfp"
			else exec /home/ubuntu/bin/litrpt_noload.sh
		fi
fi

exit

