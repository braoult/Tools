# brlib Makefile - GNU make only
#
# Copyright (C) 2021-2023 Bruno Raoult ("br")
# Licensed under the GNU General Public License v3.0 or later.
# Some rights reserved. See COPYING.
#
# You should have received a copy of the GNU General Public License along with this
# program. If not, see <https://www.gnu.org/licenses/gpl-3.0-standalone.html>.
#
# SPDX-License-Identifier: GPL-3.0-or-later <https://spdx.org/licenses/GPL-3.0-or-later.html>
#

# important to know where exactly is project root dir
ROOTDIR   := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

SHELL     := /bin/bash
CC        := gcc
LD        := ld
BEAR      := bear
TOUCH     := touch
RM        := rm
RMDIR     := rmdir

SRCDIR    := ./src
INCDIR    := ./include
OBJDIR    := ./obj
LIBDIR    := ./lib
BINDIR    := ./bin
DEPDIR    := ./dep

SRC       := $(wildcard $(SRCDIR)/*.c)                      # brlib sources
SRC_FN    := $(notdir $(SRC))                               # source basename
OBJ       := $(addprefix $(OBJDIR)/,$(SRC_FN:.c=.o))

LIB       := br_$(shell uname -m)                           # library name
SLIB      := $(addsuffix .a, $(LIBDIR)/lib$(LIB))           # static lib
DLIB      := $(addsuffix .so, $(LIBDIR)/lib$(LIB))          # dynamic lib

DEP_FN    := $(SRC_FN) $(LIBSRC_FN)
DEP       := $(addprefix $(DEPDIR)/,$(DEP_FN:.c=.d))

##################################### emacs projectile/ccls
PRJROOT   := .projectile
CCLSROOT  := .ccls-root
CCLSCMDS  := compile_commands.json

##################################### pre-processor flags
CPPFLAGS  := -I$(INCDIR)
#CPPFLAGS  += -DDEBUG                                       # global
CPPFLAGS  += -DDEBUG_DEBUG                                  # enable log() functions
#CPPFLAGS  += -DDEBUG_DEBUG_C                               # log() funcs debug
PPFLAGS   += -DDEBUG_DEBUG                                  # activate logs funcs
CPPFLAGS  += -DDEBUG_POOL                                   # mem pools

# remove extraneous spaces (due to spaces before comments)
CPPFLAGS  := $(strip $(CPPFLAGS))

##################################### compiler flags
CFLAGS    := -std=gnu11
CFLAGS    += -O2
CFLAGS    += -g
CFLAGS    += -Wall
CFLAGS    += -Wextra
CFLAGS    += -march=native
CFLAGS    += -Wmissing-declarations
CFLAGS    += -Wno-unused-result
CFLAGS    += -fPIC
# for gprof
#CFLAGS    += -pg
# Next one may be useful for valgrind (some invalid instructions)
# CFLAGS   += -mno-tbm

CFLAGS    := $(strip $(CFLAGS))

##################################### archiver/linker/dependency flags
ARFLAGS   := rcs
LDFLAGS   := -L$(LIBDIR)
DEPFLAGS   = -MMD -MP -MF $(DEPDIR)/$*.d

##################################### General targets
.PHONY: all compile clean cleanall

all: libs

compile: objs

clean: cleandep cleanobj cleanlib cleanbin

cleanall: clean cleandepdir cleanobjdir cleanlibdir cleanbindir

# setup emacs projectile/ccls
emacs: emacs-setup
# update compile-commands.json
ccls: $(CCLSCMDS)

##################################### cleaning functions
# rmfiles - deletes a list of files in a directory if they exist.
# $(1): the directory
# $(2): the list of files to delete
# $(3): The string to include in action output - "cleaning X files."
# see: https://stackoverflow.com/questions/6783243/functions-in-makefiles
#
# Don't use wildcard like "$(DIR)/*.o", so we can control mismatches between
# list and actual files in directory.
# See rmdir below.
define rmfiles
	@#echo "rmfiles=+$(1)+"
	$(eval $@_EXIST = $(wildcard $(1)))
	@#echo "existfile=+${$@_EXIST}+"
	@if [[ -n "${$@_EXIST}" ]]; then         \
		echo "cleaning $(2) files." ;    \
		$(RM) ${$@_EXIST} ;              \
	fi
endef

# rmdir - deletes a directory if it exists.
# $(1): the directory
# $(2): The string to include in action output - "removing X dir."
#
# Don't use $(RM) -rf, to control unexpected dep files.
# See rmfile above.
define rmdir
	@#echo "rmdir +$(1)+"
	$(eval $@_EXIST = $(wildcard $(1)))
	@#echo "existdir=+${$@_EXIST}+"
	@if [[ -n "${$@_EXIST}" ]]; then         \
		echo "removing $(2) dir." ;      \
		$(RMDIR) ${$@_EXIST} ;           \
	fi
endef

##################################### dirs creation
.PHONY: alldirs

ALLDIRS   := $(DEPDIR) $(OBJDIR) $(LIBDIR) $(BINDIR)

alldirs: $(ALLDIRS)

# Here, we have something like:
# a: a
# a will be built if (1) older than a, or (2) does not exist. Here only (2).
$(ALLDIRS): $@
	@echo creating $@ directory.
	@mkdir -p $@

##################################### Dependencies files
.PHONY: cleandep cleandepdir

-include $(wildcard $(DEP))

# Don't use $(DEPDIR)/*.d, to control mismatches between dep and src files.
# See second rule below.
cleandep:
	$(call rmfiles,$(DEP),depend)
	@#echo cleaning dependency files.
	@#$(RM) -f $(DEP)

cleandepdir:
	$(call rmdir,$(DEPDIR),depend)
	@#[ -d $(DEPDIR) ] && echo cleaning depend files && $(RM) -f $(DEP) || true

##################################### objects
.PHONY: objs cleanobj cleanobjdir

objs: $(OBJ)

cleanobj:
	$(call rmfiles,$(OBJ),brlib object)

cleanobjdir:
	$(call rmdir,$(OBJDIR),brlib objects)

$(OBJDIR)/%.o: $(SRCDIR)/%.c | $(OBJDIR) $(DEPDIR)
	@echo compiling $< "->" $@.
	$(CC) -c $(DEPFLAGS) $(CPPFLAGS) $(CFLAGS) $< -o $@

##################################### brlib libraries
.PHONY: libs cleanlib cleanlibdir

libs: $(DLIB) $(SLIB)

cleanlib:
	$(call rmfiles,$(DLIB) $(SLIB),library)

cleanlibdir:
	$(call rmdir,$(LIBDIR),libraries)

#$(DLIB): CFLAGS += -fPIC
$(DLIB): LDFLAGS += -shared
$(DLIB): $(OBJ) | $(LIBDIR)
	@echo "building $@ shared library ($?)."
	$(CC) $(CFLAGS) $(LDFLAGS) $? -o $@

$(SLIB): $(OBJ) | $(LIBDIR)
	@echo "building $@ static library ($?)."
	$(AR) $(ARFLAGS) $@ $? > /dev/null

##################################### brchess binaries
.PHONY: targets cleanbin cleanbindir

targets: $(TARGET)

cleanbin:
	$(call rmfiles,$(TARGET),binary)

cleanbindir:
	$(call rmdir,$(BINDIR),binaries)

##################################### pre-processed (.i) and assembler (.s) output
%.i: %.c
	@echo generating $@
	@$(CC) -E $(CPPFLAGS) $(CFLAGS) $< -o $@

%.s: %.c
	@echo generating $@
	@$(CC) -S -fverbose-asm $(CPPFLAGS) $(CFLAGS) $< -o $@

##################################### LSP (ccls)
.PHONY: emacs-setup

PRJROOT   := .projectile
CCLSROOT  := .ccls-root
CCLSFILE  := .ccls
CCLSCMDS  := compile_commands.json

emacs-setup: $(PRJROOT) $(CCLSROOT) $(CCLSCMDS)

#$(CCLSFILE):
#	@echo "creating CCLS's $@ project root file."
#	echo '%compile_commands.json' > $@

$(CCLSROOT) $(PRJROOT):
	@if [[ $(@) = $(PRJROOT) ]] ;                           \
	then                                                    \
		echo "creating Emacs's projectile root file." ; \
	else                                                    \
		echo "creating Emacs's ccls root file." ;       \
	fi
	@$(TOUCH) $@

# generate compile_commands.json.
# TODO: add includes and Makefile dependencies.
# also, if cclsfile is newer than sources, no need to clean objects file
# (and to run bear).
# maybe run cleanobj cleanlibobj in commands ?
$(CCLSCMDS): cleanobj $(SRC) | $(CCLSROOT)
	@echo "Generating ccls compile commands file ($@)."
	@$(BEAR) -- make compile

#.PHONY: bear
#bear: cleanobj cleanlibobj Makefile | $(CCLSROOT)
#    @$(BEAR) -- make compile

##################################### valgrind (mem check)
.PHONY: memcheck

VALGRIND      := valgrind
VALGRINDFLAGS := --leak-check=full --show-leak-kinds=all
VALGRINDFLAGS += --track-origins=yes --sigill-diagnostics=yes
VALGRINDFLAGS += --quiet --show-error-list=yes
VALGRINDFLAGS += --log-file=valgrind.out
# We need to suppress libreadline leaks here. See :
# https://stackoverflow.com/questions/72840015
VALGRINDFLAGS += --suppressions=etc/libreadline.supp

memcheck: targets
	@$(VALGRIND) $(VALGRINDFLAGS) $(BINDIR)/brchess

##################################### Makefile debug
.PHONY: showflags wft

showflags:
	@echo CFLAGS: "$(CFLAGS)"
	@echo CPPFLAGS: $(CPPFLAGS)
	@echo DEPFLAGS: $(DEPFLAGS)
	@echo LDFLAGS: $(LDFLAGS)

wtf:
	@printf "ROOTDIR=+%s+\n\n" "$(ROOTDIR)"
	@printf "OBJDIR=%s\n\n" "$(OBJDIR)"
	@printf "OBJ=%s\n\n" "$(OBJ)"
