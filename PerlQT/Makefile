################################################################
####
#### Author: Dongxu Ma <dongxu.ma@gmail.com>
#### License: GPLv2 
####
################################################################

#################### META CONFIG ###############################
include config.mk

#################### QT FLAGS ##################################

# modules
CORE_DEFINE     := -DQT_CORE_LIB
GUI_DEFINE      := -DQT_GUI_LIB
NETWORK_DEFINE  := -DQT_NETWORK_LIB
SQL_DEFINE      := -DQT_SQL_LIB
XML_DEFINE      := -DQT_XML_LIB
OPENGL_DEFINE   := -DQT_OPENGL_LIB
QT3_DEFINE      := -DQT3_SUPPORT -DQT_QT3SUPPORT_LIB

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

#################### DIRECTORY STRUCTURES ######################

# FIXME: oops on MSWin32, unknown on Darwin
# always try to be absolute

MAKE_ROOT       := $(shell pwd)
HEADER_DIR      := $(_HEADER_DIR)
SCRIPT_DIR      := $(MAKE_ROOT)/script

IN_STRIP_DIR    := $(HEADER_DIR)
OUT_STRIP_DIR   := $(MAKE_ROOT)/00stripped

IN_PREPRO_DIR   := $(OUT_STRIP_DIR)
OUT_PREPRO_DIR  := $(MAKE_ROOT)/01preprocessed

IN_PARSE_DIR    := $(OUT_PREPRO_DIR)
OUT_PARSE_DIR   := $(MAKE_ROOT)/02parsed

IN_FORMAT_DIR   := $(OUT_PARSE_DIR)
OUT_FORMAT_DIR  := $(MAKE_ROOT)/03formatted

IN_GROUP_DIR    := $(OUT_FORMAT_DIR)
OUT_GROUP_DIR   := $(MAKE_ROOT)/04grouped

IN_XSCODE_DIR   := $(OUT_GROUP_DIR)
OUT_XSCODE_DIR  := $(MAKE_ROOT)/99xscode

#################### MAKE TOOLS ################################

# DEBUG echos all shell commands
ifndef DEBUG
_Q              := @
else
_Q              := $(empty)$(empty)
endif

# FIXME: check available options for all involved commands
CMD_CC          := g++
# intepretable echo
CMD_ECHO        := echo -e
CMD_PREPRO      := $(CMD_CC) -E
CMD_PARSE       := $(SCRIPT_DIR)/parse_header.pl
CMD_MKDIR       := mkdir -p
CMD_MV          := mv -f
CMD_CAT         := cat
CMD_RM          := rm -f
CMD_RMDIR       := rm -rf

OPT_CC_INPUT    := $(empty)$(empty)
OPT_CC_OUTPUT   := -o
OPT_PREPRO_HD   := $(_CMD_PREPRO_HD_OPTS)

CMD_STRIP_INC   := $(SCRIPT_DIR)/strip_include.pl
CMD_STRIP_MK    := $(SCRIPT_DIR)/gen_strip_mk.pl
CMD_PREPRO_HD   := $(CMD_PREPRO) $(ALL_DEFINES) $(CXXFLAGS)   \
                       $(OPT_PREPRO_HD) -I$(HEADER_DIR)
CMD_PREPRO_MK   := $(SCRIPT_DIR)/gen_prepro_mk.pl
CMD_PARSE_HD    := $(CMD_PARSE)
CMD_PARSE_MK    := $(SCRIPT_DIR)/gen_parse_mk.pl
CMD_FORMAT_YML  := $(SCRIPT_DIR)/format_qtedi_production.pl
CMD_FORMAT_MK   := $(SCRIPT_DIR)/gen_format_mk.pl
CMD_GROUP_MK    := $(SCRIPT_DIR)/gen_group_mk.pl 
CMD_GROUP_YML   := $(SCRIPT_DIR)/group_by_namespace.pl
CMD_GROUP_CHECK := $(SCRIPT_DIR)/check_class_consistency.sh
CMD_GROUPLIST_MK:= $(SCRIPT_DIR)/gen_grouplist_mk.pl 
CMD_XSCODE_MK   := $(SCRIPT_DIR)/gen_xscode_mk.pl
CMD_CREAT_TP    := $(SCRIPT_DIR)/create_typemap.pl 
CMD_CREAT_XS    := $(SCRIPT_DIR)/create_xs_code.pl
CMD_CREAT_PM    := $(SCRIPT_DIR)/create_pm_code.pl

