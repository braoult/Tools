/* bits.h - bits functions.
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
#ifndef _BITS_H
#define _BITS_H

#include <stdint.h>
#include <stdbool.h>

/* next include will define __WORDSIZE: 32 or 64
 */
#include <bits/wordsize.h>

#ifndef __has_builtin
#define __has_builtin(x) 0
#endif

/* no plan to support 32bits for now...
 * #if __WORDSIZE != 64
 * #error "Only 64 bits word size supported."
 * #endif
 */

/* fixed-size types
 */
typedef int64_t  s64;
typedef int32_t  s32;
typedef int16_t  s16;
typedef int8_t   s8;

typedef uint64_t u64;
typedef uint32_t u32;
typedef uint16_t u16;
typedef uint8_t  u8;

/* convenience types
 */
typedef long long int llong;
typedef unsigned long long int ullong;
typedef unsigned long int ulong;
typedef unsigned int uint;
typedef unsigned short ushort;
typedef unsigned char uchar;

/* define common types sizes
 */
#define BITS_PER_CHAR 8

#ifndef BITS_PER_SHORT
#define BITS_PER_SHORT (BITS_PER_CHAR * sizeof (short))
#endif
#ifndef BITS_PER_INT
#define BITS_PER_INT   (BITS_PER_CHAR * sizeof (int))
#endif
#ifndef BITS_PER_LONG
#define BITS_PER_LONG  (BITS_PER_CHAR * sizeof (long))
#endif
#ifndef BITS_PER_LLONG
#define BITS_PER_LLONG (BITS_PER_CHAR * sizeof (long long))
#endif

/* count set bits:  10101000 -> 3
 *                  ^ ^ ^
 */
static __always_inline int popcount64(u64 n)
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

static __always_inline int popcount32(u32 n)
{
#   if __has_builtin(__builtin_popcount)
#   ifdef DEBUG_BITS
    log_f(1, "builtin.\n");
#   endif
    return __builtin_popcount(n);

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

/* char is a special case, as it can be signed or unsigned
 */
typedef signed char schar;

/* count trailing zeroes : 00101000 -> 3
 *                              ^^^
 */
static __always_inline int ctz64(u64 n)
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
    return popcount64((n & -n) - 1);
#   endif
}

static __always_inline int ctz32(u32 n)
{
#   if __has_builtin(__builtin_ctz)
#   ifdef DEBUG_BITS
    log_f(1, "builtin ctz.\n");
#   endif
    return __builtin_ctzl(n);

#   elif __has_builtin(__builtin_clz)
#   ifdef DEBUG_BITS
    log_f(1, "builtin clz.\n");
#   endif
    return __WORDSIZE - (__builtin_clz(n & -n) + 1);

#   else
#   ifdef DEBUG_BITS
    log_f(1, "emulated.\n");
#   endif
    return popcount32((n & -n) - 1);
#   endif
}

/* clz - count leading zeroes : 00101000 -> 2
 *                              ^^
 */
static __always_inline int clz64(u64 n)
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
    return 64 - r - 1;
#   endif
}

static __always_inline int clz32(u32 n)
{
#   if __has_builtin(__builtin_clz)
#   ifdef DEBUG_BITS
    log_f(1, "builtin.\n");
#   endif
    return __builtin_clz(n);

#   else
#   ifdef DEBUG_BITS
    log_f(1, "emulated.\n");
#   endif
    u32 r, q;

    r = (n > 0xFFFF)     << 4; n >>= r;
    q = (n > 0xFF  )     << 3; n >>= q; r |= q;
    q = (n > 0xF   )     << 2; n >>= q; r |= q;
    q = (n > 0x3   )     << 1; n >>= q; r |= q;
    r |= (n >> 1);
    return 32 - r - 1;
#   endif
}

/* fls - find last set : 00101000 -> 6
 *                           ^
 */
static __always_inline int fls64(u64 n)
{
    if (!n)
        return 0;
    return 64 - clz64(n);
}

static __always_inline int fls32(u32 n)
{
    if (!n)
        return 0;
    return 32 - clz32(n);
}

