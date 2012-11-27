#!/bin/sh
# Author: Dongxu Ma

grep '#include "' $1 | cut -d'"' -f2