MODULE_DOT_CONF := $(MAKE_ROOT)/module.conf 
HEADER_DOT_MK   := $(MAKE_ROOT)/header.mk
STRIP_DOT_MK    := $(MAKE_ROOT)/strip.mk
PREPRO_DOT_MK   := $(MAKE_ROOT)/preprocess.mk
PARSE_DOT_MK    := $(MAKE_ROOT)/parse.mk
FORMAT_DOT_MK   := $(MAKE_ROOT)/format.mk
GROUP_DOT_MK    := $(MAKE_ROOT)/group.mk
GROUPLIST_DOT_MK:= $(MAKE_ROOT)/grouplist.mk
XSCODE_DOT_MK   := $(MAKE_ROOT)/xscode.mk

_R              := $(shell $(CMD_ECHO) "\n")

#################### TARGETS ###################################

HEADERS         := $(_HEADERS)
HEADERS_NO_ROOT := $(patsubst $(HEADER_DIR)/%,%,$(HEADERS))

STRIP_HEADERS   := $(addprefix $(OUT_STRIP_DIR)/,$(HEADERS_NO_ROOT))
PREPRO_HEADERS  := $(addprefix $(OUT_PREPRO_DIR)/,\
                       $(patsubst %.h,%.i,$(HEADERS_NO_ROOT)))
PARSE_HEADERS   := $(addprefix $(OUT_PARSE_DIR)/,\
                       $(patsubst %.h,%.yaml,$(HEADERS_NO_ROOT)))
FORMAT_YAMLS    := $(addprefix $(OUT_FORMAT_DIR)/,\
                       $(patsubst %.h,%.yaml,$(HEADERS_NO_ROOT)))
# initially empty, re-defined inside group_list.mk
GROUP_YAMLS     := $(empty)$(empty)

#################### SUBROUTINES ###############################

_remove_file = echo removing $1; \
               if [[ -f $1 ]] ; then $(CMD_RM) $1 ; fi
_remove_dir  = echo removing $1; \
               if [[ -d $1 ]] ; then $(CMD_RMDIR) $1 ; fi

#################### PHONY and FRIENDS #########################

# default goal
all: 
.PHONY: all

.SUFFIXES: .pre .h .i .meta .yaml

FORCE:

ifneq ($(MAKECMDGOALS),"clean")
-include $(HEADER_DOT_MK)
-include $(STRIP_DOT_MK)
-include $(PREPRO_DOT_MK)
-include $(PARSE_DOT_MK)
-include $(FORMAT_DOT_MK)
-include $(GROUP_DOT_MK)
endif

#################### META RULES and PATTERNS ###################

# ponny
# FIXME: great performance issue
$(HEADER_DOT_MK): $(HEADERS)
	$(shell echo > $@)
	$(foreach i,$(HEADERS),$(shell $(CMD_ECHO) "$i: \n" >> $@))

# strip include directives
# or preprocessor will croak
$(STRIP_DOT_MK): $(HEADER_DOT_MK)
	$(_Q)[[ -d $(OUT_STRIP_DIR) ]] || $(CMD_MKDIR) $(OUT_STRIP_DIR)
	$(_Q)$(CMD_STRIP_MK) $< $(IN_STRIP_DIR) $(OUT_STRIP_DIR) $@

# preprocess to omit macros
$(PREPRO_DOT_MK): $(HEADER_DOT_MK)
	$(_Q)[[ -d $(OUT_PREPRO_DIR) ]] || $(CMD_MKDIR) $(OUT_PREPRO_DIR)
	$(_Q)$(CMD_PREPRO_MK) $< $(IN_STRIP_DIR) $(IN_PREPRO_DIR) \
        $(OUT_PREPRO_DIR) $@

