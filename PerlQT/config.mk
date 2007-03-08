################################################################
#### 
#### Author: Dongxu Ma <dongxu.ma@gmail.com>
#### License: GPLv2
#### 
################################################################

# QT4 META CONFIGURATION
_HEADER_DIR := /usr/include/qt4

_HEADERS    := $(filter-out $(_HEADER_DIR)/QtCore/qatomic_%,\
                   $(wildcard $(_HEADER_DIR)/*/*.h)         \
                   $(wildcard $(_HEADER_DIR)/*/*/*.h))

# keep the order
# disable QT features here
_IMACROS            := QtCore/qfeatures.h QtCore/qconfig.h QtCore/qglobal.h
_CMD_PREPRO_HD_OPTS := $(addprefix -imacros ,\
                          $(addprefix $(_HEADER_DIR)/,$(_IMACROS)))
