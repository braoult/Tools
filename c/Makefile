# Tools Makefile
#
# Copyright (C) 2022 Bruno Raoult ("br")
# Licensed under the GNU General Public License v3.0 or later.
# Some rights reserved. See COPYING.
#
# You should have received a copy of the GNU General Public License along with this
# program. If not, see <https://www.gnu.org/licenses/gpl-3.0-standalone.html>.
#
# SPDX-License-Identifier: GPL-3.0-or-later <https://spdx.org/licenses/GPL-3.0-or-later.html>
#

SHELL  := /bin/bash
CC     := gcc

CFLAGS += -std=gnu99
CFLAGS += -O2
CFLAGS += -g
CFLAGS += -Wall
CFLAGS += -Wextra
CFLAGS += -march=native
CFLAGS += -Wmissing-declarations
CFLAGS += -Wno-unused-result

# for gprof
#CFLAGS += -pg

# Next one may be useful for valgrind (some invalid instructions)
# CFLAGS += -mno-tbm

CFLAGS += -DDEBUG_DEBUG		# activate general debug (debug.c)
CFLAGS += -DDEBUG_POOL		# memory pools management

INCDIR    := ./include
LIBDIR    := ./lib
OBJDIR    := ./obj

LIBNAME   := br_$(shell uname -m)
LIB       := lib$(LIBNAME)
SLIB      := $(LIBDIR)/$(LIB).a
DLIB      := $(LIBDIR)/$(LIB).so
LIBSRC    := $(wildcard *.c)
LIBOBJ    := $(addprefix $(OBJDIR)/,$(patsubst %.c,%.o,$(LIBSRC)))
LDFLAGS   := -L$(LIBDIR)
LDLIB     := -l$(LIB)

export LD_LIBRARY_PATH = $(LIBDIR)
#export PATH := .:$(PATH)

.PHONY: all libs clean dirs

all: libs

libs: dirs $(DLIB) $(SLIB)

dirs: $(LIBDIR) $(OBJDIR)

$(LIBDIR) $(OBJDIR):
	@echo creating $@ directory.
	@mkdir $@

clean:
	@echo deleting $(OBJDIR) and $(LIBDIR) directories.
	@$(RM) -rf $(LIBDIR) $(OBJDIR)

$(SLIB): $(LIBOBJ)
	@echo building $@ static library.
	@$(AR) $(ARFLAGS) -o $@ $^

$(DLIB): CFLAGS += -fPIC
$(DLIB): LDFLAGS += -shared
$(DLIB): $(LIBOBJ)
	@echo building $@ shared library.
	@$(CC) $(LDFLAGS) $^ -o $@

.c:
	@echo compiling $<
	@$(CC) $(CFLAGS) $(LDFLAGS) -I $(INCDIR) $< $(LDLIB) -o $@

#.c.o:
$(OBJDIR)/%.o: %.c
	@echo compiling $<.
	@$(CC) -c $(CFLAGS) $(LDFLAGS) -I $(INCDIR) -o $@ $<

.c.s:
	@echo generating $@
	@$(CC) -S -fverbose-asm $(CFLAGS) -I $(INCDIR) $< -o $@
