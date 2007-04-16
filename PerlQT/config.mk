################################################################
#### 
#### Author: Dongxu Ma <dongxu.ma@gmail.com>
#### License: GPLv2
#### 
################################################################

# QT4 META CONFIGURATION
_HEADER_DIR := /usr/include/qt4

# QT = QtCore   + QtGui + 
#      QtOpenGL + QtSvg + QtNetwork + QtSql + QtXml + 
#      Qt3Support
_QT         := QtCore QtGui QtOpenGL QtSvg QtNetwork QtSql QtXml \
               Qt3Support 

# QT-EXTRA = QtAssistant + QtDBus + QtUiTools + QtDesigner + QtTest 
_QT_EXTRA   := QtAssistant QtDBus QtUiTools QtDesigner QtTest

_HEADERS    := $(filter-out $(_HEADER_DIR)/QtCore/qatomic_%,     \
                   $(wildcard                                    \
                       $(addprefix $(_HEADER_DIR)/,              \
                           $(addsuffix /*.h, $(_QT)))))

# keep the order
# disable QT features here
_IMACROS            := QtCore/qfeatures.h QtCore/qconfig.h QtCore/qglobal.h
_CMD_PREPRO_HD_OPTS := $(addprefix -imacros ,\
                          $(addprefix $(_HEADER_DIR)/,$(_IMACROS)))
