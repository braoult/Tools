/* bits.h - bits functions.
 *
 * Copyright (C) 2021 Bruno Raoult ("br")
 * Licensed under the GNU General Public License v3.0 or later.
 * Some rights reserved. See COPYING.
 *
 * You should have received a copy of the GNU General Public License along with this
 * program. If not, see <https://www.gnu.org/licenses/gpl-3.0-standalone.html>.
 *
 * SPDX-License-Identifier: GPL-3.0-or-later <https://spdx.org/licenses/GPL-3.0-or-later.html>
 *
 */
#ifndef BITS_H
#define BITS_H

#include <stdint.h>

/* next include will define __WORDSIZE: 32 or 64
 */
#include <bits/wordsize.h>

#ifndef __has_builtin
#define __has_builtin(x) 0
#endif

/* no plan to support 32bits for now...
 */
#if __WORDSIZE != 64
ERROR_64_BYTES_WORDSIZE_ONLY
#endif

typedef int64_t  s64;
typedef int32_t  s32;
typedef int16_t  s16;
typedef int8_t   s8;

typedef uint64_t u64;
typedef uint32_t u32;
typedef uint16_t u16;
typedef uint8_t  u8;
typedef unsigned int uint;
typedef unsigned char uchar;

/* count trailing zeroes : 00101000 -> 3
 *                              ^^^
 */
static inline int ctz64(u64 n)
{
#   if __has_builtin(__builtin_ctzl)
#   ifdef DEBUG_BITS
    log_f(1, "builtin ctzl.\n");
#   endif
    return __builtin_ctzl(n);

#   elif __has_builtin(__builtin_clzl)
#   ifdef DEBUG_BITS
    log_f(1, "builtin clzl.\n");
#   endif
    return __WORDSIZE - (__builtin_clzl(n & -n) + 1);

#   else
#   ifdef DEBUG_BITS
    log_f(1, "emulated.\n");
#   endif
    return popcount64((n & −n) − 1);
#   endif
}

/* count leading zeroes : 00101000 -> 2
 *                        ^^
 */
static inline int clz64(u64 n)
{
#   if __has_builtin(__builtin_clzl)
#   ifdef DEBUG_BITS
    log_f(1, "builtin.\n");
#   endif
    return __builtin_clzl(n);

#   else
#   ifdef DEBUG_BITS
    log_f(1, "emulated.\n");
#   endif
    u64 r, q;

    r = (n > 0xFFFFFFFF) << 5; n >>= r;
    q = (n > 0xFFFF)     << 4; n >>= q; r |= q;
    q = (n > 0xFF  )     << 3; n >>= q; r |= q;
    q = (n > 0xF   )     << 2; n >>= q; r |= q;
    q = (n > 0x3   )     << 1; n >>= q; r |= q;
    r |= (n >> 1);
    return __WORDSIZE - r - 1;
#   endif
}

/* find first set :  00101000 -> 4
 *                       ^
 */
static inline uint ffs64(u64 n)
{
#   if __has_builtin(__builtin_ffsl)
#   ifdef DEBUG_BITS
    log_f(1, "builtin ffsl.\n");
#   endif
    return __builtin_ffsll(n);

#   elif __has_builtin(__builtin_ctzl)
#   ifdef DEBUG_BITS
    log_f(1, "builtin ctzl.\n");
#   endif
    if (n == 0)
        return (0);
    return __builtin_ctzl(n) + 1;

#   else
#   ifdef DEBUG_BITS
    log_f(1, "emulated.\n");
#   endif
    return popcount64(n ^ ~-n);
#   endif
}

static inline int popcount64(u64 n)
{
#   if __has_builtin(__builtin_popcountl)
#   ifdef DEBUG_BITS
    log_f(1, "builtin.\n");
#   endif
    return __builtin_popcountl(n);

#   else
#   ifdef DEBUG_BITS
    log_f(1, "emulated.\n");
#   endif
    int count = 0;
    while (n) {
        count++;
        n &= (n - 1);
    }
    return count;
#   endif
}

/** bit_for_each64 - iterate over an u64 bits
 * @pos:        an int used as current bit
 * @tmp:        a temp u64 used as temporary storage
 * @ul:         the u64 to loop over
 *
 * Usage:
 * u64 u=139, _t;     //  u=b10001011
 * int cur;
 * bit_for_each64(cur, _t, u) {
 *     printf("%d\n", cur);
 * }
 * This will display the position of each bit set in ul: 1, 2, 4, 8
 *
 * I should probably re-think the implementation...
 */
#define bit_for_each64(pos, tmp, ul)                                    \
    for (tmp = ul, pos = ffs64(tmp); tmp; tmp &= (tmp - 1),  pos = ffs64(tmp))

/** or would it be more useful (counting bits from zero instead of 1) ?
 */
#define bit_for_each64_2(pos, tmp, ul)                                  \
    for (tmp = ul, pos = ctz64(tmp); tmp; tmp ^= 1UL<<pos, pos = ctz64(tmp))

#endif  /* BITS_H */
