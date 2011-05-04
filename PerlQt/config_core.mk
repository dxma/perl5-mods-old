################################################################
#### 
#### Author: Dongxu Ma <dongxu.ma@gmail.com>
#### License: Artistic
#### 
################################################################

# QT4 META CONFIGURATION
# this line will be scaned by script/gen_makefile_pl.pl
# no make variables inside, keep value in one line
_HEADER_DIR := /usr/include/qt4

# QT = QtCore   + QtGui + 
#      QtOpenGL + QtSvg + QtNetwork + QtSql + QtXml + 
#      Qt3Support
#_QT         := QtCore QtGui QtOpenGL QtSvg QtNetwork QtSql QtXml \
#               Qt3Support 
_QT := QtCore

# QT-EXTRA = QtAssistant + QtDBus + QtUiTools + QtDesigner + QtTest 
_QT_EXTRA := QtAssistant QtDBus QtUiTools QtDesigner QtTest

_HEADERS  := $(filter-out $(_HEADER_DIR)/QtCore/qatomic_%,     \
                   $(wildcard                                    \
                       $(addprefix $(_HEADER_DIR)/,              \
                           $(addsuffix /*.h, $(_QT)))))

HEADER_PREFIX := h

# imacros list
# which will be passed to preprocessor
# keep the order
# disable QT features here
_IMACROS := QtCore/qfeatures.h QtCore/qconfig.h QtCore/qglobal.h

# core define modules
# this line will be scaned by script/gen_makefile_pl.pl
# no make variables inside, keep value in one line
CORE_DEFINES     := -DQT_CORE_LIB -DQT_SHARED -DQT_NO_DEBUG
GUI_DEFINES      := -DQT_GUI_LIB
NETWORK_DEFINES  := -DQT_NETWORK_LIB
SQL_DEFINES      := -DQT_SQL_LIB
XML_DEFINES      := -DQT_XML_LIB
OPENGL_DEFINES   := -DQT_OPENGL_LIB
#QT3_DEFINES      := -DQT3_SUPPORT -DQT_QT3SUPPORT_LIB
QT3_DEFINES      := $(empty)$(empty)

# NOTE: keep the default visibility mark as 'Q_DECL_EXPORT'
#       or else normally it will be expanded to
#       '__attribute__((visibility("default")))' on Linux
#       '__declspec(dllexport)'                  on Windows
#       parser will benefit on such uniform look
# -DQT_VISIBILITY_AVAILABLE
EXTRA_DEFINES := -DQT_NO_KEYWORDS -DQ_DECL_EXPORT="Q_DECL_EXPORT"

ALL_DEFINES   := $(CORE_DEFINES) $(GUI_DEFINES) $(NETWORK_DEFINES) \
                 $(SQL_DEFINES) $(XML_DEFINES) $(OPENGL_DEFINES)   \
                 $(QT3_DEFINES) $(EXTRA_DEFINES)

# gcc
# only available on x86_64
_CMD_CC := g++

override MAKE_ROOT = .

# pkg-config --cflags --libs QtCore
# following is not used by GNUmakefile
# each line will be scaned by script/gen_makefile_pl.pl
# no make variables inside, keep value in one line
LDFLAGS := -L/usr/lib/qt4 -lQtCore
