# Tools Makefile
#
# Copyright (C) 2023 Bruno Raoult ("br")
# Licensed under the GNU General Public License v3.0 or later.
# Some rights reserved. See COPYING.
#
# You should have received a copy of the GNU General Public License along with this
# program. If not, see <https://www.gnu.org/licenses/gpl-3.0-standalone.html>.
#
# SPDX-License-Identifier: GPL-3.0-or-later <https://spdx.org/licenses/GPL-3.0-or-later.html>
#

SHELL     := /bin/bash
CC        := gcc
BEAR      := bear

CFLAGS    += -std=gnu11
CFLAGS    += -O2
CFLAGS    += -g
CFLAGS    += -Wall
CFLAGS    += -Wextra
CFLAGS    += -march=native
CFLAGS    += -Wmissing-declarations
CFLAGS    += -Wno-unused-result
# for gprof
#CFLAGS    += -pg
# Next one may be useful for valgrind (some invalid instructions)
#CFLAGS    += -mno-tbm

CPPFLAGS += -DDEBUG_DEBUG		# activate general debug (debug.c)
CPPFLAGS += -DDEBUG_POOL		# memory pools management

INCDIR    := ./include
LIBDIR    := ./lib
OBJDIR    := ./obj
BRLIBDIR  := ./brlib

LIBNAME   := br_$(shell uname -m)
#LIB       := lib$(LIBNAME)


all: brlib

#export LD_LIBRARY_PATH = $(LIBDIR)

.PHONY: all brlib clean

all: brlib

brlib:
	$(MAKE) -C $(BRLIBDIR)

bear ccls:
	@echo building ccls language server compilation database
	$(MAKE) -C $(BRLIBDIR) ccls

clean:
	@echo cleaning brlib.
	@$(MAKE) -C $(BRLIBDIR) clean
