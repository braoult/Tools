/* SPDX-License-Identifier: GPL-2.0 */

#ifndef _BR_HASH_H
#define _BR_HASH_H
/* adaptation of Linux kernel's <linux/hash.h> and <linux/stringhash.h>
 */

/* Fast hashing routine for ints,  longs and pointers.
   (C) 2002 Nadia Yvette Chambers, IBM */

#include <asm/types.h>
#include <asm/bitsperlong.h>
#include "bits.h"
#include "br.h"

/*
 * The "GOLDEN_RATIO_PRIME" is used in ifs/btrfs/brtfs_inode.h and
 * fs/inode.c.  It's not actually prime any more (the previous primes
 * were actively bad for hashing), but the name remains.
 */
#if __BITS_PER_LONG == 32
#define GOLDEN_RATIO_PRIME GOLDEN_RATIO_32
#define hash_long(val, bits) hash_32(val, bits)
#elif __BITS_PER_LONG == 64
#define hash_long(val, bits) hash_64(val, bits)
#define GOLDEN_RATIO_PRIME GOLDEN_RATIO_64
#else
#error Wordsize not 32 or 64
#endif

/*
 * This hash multiplies the input by a large odd number and takes the
 * high bits.  Since multiplication propagates changes to the most
 * significant end only, it is essential that the high bits of the
 * product be used for the hash value.
 *
 * Chuck Lever verified the effectiveness of this technique:
 * http://www.citi.umich.edu/techreports/reports/citi-tr-00-1.pdf
 *
 * Although a random odd number will do, it turns out that the golden
 * ratio phi = (sqrt(5)-1)/2, or its negative, has particularly nice
 * properties.  (See Knuth vol 3, section 6.4, exercise 9.)
 *
 * These are the negative, (1 - phi) = phi**2 = (3 - sqrt(5))/2,
 * which is very slightly easier to multiply by and makes no
 * difference to the hash distribution.
 */
#define GOLDEN_RATIO_32 0x61C88647
#define GOLDEN_RATIO_64 0x61C8864680B583EBull

/*
 * The _generic versions exist only so lib/test_hash.c can compare
 * the arch-optimized versions with the generic.
 *
 * Note that if you change these, any <asm/hash.h> that aren't updated
 * to match need to have their HAVE_ARCH_* define values updated so the
 * self-test will not false-positive.
 */
#ifndef HAVE_ARCH__HASH_32
#define __hash_32 __hash_32_generic
#endif
static inline u32 __hash_32_generic(u32 val)
{
	return val * GOLDEN_RATIO_32;
}

static inline u32 hash_32(u32 val, unsigned int bits)
{
	/* High bits are more random, so use them. */
	return __hash_32(val) >> (32 - bits);
}

#ifndef HAVE_ARCH_HASH_64
#define hash_64 hash_64_generic
#endif
static __always_inline u32 hash_64_generic(u64 val, unsigned int bits)
{
#if __BITS_PER_LONG == 64
	/* 64x64-bit multiply is efficient on all 64-bit processors */
	return val * GOLDEN_RATIO_64 >> (64 - bits);
#else
	/* Hash 64 bits using only 32x32-bit multiply. */
	return hash_32((u32)val ^ __hash_32(val >> 32), bits);
#endif
}

static inline u32 hash_ptr(const void *ptr, unsigned int bits)
{
	return hash_long((unsigned long)ptr, bits);
}

/* This really should be called fold32_ptr; it does no hashing to speak of. */
static inline u32 hash32_ptr(const void *ptr)
{
	unsigned long val = (unsigned long)ptr;

#if __BITS_PER_LONG == 64
	val ^= (val >> 32);
#endif
	return (u32)val;
}

/*
 * Routines for hashing strings of bytes to a 32-bit hash value.
 *
 * These hash functions are NOT GUARANTEED STABLE between kernel
 * versions, architectures, or even repeated boots of the same kernel.
 * (E.g. they may depend on boot-time hardware detection or be
 * deliberately randomized.)
 *
 * They are also not intended to be secure against collisions caused by
 * malicious inputs; much slower hash functions are required for that.
 *
 * They are optimized for pathname components, meaning short strings.
 * Even if a majority of files have longer names, the dynamic profile of
 * pathname components skews short due to short directory names.
 * (E.g. /usr/lib/libsesquipedalianism.so.3.141.)
 */

/*
 * Version 1: one byte at a time.  Example of use:
 *
 * unsigned long hash = init_name_hash;
 * while (*p)
 *	hash = partial_name_hash(tolower(*p++), hash);
 * hash = end_name_hash(hash);
 *
 * Although this is designed for bytes, fs/hfsplus/unicode.c
 * abuses it to hash 16-bit values.
 */

/* Hash courtesy of the R5 hash in reiserfs modulo sign bits */
#define init_name_hash(salt)		(unsigned long)(salt)

/* partial hash update function. Assume roughly 4 bits per character */
static inline unsigned long
partial_name_hash(unsigned long c, unsigned long prevhash)
{
	return (prevhash + (c << 4) + (c >> 4)) * 11;
}

/*
 * Finally: cut down the number of bits to a int value (and try to avoid
 * losing bits).  This also has the property (wanted by the dcache)
 * that the msbits make a good hash table index.
 */
static inline unsigned int end_name_hash(unsigned long hash)
{
	return hash_long(hash, 32);
}

/*
 * Version 2: One word (32 or 64 bits) at a time.
 * If CONFIG_DCACHE_WORD_ACCESS is defined (meaning <asm/word-at-a-time.h>
 * exists, which describes major Linux platforms like x86 and ARM), then
 * this computes a different hash function much faster.
 *
 * If not set, this falls back to a wrapper around the preceding.
 */
extern unsigned int __pure full_name_hash(const void *salt, const char *, unsigned int);

/*
 * A hash_len is a u64 with the hash of a string in the low
 * half and the length in the high half.
 */
#define hashlen_hash(hashlen) ((u32)(hashlen))
#define hashlen_len(hashlen)  ((u32)((hashlen) >> 32))
#define hashlen_create(hash, len) ((u64)(len)<<32 | (u32)(hash))

/* Return the "hash_len" (hash and length) of a null-terminated string */
extern u64 __pure hashlen_string(const void *salt, const char *name);

#endif /* _BR_HASH_H */
