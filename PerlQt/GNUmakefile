################################################################
####
#### Author: Dongxu Ma <dongxu.ma@gmail.com>
#### License: Artistic 
####
################################################################

#################### META CONFIG ###############################
include config.mk

#################### SHELL    ##################################
SHELL=/bin/bash

#################### DIRECTORY STRUCTURES ######################

# FIXME: oops on MSWin32, unknown on Darwin
# always try to be absolute

MAKE_ROOT       := $(shell pwd)
HEADER_DIR      := $(_HEADER_DIR)
# NOTE: ugly hack to permit custom PERL5LIB
SCRIPT_DIR      := $(_PERL5) $(MAKE_ROOT)/script
TEMPLATE_DIR    := $(MAKE_ROOT)/template

IN_STRIP_DIR    := $(HEADER_DIR)
OUT_STRIP_DIR   := $(MAKE_ROOT)/00strip

IN_PREPRO_DIR   := $(OUT_STRIP_DIR)
OUT_PREPRO_DIR  := $(MAKE_ROOT)/01prepro

IN_PARSE_DIR    := $(OUT_PREPRO_DIR)
OUT_PARSE_DIR   := $(MAKE_ROOT)/02parse

IN_FORMAT_DIR   := $(OUT_PARSE_DIR)
OUT_FORMAT_DIR  := $(MAKE_ROOT)/03format

IN_GROUP_DIR    := $(OUT_FORMAT_DIR)
OUT_GROUP_DIR   := $(MAKE_ROOT)/04group

IN_TYPEMAP_DIR  := $(OUT_GROUP_DIR)
OUT_TYPEMAP_DIR := $(MAKE_ROOT)/05typemap

IN_XSCODE_DIR   := $(OUT_GROUP_DIR)
OUT_XSCODE_DIR  := $(MAKE_ROOT)/99xscode

#################### MAKE TOOLS ################################

# DEBUG echos all shell commands
ifndef DEBUG
_Q := @
else
_Q := $(empty)$(empty)
endif

# FIXME: check available options for all involved commands
CMD_CC             := $(_CMD_CC)
CMD_CC             ?= g++
# intepretable echo
CMD_ECHO           := echo -e
CMD_PREPRO         := $(CMD_CC) -E
CMD_PARSE          := $(SCRIPT_DIR)/parse_header.pl
CMD_MKDIR          := mkdir -p
CMD_MV             := mv -f
CMD_CAT            := cat
CMD_RM             := rm -f
CMD_RMDIR          := rm -rf

OPT_CC_INPUT       := $(empty)$(empty)
OPT_CC_OUTPUT      := -o
IMACROS            := $(_IMACROS)

CMD_STRIP_INC      := $(SCRIPT_DIR)/strip_include.pl
CMD_STRIP_MK       := $(SCRIPT_DIR)/gen_strip_mk.pl
CMD_PREPRO_HD      := $(CMD_PREPRO) $(ALL_DEFINES) $(CXXFLAGS)\
                          -I$(HEADER_DIR)
CMD_PREPRO_MK      := $(SCRIPT_DIR)/gen_prepro_mk.pl
CMD_PARSE_HD       := $(CMD_PARSE)
CMD_PARSE_MK       := $(SCRIPT_DIR)/gen_parse_mk.pl
CMD_FORMAT_YML     := $(SCRIPT_DIR)/format_qtedi_production.pl
CMD_FORMAT_MK      := $(SCRIPT_DIR)/gen_format_mk.pl
CMD_GROUP_MK       := $(SCRIPT_DIR)/gen_group_mk.pl 
CMD_GROUP_YML      := $(SCRIPT_DIR)/group_by_namespace.pl
CMD_GROUP_CHECK    := $(SCRIPT_DIR)/check_class_consistency.sh
CMD_GROUPLIST_MK   := $(SCRIPT_DIR)/gen_grouplist_mk.pl 
CMD_XSCODE_MK      := $(SCRIPT_DIR)/gen_xscode_mk.pl
CMD_CREAT_TP       := $(SCRIPT_DIR)/create_typemap.pl
CMD_TYPEMAPLIST_MK := $(SCRIPT_DIR)/gen_typemaplist_mk.pl 
CMD_TYPEMAP        := $(SCRIPT_DIR)/finalize_typemap.pl 
CMD_PKGMAP         := $(SCRIPT_DIR)/create_packagemap.pl
CMD_CREAT_XS       := $(SCRIPT_DIR)/create_xs_code.pl
CMD_CREAT_PM       := $(SCRIPT_DIR)/create_pm_code.pl
CMD_YGREP          := $(SCRIPT_DIR)/ygrep.pl 

