#!/bin/bash
#
# sync-conf-example.sh - a "sync.sh" configuration file example.
#
# (C) Bruno Raoult ("br"), 2007-2022
# Licensed under the GNU General Public License v3.0 or later.
# Some rights reserved. See COPYING.
#
# You should have received a copy of the GNU General Public License along with this
# program. If not, see <https://www.gnu.org/licenses/gpl-3.0-standalone.html>.
#
# SPDX-License-Identifier: GPL-3.0-or-later <https://spdx.org/licenses/GPL-3.0-or-later.html>
#
# USAGE:
#    sync.sh -rfu /path/to/sync-conf-example.sh

# full source path
SOURCEDIR=/example-srcdir
# server name. Could also be user@hostname
SERVER=backuphost
# full destination path on target machine (or relative to home directory)
DESTDIR=/mnt/array3+4/example-destdir

# backups to keep
NYEARS=2
NMONTHS=12
NWEEKS=4
NDAYS=7

# FILTER can be used to filter directories to include/exclude. See rsync(1) for
# details.
FILTER=--filter="dir-merge .rsync-filter-br"

# other rsync options
RSYNCOPTS=""

# functions run just before and after the rsync. Could be useful to create
# database dumps, etc...
# Warning: avoid using "cd", or be sure to come back to current dir
# before returning from functions

# example below will create a dump
function beforesync() {
    # next line may be removed if you do something. bash does not like empty
    # functions
    :

    # log is a sync.sh function.
    log -s -t "calling user beforesync: mysql databases dumps..."

    datadir=$(mysql -sN -u root -e 'select @@datadir')
    # log "mysql datadir=${datadir}"
    rm -f "$datadir/$FILTERNAME"
    databases=($(mysql -sN -u root -e "SHOW DATABASES;"))

    for db in "${databases[@]}"
    do
        # exclude database directory itself
		echo "- /${db}/*" >> "$datadir/$FILTERNAME"

        log -n "${db}... "
        case "$db" in
            information_schema|performance_schema)
                log "skipped."
                ;;
            *)
                log -n "dumping to ${datadir}${db}.sql... "
                mysqldump --user=root --routines "$db" > "$datadir/$db.sql"
                # log -n "compressing... "
                gzip "$datadir/$db.sql"
                log "done."
        esac
    done
    # log "filtername contains:"
    # cat ${datadir}/${FILTERNAME}
}

function aftersync() {
    # next line may be removed if you do something. bash does not like empty
    # functions
    :
    # we may remove the dump here...
    log -s -t "calling user aftersync"
}
