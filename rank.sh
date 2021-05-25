#!/bin/bash
# Updated: Tues May 07 21:04:12 2013 by webmaster@askapache
# @ https://www.askapache.com/shellscript/reflector-ranking-mirrors/
# Copyright (C) 2013 Free Software Foundation, Inc.
#
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.



# if mirrors exists, cat it, otherwise create it
function get_mirrors () #{{{1
{
   if [[ -s $MIRRORS ]]; then
          cat $MIRRORS;
   else
          curl -LksS -o - 'https://www.archlinux.org/mirrors/status/json/' | sed 's,{,\n{,g' | sed -n '/rsync/d; /pct": 1.0/p' | sed 's,^.*"url": "\([^"]\+\)".*,\1,g' > $MIRRORS
          cat $MIRRORS;
   fi
}

function get_core_urls () #{{{1
{
   get_mirrors | sed "s,$,core/os/${ARCH}/core.db.tar.gz,g"
}

function get_gcc_urls () #{{{1
{
   get_mirrors | sed "s,$,core/os/${ARCH}/${GCC_URL},g"
}


# rm tmp file on exit
trap "exitcode=\$?; (rm -f \$MIRRORS 2>/dev/null;) && exit \$exitcode" 0;
trap "exit 1" 1 2 13 15;


# file containing mirror urls
MIRRORS=`(mktemp -t reflector-mirrorsXXXX) 2>/dev/null` && test -w "$MIRRORS" || MIRRORS=~/reflector.mirrorsXXX

# arch
ARCH=`(uname -m) 2>/dev/null` || ARCH=x86_64

# the gcc file
GCC_URL=$( curl -LksSH --url ftp://ftp.archlinux.org/core/os/${ARCH}/ 2>/dev/null | sed -n 's/^.*\ \(gcc-[0-9]\+.*.tar.xz.sig\)\ -.*$/\1/gp' );


{
   # faster as primarily used to pre-resolve dns for 2nd core test
   get_gcc_urls | xargs -I'{}' -P40 curl -Lks -o /dev/null -m 3 --connect-timeout 4 --retry 0 --no-keepalive -w '%{time_total}@%{speed_download}@%{url_effective}\n' --url '{}' | sort -t@ -k2 -nr | head -n 50 | cut -d'@' -f3 | sed 's,core/os/'"${ARCH}/${GCC_URL}"',$repo/os/$arch,g'
   get_core_urls | xargs -I'{}' -P10 curl -Lks -o /dev/null -m 5 --connect-timeout 4 --retry 0 --no-keepalive -w '%{time_total}@%{speed_download}@%{url_effective}\n' --url '{}' | sort -t@ -k2 -nr | head -n 50 | cut -d'@' -f3 | sed 's,core/os/'"${ARCH}"'/core.db.tar.gz,$repo/os/$arch,g'
} | sed 's,^,Server = ,g' | awk '{ if (!h[$0]) { print $0; h[$0]=1 } }'


exit $?;