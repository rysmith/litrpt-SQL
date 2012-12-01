#!/bin/bash
#file: litrpt_lfp.sh
#gathers information from documents produced in the course of litigation
#run in the top directory of the production
#use if the load file has the extension .lfp
#this report is formated for loading into the table "prod_rpts" in the mysql database "sandbox"

#general information for the production report from user input
echo "What is the Lainer client number?"
read client_number
echo "What is the Lanier client name?"
read client
echo "Who did this production come from?"
read party
echo "What production volume number was this?"
read volume
echo "What is the date of this production (yyyymmdd)?"
read prod_date

echo ""
echo "Great! Thanks for the input.  Generating SQL input statements and production messages..." 
echo ""

#collects the data from the load file (opt)
lfp_filepath="$1"
rpt_name=`date +%s`-$client.$party.$volume-litrpt.sql
rpt_num=`date +%s`
doc_prod_C=`grep ,C, "$lfp_filepath" | wc -l | tr -d ' '`
doc_prod_D=`grep ,D, "$lfp_filepath" | wc -l | tr -d ' '`
doc_prod=`expr $doc_prod_C + $doc_prod_D`
load_tif=`grep -i tif "$lfp_filepath" | wc -l | tr -d ' '`
load_jpg=`grep -i jpg "$lfp_filepath" | wc -l | tr -d ' '`
prod_size=`du -h . | tail -n 1 | rev | cut -d '.' -f 2- | rev | sed 's/[ \t]//g'`
beg_bates=`head -n 1 "$lfp_filepath" | cut -d ',' -f 2`
end_bates=`tail -n 1 "$lfp_filepath" | cut -d ',' -f 2`

#opens the output file for writing on FI 5
exec 5>~/rsmith/$rpt_name

#main body of the report writing to FI 5
#creats SQL input statements for report number, case number, client, party, volume number, date received, production size, beginning bates, ending bates, total documents produced, total TIF images produced, and total JPG images produced
echo "INSERT INTO prod_rpts (rpt_num) VALUES ($rpt_num);" >&5
echo "UPDATE prod_rpts SET LLF_num=$client_number WHERE rpt_num=$rpt_num;" >&5
echo "UPDATE prod_rpts SET client='$client' WHERE rpt_num=$rpt_num;" >&5
echo "UPDATE prod_rpts SET party='$party' WHERE rpt_num=$rpt_num;" >&5
echo "UPDATE prod_rpts SET vol='$volume' WHERE rpt_num=$rpt_num;" >&5
echo "UPDATE prod_rpts SET date=$prod_date WHERE rpt_num=$rpt_num;" >&5
echo "UPDATE prod_rpts SET du='$prod_size' WHERE rpt_num=$rpt_num;" >&5
echo "UPDATE prod_rpts SET beg='$beg_bates' WHERE rpt_num=$rpt_num;" >&5
echo "UPDATE prod_rpts SET end='$end_bates' WHERE rpt_num=$rpt_num;" >&5
echo "UPDATE prod_rpts SET doc_prod=$doc_prod WHERE rpt_num=$rpt_num;" >&5
echo "UPDATE prod_rpts SET load_tif=$load_tif WHERE rpt_num=$rpt_num;" >&5
echo "UPDATE prod_rpts SET load_jpg=$load_jpg WHERE rpt_num=$rpt_num;" >&5
echo "UPDATE prod_rpts SET pages=`expr $load_tif + $load_jpg` WHERE rpt_num=$rpt_num;" >&5

#identifies and counts file extensions, then creates the SQL input statements for them
ext_tmp=/tmp/ext_tmp
sorted_ext_tmp=/tmp/sorted_ext_tmp
counted_ext_tmp=/tmp/counted_ext_tmp

while read line; do 
	echo "${line##*.}" | tr '[A-Z]' '[a-z]'
done <<< "`find . -type f`" > $ext_tmp

sort -u $ext_tmp > $sorted_ext_tmp

while read line; do
	echo "$line:`grep -wi "$line" $ext_tmp | wc -l | tr -d ' '`"
done < $sorted_ext_tmp > $counted_ext_tmp

while read line; do
	if [[ `echo "DESC prod_rpts" | sandbox_sql.sh | grep -wi ${line%:*} | wc -l` == 1 ]] 
		then echo "UPDATE prod_rpts SET ${line%:*}=${line##*:} WHERE rpt_num=$rpt_num;"
		else echo "ALTER TABLE prod_rpts ADD ${line%:*} int(11) DEFAULT 0; UPDATE prod_rpts SET ${line%:*}=${line##*:} WHERE rpt_num=$rpt_num;"
	fi
done < $counted_ext_tmp >&5

#closes the output file from writing on FI 5
exec <&-

#checks for production processing errors and displays them on stdout
echo "**********************************************"
echo "*IMPORTANT MESSAGES REGARDING THIS PRODUCTION*"
echo "**********************************************"
echo "The SQL script is titled: $rpt_name"
if [[ $doc_prod == `grep txt $counted_ext_tmp | cut -d ':' -f 2` ]]
	then echo "OK - Document count and TXT file count match."
	else echo "Error - The document count and txt file count don't match.  Please investigate."
fi

if [[ $load_tif == `grep tif $counted_ext_tmp | cut -d ':' -f 2` ]]
	then echo "OK - TIF count in the load file and TIF count in the directories match."
	else echo "Error - The TIF count in the load file and the TIF count in the directories don't match.  Please investigate."
fi

if [[ $load_jpg == `grep jpg $counted_ext_tmp | wc -l` ]]
	then echo "OK - JPG count in the load file and JPG count in the directories match."
	else
		if [[ $load_jpg == `grep jpg $counted_ext_tmp | cut -d ':' -f 2` ]]
			then echo "OK - JPG count in the load file and JPG count in the directories match."
			else echo "Error - The JPG count in the load file and the JPG count in the directories don't match.  Please investigate."
		fi
fi

#previews the sql inputs statements on stdout
echo ""
echo "************************************************"
echo "*BELOW IS A PREVIEW OF THE SQL INPUT STATEMENTS*"
echo "************************************************"
cat ~/rsmith/$rpt_name
echo ""

rm $ext_tmp $sorted_ext_tmp $counted_ext_tmp

exit