/* find first set :  00101000 -> 4
 *                       ^
 */
static __always_inline uint ffs64(u64 n)
{
#   if __has_builtin(__builtin_ffsl)
#   ifdef DEBUG_BITS
    log_f(1, "builtin ffsl.\n");
#   endif
    return __builtin_ffsl(n);

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

static __always_inline uint ffs32(u32 n)
{
#   if __has_builtin(__builtin_ffs)
#   ifdef DEBUG_BITS
    log_f(1, "builtin ffs.\n");
#   endif
    return __builtin_ffs(n);

#   elif __has_builtin(__builtin_ctz)
#   ifdef DEBUG_BITS
    log_f(1, "builtin ctz.\n");
#   endif
    if (n == 0)
        return (0);
    return __builtin_ctz(n) + 1;

#   else
#   ifdef DEBUG_BITS
    log_f(1, "emulated.\n");
#   endif
    return popcount32(n ^ ~-n);
#   endif
}

/*  rolXX are taken from kernel's <linux/bitops.h> are are:
 * SPDX-License-Identifier: GPL-2.0
 */

/**
 * rol64 - rotate a 64-bit value left
 * @word: value to rotate
 * @shift: bits to roll
 */
static inline u64 rol64(u64 word, unsigned int shift)
{
	return (word << (shift & 63)) | (word >> ((-shift) & 63));
}

/**
 * ror64 - rotate a 64-bit value right
 * @word: value to rotate
 * @shift: bits to roll
 */
static inline u64 ror64(u64 word, unsigned int shift)
{
	return (word >> (shift & 63)) | (word << ((-shift) & 63));
}

/**
 * rol32 - rotate a 32-bit value left
 * @word: value to rotate
 * @shift: bits to roll
 */
static inline u32 rol32(u32 word, unsigned int shift)
{
	return (word << (shift & 31)) | (word >> ((-shift) & 31));
}

/**
 * ror32 - rotate a 32-bit value right
 * @word: value to rotate
 * @shift: bits to roll
 */
static inline u32 ror32(u32 word, unsigned int shift)
{
	return (word >> (shift & 31)) | (word << ((-shift) & 31));
}

/**
 * rol16 - rotate a 16-bit value left
 * @word: value to rotate
 * @shift: bits to roll
 */
static inline u16 rol16(u16 word, unsigned int shift)
{
	return (word << (shift & 15)) | (word >> ((-shift) & 15));
}

/**
 * ror16 - rotate a 16-bit value right
 * @word: value to rotate
 * @shift: bits to roll
 */
static inline u16 ror16(u16 word, unsigned int shift)
{
	return (word >> (shift & 15)) | (word << ((-shift) & 15));
}

/**
 * rol8 - rotate an 8-bit value left
 * @word: value to rotate
 * @shift: bits to roll
 */
static inline u8 rol8(u8 word, unsigned int shift)
{
	return (word << (shift & 7)) | (word >> ((-shift) & 7));
}

/**
 * ror8 - rotate an 8-bit value right
 * @word: value to rotate
 * @shift: bits to roll
 */
static inline u8 ror8(u8 word, unsigned int shift)
{
	return (word >> (shift & 7)) | (word << ((-shift) & 7));
}

/**
 * ilog2 -
 */
static __always_inline __attribute__((const))
int __ilog2_u32(u32 n)
{
	return fls32(n) - 1;
}

static __always_inline __attribute__((const))
int __ilog2_u64(u64 n)
{
	return fls64(n) - 1;
}

/**
 * is_power_of_2() - check if a value is a power of two
 * @n: the value to check
 *
 * Determine whether some value is a power of two, where zero is
 * *not* considered a power of two.
 * Return: true if @n is a power of 2, otherwise false.
 */
static inline __attribute__((const))
bool is_power_of_2(unsigned long n)
{
	return (n != 0 && ((n & (n - 1)) == 0));
}

/**
 * ilog2 - log base 2 of 32-bit or a 64-bit unsigned value
 * @n: parameter
 *
 * constant-capable log of base 2 calculation
 * - this can be used to initialise global variables from constant data, hence
 * the massive ternary operator construction
 *
 * selects the appropriately-sized optimised version depending on sizeof(n)
 */
#define ilog2(n) \
( \
	__builtin_constant_p(n) ?	\
	((n) < 2 ? 0 :			\
	 63 - __builtin_clzll(n)) :	\
	(sizeof(n) <= 4) ?		\
	__ilog2_u32(n) :		\
	__ilog2_u64(n)			\
 )

/**
 * roundup_pow_of_two - round the given value up to nearest power of two
 * @n: parameter
 *
 * round the given value up to the nearest power of two
 * - the result is undefined when n == 0
 * - this can be used to initialise global variables from constant data
 */
#define roundup_pow_of_two(n)			\
(						\
	__builtin_constant_p(n) ? (		\
		((n) == 1) ? 1 :		\
		(1UL << (ilog2((n) - 1) + 1))	\
				   ) :		\
	__roundup_pow_of_two(n)			\
 )

/**
 * rounddown_pow_of_two - round the given value down to nearest power of two
 * @n: parameter
 *
 * round the given value down to the nearest power of two
 * - the result is undefined when n == 0
 * - this can be used to initialise global variables from constant data
 */
#define rounddown_pow_of_two(n)			\
(						\
	__builtin_constant_p(n) ? (		\
		(1UL << ilog2(n))) :		\
	__rounddown_pow_of_two(n)		\
 )

static inline __attribute_const__
int __order_base_2(unsigned long n)
{
	return n > 1 ? ilog2(n - 1) + 1 : 0;
}

/**
 * order_base_2 - calculate the (rounded up) base 2 order of the argument
 * @n: parameter
 *
 * The first few values calculated by this routine:
 *  ob2(0) = 0
 *  ob2(1) = 0
 *  ob2(2) = 1
 *  ob2(3) = 2
 *  ob2(4) = 2
 *  ob2(5) = 3
 *  ... and so on.
 */
#define order_base_2(n)				\
(						\
	__builtin_constant_p(n) ? (		\
		((n) == 0 || (n) == 1) ? 0 :	\
		ilog2((n) - 1) + 1) :		\
	__order_base_2(n)			\
)

static inline __attribute__((const))
int __bits_per(unsigned long n)
{
	if (n < 2)
		return 1;
	if (is_power_of_2(n))
		return order_base_2(n) + 1;
	return order_base_2(n);
}

/**
 * bits_per - calculate the number of bits required for the argument
 * @n: parameter
 *
 * This is constant-capable and can be used for compile time
 * initializations, e.g bitfields.
 *
 * The first few values calculated by this routine:
 * bf(0) = 1
 * bf(1) = 1
 * bf(2) = 2
 * bf(3) = 2
 * bf(4) = 3
 * ... and so on.
 */
#define bits_per(n)				\
(						\
	__builtin_constant_p(n) ? (		\
		((n) == 0 || (n) == 1)		\
			? 1 : ilog2(n) + 1	\
	) :					\
	__bits_per(n)				\
)

/** bit_for_each - iterate over an u64/u32 bits
 * @pos:        an int used as current bit
 * @tmp:        a temp u64/u32 used as temporary storage
 * @ul:         the u64/u32 to loop over
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

#define bit_for_each32(pos, tmp, ul)                                    \
    for (tmp = ul, pos = ffs32(tmp); tmp; tmp &= (tmp - 1),  pos = ffs32(tmp))

/** or would it be more useful (counting bits from zero instead of 1) ?
 */
#define bit_for_each64_2(pos, tmp, ul)                                  \
    for (tmp = ul, pos = ctz64(tmp); tmp; tmp ^= 1UL << pos, pos = ctz64(tmp))

#define bit_for_each32_2(pos, tmp, ul)                                  \
    for (tmp = ul, pos = ctz32(tmp); tmp; tmp ^= 1U << pos, pos = ctz32(tmp))

#endif  /* _BITS_H */
