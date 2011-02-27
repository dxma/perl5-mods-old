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
#_QT         := QtCore QtGui QtOpenGL QtSvg QtNetwork QtSql QtXml \
#               Qt3Support 
_QT         := QtCore

# QT-EXTRA = QtAssistant + QtDBus + QtUiTools + QtDesigner + QtTest 
_QT_EXTRA   := QtAssistant QtDBus QtUiTools QtDesigner QtTest

_HEADERS    := $(filter-out $(_HEADER_DIR)/QtCore/qatomic_%,     \
                   $(wildcard                                    \
                       $(addprefix $(_HEADER_DIR)/,              \
                           $(addsuffix /*.h, $(_QT)))))

HEADER_PREFIX  := h

# imacros list
# which will be passed to preprocessor
# keep the order
# disable QT features here
_IMACROS            := QtCore/qfeatures.h QtCore/qconfig.h QtCore/qglobal.h

# core define modules
CORE_DEFINE     := -DQT_CORE_LIB
GUI_DEFINE      := -DQT_GUI_LIB
NETWORK_DEFINE  := -DQT_NETWORK_LIB
SQL_DEFINE      := -DQT_SQL_LIB
XML_DEFINE      := -DQT_XML_LIB
OPENGL_DEFINE   := -DQT_OPENGL_LIB
#QT3_DEFINE      := -DQT3_SUPPORT -DQT_QT3SUPPORT_LIB
QT3_DEFINE      := $(empty)$(empty)

# NOTE: keep the default visibility mark as 'Q_DECL_EXPORT'
#       or else normally it will be expanded to
#       '__attribute__((visibility("default")))' on Linux
#       '__declspec(dllexport)'                  on Windows
#       parser will benefit on such uniform look
# -DQT_VISIBILITY_AVAILABLE
EXTRA_DEFINES   := -DQT_SHARED -DQT_NO_DEBUG -DQT_NO_KEYWORDS     \
                   -DQ_DECL_EXPORT="Q_DECL_EXPORT"

ALL_DEFINES     := $(CORE_DEFINE) $(GUI_DEFINE) $(NETWORK_DEFINE) \
                   $(SQL_DEFINE) $(XML_DEFINE) $(OPENGL_DEFINE)   \
                   $(QT3_DEFINE) $(EXTRA_DEFINES)

# gcc
# only available on x86_64
_CMD_CC        := g++

override MAKE_ROOT  = .
