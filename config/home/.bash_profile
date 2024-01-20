#!/usr/bin/env bash
#
# ~/.bash_profile - bash login script.
#
# (C) Bruno Raoult ("br"), 2024
# Licensed under the GNU General Public License v3.0 or later.
# Some rights reserved. See COPYING.
#
# You should have received a copy of the GNU General Public License along with this
# program. If not, see <https://www.gnu.org/licenses/gpl-3.0-standalone.html>.
#
# For login shells, ~/.profile is executed. Debian default one does:
#   1) source .bashrc if it exists
#   2) add "$HOME"/bin in PATH
# This imply a duplicate "$HOME/bin" in PATH, as we do everything in .bashrc.$user.

 [ -f "$HOME/.bashrc" ] && . "$HOME/.bashrc"
