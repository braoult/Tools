/* SPDX-License-Identifier: GPL-2.0 */

/*  taken from Kernel's <linux/compiler.h
 */
#ifndef __LIKELY_H
#define __LIKELY_H

/* See https://kernelnewbies.org/FAQ/LikelyUnlikely
 *
 * In 2 words:
 * "You should use it [likely() and unlikely()] only in cases when the likeliest
 *  branch is very very very likely, or when the unlikeliest branch is very very
 *  very unlikely."
 */
# define likely(x)      __builtin_expect(!!(x), 1)
# define unlikely(x)    __builtin_expect(!!(x), 0)

#endif /* __LIKELY_H */