MODULE_DOT_CONF    := $(MAKE_ROOT)/module.conf 
HEADER_DOT_MK      := $(MAKE_ROOT)/header.mk
STRIP_DOT_MK       := $(MAKE_ROOT)/strip.mk
PREPRO_DOT_MK      := $(MAKE_ROOT)/preprocess.mk
PARSE_DOT_MK       := $(MAKE_ROOT)/parse.mk
FORMAT_DOT_MK      := $(MAKE_ROOT)/format.mk
GROUP_DOT_MK       := $(MAKE_ROOT)/group.mk
GROUPLIST_DOT_MK   := $(MAKE_ROOT)/grouplist.mk
TYPEMAPLIST_DOT_MK := $(MAKE_ROOT)/typemaplist.mk
XSCODE_DOT_MK      := $(MAKE_ROOT)/xscode.mk

# temple use
TYPEMAP_DOT_DEP    := $(MAKE_ROOT)/.typemap.dep
# used by script/create_typemap.pl
TYPEMAP_DOT_IGNORE := $(MAKE_ROOT)/typemap.ignore
TYPEMAP_DOT_SIMPLE := $(MAKE_ROOT)/typemap.simple
TYPEMAP_DOT_MANUAL := $(MAKE_ROOT)/typemap.manual
TYPEMAP_DOT_TT2    := $(TEMPLATE_DIR)/typemap.tt2

#################### TARGETS ###################################

HEADERS         := $(_HEADERS)
HEADERS_NO_ROOT := $(patsubst $(HEADER_DIR)/%,%,$(HEADERS))

STRIP_HEADERS   := $(addprefix $(OUT_STRIP_DIR)/,$(HEADERS_NO_ROOT))
PREPRO_HEADERS  := $(addprefix $(OUT_PREPRO_DIR)/,\
                       $(patsubst %.$(HEADER_PREFIX),%.i,$(HEADERS_NO_ROOT)))
PARSE_HEADERS   := $(addprefix $(OUT_PARSE_DIR)/,\
                       $(patsubst %.$(HEADER_PREFIX),%.yml,$(HEADERS_NO_ROOT)))
FORMAT_YAMLS    := $(addprefix $(OUT_FORMAT_DIR)/,\
                       $(patsubst %.$(HEADER_PREFIX),%.yml,$(HEADERS_NO_ROOT)))
# initially empty, overriden inside grouplist.mk
GROUP_YAMLS     := $(empty)$(empty)
# initially empty, overriden inside xscode.mk
TYPEMAP_YAMLS   := $(empty)$(empty)
TYPEMAP_LIST    := $(OUT_TYPEMAP_DIR)/typemap_list
TYPEMAP_TEMPLATE:= $(OUT_TYPEMAP_DIR)/typemap_template
TYPEMAP         := $(OUT_TYPEMAP_DIR)/typemap
PACKAGEMAP      := $(OUT_TYPEMAP_DIR)/packagemap

#################### SUBROUTINES ###############################

_remove_file = echo removing $1; \
               if [[ -f $1 ]] ; then $(CMD_RM) $1 ; fi
_remove_dir  = echo removing $1; \
               if [[ -d $1 ]] ; then $(CMD_RMDIR) $1 ; fi
# generate imacros options for g++ preprocessor
# exclude process target file from imacros files
# this mainly works for QtCore/qglobal.h in QT
_generate_imacros = $(addprefix -imacros ,$(addprefix             \
                        $(HEADER_DIR)/,$(filter-out               \
                            %/$(notdir $1),$(IMACROS))))

