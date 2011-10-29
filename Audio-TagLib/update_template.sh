#!/bin/bash

for i in `ls script` ; do
	/usr/bin/perl script/$i
done