# parse preprocessed headers
# YAML output
$(PARSE_DOT_MK): $(HEADER_DOT_MK) 
	$(_Q)[[ -d $(OUT_PARSE_DIR) ]] || $(CMD_MKDIR) $(OUT_PARSE_DIR)
	$(_Q)$(CMD_PARSE_MK) $< $(IN_STRIP_DIR) $(IN_PARSE_DIR) \
        $(OUT_PARSE_DIR) $@

# strip && format parse productions
# YAML output
$(FORMAT_DOT_MK): $(HEADER_DOT_MK)
	$(_Q)[[ -d $(OUT_FORMAT_DIR) ]] || $(CMD_MKDIR) $(OUT_FORMAT_DIR)
	$(_Q)$(CMD_FORMAT_MK) $< $(IN_STRIP_DIR) $(IN_FORMAT_DIR) \
        $(OUT_FORMAT_DIR) $@

# group formatted yaml 
$(GROUP_DOT_MK): $(HEADER_DOT_MK) $(MODULE_DOT_CONF)
	$(_Q)$(CMD_GROUP_MK) $< $(IN_STRIP_DIR) $(IN_GROUP_DIR) \
        $(OUT_GROUP_DIR) $(MODULE_DOT_CONF) $@

# grouped file list produced by gen_group
$(GROUPLIST_DOT_MK): $(GROUP_DOT_MK) _GROUP_DOT_MK

# generate xs && pm code
$(XSCODE_DOT_MK): $(GROUPLIST_DOT_MK)                        \
                  $(eval $(shell cat $(GROUPLIST_DOT_MK)))   \
                  $(GROUP_YAMLS)
	$(_Q)$(CMD_XSCODE_MK) $(IN_XSCODE_DIR) $(OUT_XSCODE_DIR) \
        $(XSCODE_DOT_MK)

#################### GENERIC RULES #############################

clean_dot_mk:
	$(_Q)$(call _remove_file,$(HEADER_DOT_MK))
	$(_Q)$(call _remove_file,$(STRIP_DOT_MK))
	$(_Q)$(call _remove_file,$(PREPRO_DOT_MK))
	$(_Q)$(call _remove_file,$(PARSE_DOT_MK))
	$(_Q)$(call _remove_file,$(FORMAT_DOT_MK))
	$(_Q)$(call _remove_file,$(GROUP_DOT_MK))
	$(_Q)$(call _remove_file,$(XSCODE_DOT_MK))
.PHONY: clean_dot_mk

gen_strip  : $(STRIP_HEADERS)
clean_strip: 
	$(_Q)$(call _remove_dir,$(OUT_STRIP_DIR)) 
.PHONY: gen_strip clean_strip

gen_prepro  : $(PREPRO_HEADERS)
clean_prepro:
	$(_Q)$(call _remove_dir,$(OUT_PREPRO_DIR))
.PHONY: gen_prepro clean_prepro

gen_parse: $(PARSE_HEADERS)
.PHONY: gen_parse
clean_parse:
	$(_Q)$(call _remove_dir,$(OUT_PARSE_DIR))
.PHONY: clean_parse

gen_format  : $(FORMAT_YAMLS)
clean_format: 
	$(_Q)$(call _remove_dir,$(OUT_FORMAT_DIR))
.PHONY: gen_format clean_format

gen_group  : _GROUP_DOT_MK
clean_group:
	$(_Q)$(call _remove_dir,$(OUT_GROUP_DIR))
	$(_Q)$(call _remove_file,$(XSCODE_DOT_MK))
.PHONY: gen_group clean_group

class_sanity_check:
	$(_Q)$(CMD_GROUP_CHECK) $(OUT_GROUP_DIR)
.PHONY: class_sanity_check

gen_xscode : $(GROUPLIST_DOT_MK) $(XSCODE_DOT_MK)
.PHONY: gen_xscode

# final assignment
clean: clean_dot_mk clean_strip clean_prepro clean_parse     \
       clean_format clean_group
.PHONY: clean

all: gen_group