#################### PHONY and FRIENDS #########################

# default goal
all: 
.PHONY: all

.SUFFIXES: .$(HEADER_PREFIX) .i .yml .meta                        \
           .function .public .protected .signal .typedef .enum

FORCE: ;

ifneq ($(MAKECMDGOALS),)
_GOALS := $(MAKECMDGOALS)
else
_GOALS := all
endif

#################### META RULES and PATTERNS ###################

# FIXME: great performance issue
$(HEADER_DOT_MK): $(HEADERS)
	$(_Q)echo generating $@
	$(shell echo > $@)
	$(foreach i,$(HEADERS),$(shell $(CMD_ECHO) "$i: \n" >> $@))

# strip include directives
# or preprocessor will croak
$(STRIP_DOT_MK): $(HEADER_DOT_MK)
	$(_Q)echo generating $@
	$(_Q)[[ -d $(OUT_STRIP_DIR) ]] || $(CMD_MKDIR) $(OUT_STRIP_DIR)
	$(_Q)$(CMD_STRIP_MK) $< $(IN_STRIP_DIR) $(OUT_STRIP_DIR) $@

# preprocess to omit macros
$(PREPRO_DOT_MK): $(HEADER_DOT_MK)
	$(_Q)echo generating $@
	$(_Q)[[ -d $(OUT_PREPRO_DIR) ]] || $(CMD_MKDIR) $(OUT_PREPRO_DIR)
	$(_Q)$(CMD_PREPRO_MK) $< $(IN_STRIP_DIR) $(IN_PREPRO_DIR) \
        $(OUT_PREPRO_DIR) $@

# parse preprocessed headers
# YAML output
$(PARSE_DOT_MK): $(HEADER_DOT_MK) 
	$(_Q)echo generating $@
	$(_Q)[[ -d $(OUT_PARSE_DIR) ]] || $(CMD_MKDIR) $(OUT_PARSE_DIR)
	$(_Q)$(CMD_PARSE_MK) $< $(IN_STRIP_DIR) $(IN_PARSE_DIR) \
        $(OUT_PARSE_DIR) $@

# strip && format parse productions
# YAML output
$(FORMAT_DOT_MK): $(HEADER_DOT_MK)
	$(_Q)echo generating $@
	$(_Q)[[ -d $(OUT_FORMAT_DIR) ]] || $(CMD_MKDIR) $(OUT_FORMAT_DIR)
	$(_Q)$(CMD_FORMAT_MK) $< $(IN_STRIP_DIR) $(IN_FORMAT_DIR) \
        $(OUT_FORMAT_DIR) $@

# group formatted yaml 
$(GROUP_DOT_MK): $(HEADER_DOT_MK) $(MODULE_DOT_CONF)
	$(_Q)echo generating $@
	$(_Q)$(CMD_GROUP_MK) $< $(IN_STRIP_DIR) $(IN_GROUP_DIR) \
        $(OUT_GROUP_DIR) $(MODULE_DOT_CONF) $@

$(GROUPLIST_DOT_MK): $(GROUP_DOT_MK) 

$(XSCODE_DOT_MK)   : $(GROUP_DOT_MK) $(GROUPLIST_DOT_MK)     \
                     $(TYPEMAPLIST_DOT_MK) $(GROUP_YAMLS)
	$(_Q)echo generating $@
	$(_Q)$(CMD_XSCODE_MK) $(IN_XSCODE_DIR) $(OUT_XSCODE_DIR) \
        $(OUT_TYPEMAP_DIR) $@

