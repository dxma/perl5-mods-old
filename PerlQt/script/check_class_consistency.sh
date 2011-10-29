#!/bin/sh
# Author: Dongxu Ma

# sanity check for stuff inside 04grouped

num_of_class=`ls $1 | gawk --field-separator=. '{ print $1 }' | sort | uniq | wc -l`
num_of_meta=`ls $1/*.meta | wc -l`

echo "class in total:" $num_of_class
echo "meta  in total:" $num_of_meta

if [[ $num_of_class==$num_of_meta+1 ]] ; then
	echo "ok"
else
	echo "not ok"
fi
