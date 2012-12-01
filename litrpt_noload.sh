#!/bin/bash
#file:
#gathers information from documents produced in the course of litigation
#run in the top directory of the production
#use if no load file was provided

#general information for the production report from user input 
echo "What is the Lainer client number?"
read client_number
echo "What is the client name?"
read client
echo "Who did this production come from?"
read party
echo "What production volume number is this?"
read volume
echo "What is the date of this  production (yyyymmdd)?"
read prod_date
echo "What is the beginning bates number?"
read beg_bates
echo "What is the ending bates number?"
read end_bates

echo ""
echo "Great! Thanks for the input.  Generating SQL input statement..."
echo ""

#generates a unique file name
#generates a unique production report number
rpt_name=`date +%s`-$client.$party.$volume-litrpt.sql
rpt_num=`date +%s`
prod_size=`du -h . | tail -n 1 | rev | cut -d '.' -f 2- | rev | sed 's/[ \t]//g'`

#opens the output file for writing on FI 5
exec 5>~/rsmith/$rpt_name

#main body of the report writing on FI 5
echo "INSERT INTO prod_rtps (rpt_num) VALUES ($rpt_num);" >&5
echo "UPDATE prod_rpts SET LLF_num=$client_number WHERE rpt_num=$rpt_num;" >&5
echo "UPDATE prod_rpts SET client='$client' WHERE rpt_num=$rpt_num;" >&5
echo "UPDATE prod_rpts SET party='$party' WHERE rpt_num=$rpt_num;" >&5
echo "UPDATE prod_rpts SET vol='$volume' WHERE rpt_num=$rpt_num;" >&5
echo "UPDATE prod_rpts SET date=$prod_date WHERE rpt_num=$rpt_num;" >&5
echo "UPDATE prod_rpts SET du='$prod_size' WHERE rpt_num=$rpt_num;" >&5
echo "UPDATE prod_rpts SET beg='$beg_bates' WHERE rpt_num=$rpt_num;" >&5
echo "UPDATE prod_rpts SET end='$end_bates' WHERE rpt_num=$rpt_num;" >&5

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

echo "**********************************************"
echo "*IMPORTANT MESSAGES REGARDING THIS PRODUCTION*"
echo "**********************************************"
echo "The SQL script is titled: $rpt_name"
if [[ `grep pdf $sorted_ext_tmp | wc -l` == 1 ]]
	then echo "UPDATE prod_rpts SET doc_prod=`grep pdf $counted_ext_tmp | cut -d ':' -f 2` WHERE rpt_num=$rpt_num" >&5
			 echo "It has been assumed that the total number of PDF's is the same as the document total."
	else echo "There were no PDF's in this production. The field "doc_prod" has not been set.  Please update manually."
fi
echo ""

#closes the output file from writing on FI 5
exec <&-

echo "************************************************"
echo "*BELOW IS A PREVIEW OF THE SQL INPUT STATEMENTS*"
echo "************************************************"
cat ~/rsmith/$rpt_name

rm $ext_tmp $sorted_ext_tmp $counted_ext_tmp

exit