# generate xs && pm code
# GROUP_YAMLS from grouplist.mk
# in case grouplist.mk doesn't exist
# shell will complain, eval will have nothing to bless
# grouplist.mk be rebuilt finally
# priority:
# group.mk > grouplist.mk > files under OUT_GROUP_DIR
# on the other hand, grouplist.mk behaves like a 
# checksum of staff under OUT_GROUP_DIR
# removal of any file which was produced by latest 
# gen_group triggers rebuild of all so-called 
# 'standard' files
# $(GROUPLIST_DOT_MK) defined in $(GROUP_DOT_MK)
ifeq ($(filter clean%,$(_GOALS)),)
$(info including $(HEADER_DOT_MK))
include $(HEADER_DOT_MK)
$(info including $(STRIP_DOT_MK))
include $(STRIP_DOT_MK)
$(info including $(PREPRO_DOT_MK))
include $(PREPRO_DOT_MK)
$(info including $(PARSE_DOT_MK))
include $(PARSE_DOT_MK)
$(info including $(FORMAT_DOT_MK))
include $(FORMAT_DOT_MK)
$(info including $(GROUP_DOT_MK))
include $(GROUP_DOT_MK)
endif

$(TYPEMAPLIST_DOT_MK): $(GROUPLIST_DOT_MK) $(MODULE_DOT_CONF)     \
                       $(TYPEMAP_DOT_IGNORE) $(TYPEMAP_DOT_SIMPLE)\
                       $(TYPEMAP_DOT_MANUAL)                      \
                       $(filter-out %.friend %.function,$(GROUP_YAMLS))
	$(shell $(CMD_RM) $(TYPEMAP_DOT_DEP))
	$(foreach i,$^,$(shell $(CMD_ECHO) $(i) >> $(TYPEMAP_DOT_DEP)))
	$(_Q)$(CMD_RMDIR) $(OUT_TYPEMAP_DIR)
	$(_Q)[[ -d $(OUT_TYPEMAP_DIR) ]] || $(CMD_MKDIR)         \
        $(OUT_TYPEMAP_DIR)
	$(_Q)echo generating $(TYPEMAP_LIST)
	$(_Q)[[ -d $(dir $@) ]] || $(CMD_MKDIR) $(dir $@)
	$(_Q)$(CMD_CREAT_TP) $(MODULE_DOT_CONF)                  \
        $(TYPEMAP_DOT_IGNORE) $(TYPEMAP_DOT_SIMPLE)          \
        $(TYPEMAP_DOT_MANUAL) $(TYPEMAP_DOT_DEP)             \
        $(OUT_TYPEMAP_DIR) $(TYPEMAP_TEMPLATE) $(TYPEMAP_LIST)
	$(_Q)echo generating $(TYPEMAP)
	$(_Q)$(CMD_TYPEMAP) -t $(TYPEMAP_DOT_TT2) -o $(TYPEMAP)  \
        $(TYPEMAP_LIST) $(TYPEMAP_TEMPLATE)
	$(_Q)echo generating $@
	$(_Q)$(CMD_TYPEMAPLIST_MK) $(OUT_TYPEMAP_DIR) $@

$(PACKAGEMAP): $(GROUP_DOT_MK) $(GROUPLIST_DOT_MK) $(GROUP_YAMLS)
	$(_Q)echo generating $@
	$(_Q)[[ -d $(dir $@) ]] || $(CMD_MKDIR) $(dir $@)
	$(_Q)$(CMD_PKGMAP) $(OUT_GROUP_DIR) $@

#################### GENERIC RULES #############################

clean_dot_mk :
	$(_Q)$(call _remove_file,$(HEADER_DOT_MK))
	$(_Q)$(call _remove_file,$(STRIP_DOT_MK))
	$(_Q)$(call _remove_file,$(PREPRO_DOT_MK))
	$(_Q)$(call _remove_file,$(PARSE_DOT_MK))
	$(_Q)$(call _remove_file,$(FORMAT_DOT_MK))
	$(_Q)$(call _remove_file,$(GROUP_DOT_MK))
	$(_Q)$(call _remove_file,$(GROUPLIST_DOT_MK))
	$(_Q)$(call _remove_file,$(XSCODE_DOT_MK))
	$(_Q)$(call _remove_file,$(TYPEMAPLIST_DOT_MK))
.PHONY: clean_dot_mk

