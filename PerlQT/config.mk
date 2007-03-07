################################################################
#### 
#### Author: Dongxu Ma <dongxu.ma@gmail.com>
#### License: GPLv2
#### 
################################################################

# QT4 META CONFIGURATION
_HEADER_DIR := /usr/include/qt4

_HEADERS    := $(filter-out $(_HEADER_DIR)/QtCore/qatomic_%,\
                     $(wildcard $(_HEADER_DIR)/*/*.h))