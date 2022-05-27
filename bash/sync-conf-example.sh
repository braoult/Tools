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

# below, default values are just below the lines starting with '######'.
# The only mandatory ones are SOURCEDIR, SERVER, and DESTDIR.

###### source directory full path, destination server and path.
###### SERVER could user@host, or "local" if local machine
# SOURCEDIR=""
# SERVER=""
# DESTDIR=""
SOURCEDIR=/example-srcdir
SERVER=root@backuphost
DESTDIR=/mnt/nas1/example-destdir

###### backups to keep
# NYEARS=3
# NMONTHS=12
# NWEEKS=6
# NDAYS=10

###### other rsync options. It must be an array.
# RSYNCOPTS=()
FILTERNAME=".rsync-filter-system"
FILTER=--filter="dir-merge ${FILTERNAME}"
RSYNCOPTS+=("$FILTER")

###### functions run immediately before and after the rsync. Can be used
###### to create database dumps, etc...
###### Warning: avoid using "cd", or be sure to come back to current dir
###### before returning from functions
# beforesync() { log "calling default beforesync..."; }
# aftersync()  { log "calling default aftersync...";  }

# example below will create a mysql/mariadb dump. At same time we create
# a FILTERNAME file in database data directory to exclude databases directories
# themselves.
function beforesync() {
    # log is a sync.sh function.
    log -s -t "calling user beforesync: mysql databases dumps..."

    datadir="$(mysql -sN -u root -e 'select @@datadir')"
    rm -f "$datadir/$FILTERNAME"
    readarray databases <<< "$(mysql -sN -u root -e "SHOW DATABASES;")"

    for db in "${databases[@]}"; do
        # exclude database directory itself
		printf "- /%s/*\n " "$db" >> "$datadir/$FILTERNAME"

        log -n "${db}... "
        case "$db" in
            information_schema|performance_schema)
                log "skipped."
                ;;
            *)
                log -n "dumping to ${datadir}${db}.sql... "
                mysqldump --user=root --routines "$db" > "$datadir/$db.sql"
                log -n "compressing... "
                gzip "$datadir/$db.sql"
                log "done."
        esac
    done
    # log "filtername contains:"
    # cat ${datadir}/${FILTERNAME}
}

function aftersync() {
    # we may remove the dump here...
    log -s -t "calling user aftersync"
}