gen_strip    : $(STRIP_HEADERS)
clean_strip  : 
	$(_Q)$(call _remove_file,$(STRIP_DOT_MK))
	$(_Q)$(call _remove_dir,$(OUT_STRIP_DIR)) 
.PHONY: gen_strip clean_strip

gen_prepro   : gen_strip $(PREPRO_HEADERS)
clean_prepro :
	$(_Q)$(call _remove_file,$(PREPRO_DOT_MK))
	$(_Q)$(call _remove_dir,$(OUT_PREPRO_DIR))
.PHONY: gen_prepro clean_prepro

gen_parse    : gen_prepro $(PARSE_HEADERS)
clean_parse  :
	$(_Q)$(call _remove_file,$(PARSE_DOT_MK))
	$(_Q)$(call _remove_dir,$(OUT_PARSE_DIR))
.PHONY: gen_parse clean_parse

gen_format   : gen_parse $(FORMAT_YAMLS)
clean_format : 
	$(_Q)$(call _remove_file,$(FORMAT_DOT_MK))
	$(_Q)$(call _remove_dir,$(OUT_FORMAT_DIR))
.PHONY: gen_format clean_format

gen_group    : gen_format $(GROUP_DOT_MK) $(GROUPLIST_DOT_MK)
clean_group  :
	$(_Q)$(call _remove_dir,$(OUT_GROUP_DIR))
	$(_Q)$(call _remove_file,$(GROUP_DOT_MK))
	$(_Q)$(call _remove_file,$(GROUPLIST_DOT_MK))
.PHONY: gen_group clean_group

class_sanity_check:
	$(_Q)$(CMD_GROUP_CHECK) $(OUT_GROUP_DIR)
.PHONY: class_sanity_check

gen_typemap     : gen_group $(GROUPLIST_DOT_MK) $(GROUP_YAMLS)
clean_typemap   : 
	$(_Q)$(call _remove_dir,$(OUT_TYPEMAP_DIR))
	$(_Q)$(call _remove_file,$(TYPEMAPLIST_DOT_MK))
.PHONY: gen_typemap clean_typemap

gen_packagemap  : gen_group $(GROUPLIST_DOT_MK) $(GROUP_YAMLS) \
                  $(PACKAGEMAP)
clean_packagemap: 
	$(_Q)$(call _remove_file,$(PACKAGEMAP))
.PHONY: gen_packagemap clean_packagemap

# TODO: support of custom-inserted class meta files detection
#       keep a custom list in seperate file
gen_xscode_dot_mk   : gen_typemap gen_packagemap $(XSCODE_DOT_MK)
clean_xscode_dot_mk : 
	$(_Q)$(call _remove_file,$(XSCODE_DOT_MK))
.PHONY: gen_xscode_dot_mk clean_xscode_dot_mk

gen_xscode   : gen_xscode_dot_mk $(XS_FILES)
clean_xscode : clean_xscode_dot_mk
	$(_Q)$(call _remove_dir,$(OUT_XSCODE_DIR))
.PHONY: gen_xscode clean_xscode

# internal use
list_group_yamls : 
	# $(_GOALS)
	# $(GROUP_YAMLS)

list_typemap_yamls : 
	# $(TYPEMAP_YAMLS)

list_template_types: $(TYPEMAP_TEMPLATE)
	$(_Q)$(CMD_YGREP) -f name $< | sort | uniq | cut -d':' -f2

list_template_def  : $(TYPEMAP_TEMPLATE)
	$(_Q)$(CMD_YGREP) -c name=$(TEMPLATE_NAME) $<

list_typemap_types :
	$(_Q)cut -d':' -f2 $(TYPEMAP_LIST) | sort | uniq
.PHONY: list_group_yamls list_typemap_yamls list_template_types \
        list_template_def list_typemap_types

# final assignment
clean: clean_dot_mk clean_strip clean_prepro clean_parse \
       clean_format clean_group clean_typemap            \
       clean_xscode_dot_mk clean_xscode
.PHONY: clean

all: gen_xscode_dot_mk