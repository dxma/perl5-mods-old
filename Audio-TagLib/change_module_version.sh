#!/bin/sh

for i in `find ./lib -name "*.pm"` ; do
	sed -i -e "s/\$VERSION = '1\.4\.1';/\$VERSION = '1\.41';/g" $i
done
