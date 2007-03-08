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

EXTRA_DEFINES   := -DQT_SHARED -DQT_NO_DEBUG -DQT_NO_KEYWORDS

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

CMD_STRIP_INC   := $(SCRIPT_DIR)/strip_include.pl
CMD_STRIP_MK    := $(SCRIPT_DIR)/gen_strip_mk.pl
CMD_PREPRO_HD_OPTS := $(_CMD_PREPRO_HD_OPTS)
CMD_PREPRO_HD   := $(CMD_PREPRO) $(ALL_DEFINES) \
                       $(CMD_PREPRO_HD_OPTS) -I$(HEADER_DIR)
CMD_PREPRO_MK   := $(SCRIPT_DIR)/gen_prepro_mk.pl
CMD_PARSE_HD    := $(CMD_PARSE)
CMD_PARSE_MK    := $(SCRIPT_DIR)/gen_parse_mk.pl
CMD_FORMAT_YML  := $(SCRIPT_DIR)/format_yaml.pl
CMD_FORMAT_MK   := $(SCRIPT_DIR)/gen_format_mk.pl

HEADER_DOT_MK   := $(MAKE_ROOT)/header.mk
STRIP_DOT_MK    := $(MAKE_ROOT)/strip.mk
PREPRO_DOT_MK   := $(MAKE_ROOT)/preprocess.mk
PARSE_DOT_MK    := $(MAKE_ROOT)/parse.mk
FORMAT_DOT_MK   := $(MAKE_ROOT)/format.mk

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

#################### SUBROUTINES ###############################


#################### PONNY and FRIENDS #########################

# default goal
all: 
.PONNY: all

.SUFFIXES: .pre .h .cpp

FORCE:

ifneq ($(MAKECMDGOALS),"clean")
-include $(HEADER_DOT_MK)
-include $(STRIP_DOT_MK)
-include $(PREPRO_DOT_MK)
-include $(PARSE_DOT_MK)
-include $(FORMAT_DOT_MK)
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

#################### GENERIC RULES #############################

clean_dot_mk:
	$(_Q)echo removing $(HEADER_DOT_MK)
	$(_Q)[[ -f $(HEADER_DOT_MK) ]] && $(CMD_RM) $(HEADER_DOT_MK)
	$(_Q)echo removing $(STRIP_DOT_MK)
	$(_Q)[[ -f $(STRIP_DOT_MK) ]] && $(CMD_RM) $(STRIP_DOT_MK)
	$(_Q)echo removing $(PREPRO_DOT_MK)
	$(_Q)[[ -f $(PREPRO_DOT_MK) ]] && $(CMD_RM) $(PREPRO_DOT_MK)
	$(_Q)echo removing $(PARSE_DOT_MK)
	$(_Q)[[ -f $(PARSE_DOT_MK) ]] && $(CMD_RM) $(PARSE_DOT_MK)
	$(_Q)echo removing $(FORMAT_DOT_MK)
	$(_Q)[[ -f $(FORMAT_DOT_MK) ]] && $(CMD_RM) $(FORMAT_DOT_MK)
.PONNY: clean_dot_mk

gen_strip: $(STRIP_HEADERS)
.PONNY: gen_strip
clean_strip: 
	$(_Q)echo removing $(OUT_STRIP_DIR) 
	$(_Q)[[ -d $(OUT_STRIP_DIR) ]] && $(CMD_RMDIR) $(OUT_STRIP_DIR)
.PONNY: clean_strip

gen_prepro: $(PREPRO_HEADERS)
.PONNY: gen_prepro
clean_prepro:
	$(_Q)echo removing $(OUT_PREPRO_DIR)
	$(_Q)[[ -d $(OUT_PREPRO_DIR) ]] && $(CMD_RMDIR) $(OUT_PREPRO_DIR)
.PONNY: clean_prepro

gen_parse: $(PARSE_HEADERS)
.PONNY: gen_parse
clean_parse:
	$(_Q)echo removing $(OUT_PARSE_DIR)
	$(_Q)[[ -d $(OUT_PARSE_DIR) ]] && $(CMD_RMDIR) $(OUT_PARSE_DIR)
.PONNY: clean_parse

gen_format: $(FORMAT_YAMLS)
.PONNY: gen_format
clean_format: 
	$(_Q)echo removing $(OUT_FORMAT_DIR)
	$(_Q)[[ -d $(OUT_FORMAT_DIR) ]] && $(CMD_RMDIR) $(OUT_FORMAT_DIR)
.PONNY: clean_format

# final assignment
clean: clean_dot_mk clean_strip clean_prepro clean_parse clean_format
.PONNY: clean

all: gen_format
