# c++ related goals

build        : gen_pmcode $(MAKEFILE_PERL) $(MANIFEST)
	$(_Q)$(MAKE) -f Makefile
clean_build  : 
	$(_Q)$(call _remove_file,$(MAKEFILE_PL))
	$(_Q)$(call _remove_file,$(MAKEFILE_PERL))
	$(_Q)$(call _remove_file,$(MANIFEST))
	$(_Q)$(call _remove_file,$(ROOT_XS))
	$(_Q)$(call _remove_file,$(ROOT_C))
	$(_Q)$(call _remove_file,$(patsubst %.c,%.o,$(ROOT_C)))
	$(_Q)$(call _remove_file,$(patsubst %.c,%.bs,$(ROOT_C)))
.PHONY: build clean_build
