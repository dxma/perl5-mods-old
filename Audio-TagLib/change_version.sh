#!/bin/sh

for i in `find ./lib -name "*.pm"` ; do
	sed -i -e 's/5\.008007;/5\.008003;/g' $i
done

sed -i -e 's/5\.008007;/5\.008003;/g' Makefile.PL
