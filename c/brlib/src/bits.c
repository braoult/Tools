/* bits.c - information about bitops implementation.
 *
 * Copyright (C) 2021-2022 Bruno Raoult ("br")
 * Licensed under the GNU General Public License v3.0 or later.
 * Some rights reserved. See COPYING.
 *
 * You should have received a copy of the GNU General Public License along with this
 * program. If not, see <https://www.gnu.org/licenses/gpl-3.0-standalone.html>.
 *
 * SPDX-License-Identifier: GPL-3.0-or-later <https://spdx.org/licenses/GPL-3.0-or-later.html>
 *
 */

#include "bits.h"
#include "debug.h"

/**
 * bits_implementation - display bitops implementation.
 *
 * For basic bitops (popcount, ctz, etc...), print the implementation
 * (builtin, emulated).
 */
void bits_implementation(void)
{
    log(0, "bitops implementation: ");

    log(0, "popcount64: ");
#   if __has_builtin(__builtin_popcountl)
    log(0, "builtin, ");
#   else
    log(0, "emulated, ");
#   endif

    log(0, "popcount32: ");
#   if __has_builtin(__builtin_popcount)
    log(0, "builtin, ");
#   else
    log(0, "emulated, ");
#   endif

    log(0, "ctz64: ");
#   if __has_builtin(__builtin_ctzl)
    log(0, "builtin, ");
#   elif __has_builtin(__builtin_clzl)
    log(0, "builtin (clzl), ");
#   else
    log(0, "emulated, ");
#   endif

    log(0, "ctz32: ");
#   if __has_builtin(__builtin_ctz)
    log(0, "builtin, ");
#   elif __has_builtin(__builtin_clz)
    log(0, "builtin (clz), ");
#   else
    log(0, "emulated, ");
#   endif

    log(0, "clz64: ");
#   if __has_builtin(__builtin_clzl)
    log(0, "builtin, ");
#   else
    log(0, "emulated, ");
#   endif

    log(0, "clz32: ");
#   if __has_builtin(__builtin_clz)
    log(0, "builtin, ");
#   else
    log(0, "emulated, ");
#   endif

    log(0, "ffs64: ");
#   if __has_builtin(__builtin_ffsl)
    log(0, "builtin, ");
#   elif __has_builtin(__builtin_ctzl)
    log(0, "builtin (ctzl), ");
#   else
    log(0, "emulated, ");
#   endif

    log(0, "ffs32: ");
#   if __has_builtin(__builtin_ffs)
    log(0, "builtin, ");
#   elif __has_builtin(__builtin_ctz)
    log(0, "builtin (ctzl), ");
#   else
    log(0, "emulated, ");
#   endif
    log(0, "\n");
}
