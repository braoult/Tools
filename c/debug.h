/* move.h - debug/log management.
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

#ifndef DEBUG_H
#define DEBUG_H

#include <stdbool.h>
#include <stdint.h>

#include "bits.h"

#define _unused __attribute__((__unused__))
#define _printf __attribute__ ((format (printf, 6, 7)))
#ifdef DEBUG_DEBUG
#define _printf __attribute__ ((format (printf, 6, 7)))
void debug_init(u32 level);
void debug_level_set(u32 level);
void debug_devel_set(u32 level);
void _printf debug(u32 level, bool timestamp,
                   u32 indent, const char *src,
                   u32 line, const char *, ...);
#else  /* DEBUG_DEBUG */
static inline void debug_init(_unused u32 level) {}
static inline void debug_level_set(_unused u32 level) {}
static inline void debug_devel_set(_unused u32 level) {}
static inline void _printf debug(_unused u32 level, _unused bool timestamp,
                                 _unused u32 indent, _unused const char *src,
                                 _unused u32 line, const char *, ...) {}
#endif  /* DEBUG_DEBUG */
#undef _unused
#undef _printf

/* format: only printf
 */
#define log(level, fmt, args...) \
    debug((level), false, 0, NULL, 0, fmt, ##args)

/* format : indent, no func name, no timestamp
 * >>>>val=2
 */
#define log_i(level, fmt, args...) \
    debug((level), false, (level), NULL, 0, fmt, ##args)

/* format : func name, no indent, no timestamp
 * [foo] val=2
 */
#define log_f(level, fmt, args...) \
    debug((level), false, 0, __func__, 0, fmt, ##args)

/* format : func name, no indent, no timestamp
 * >>>> [foo:15] val=2
 */
#define log_if(level, fmt, args...) \
    debug((level), false, (level), __func__, __LINE__, fmt, ##args)

/* format : func name, indent, timestamp
 * >>>>foo:15 val=2
 */
#define log_it(level, fmt, args...) \
    debug((level), true, (level), __func__, __LINE__, fmt, ##args)

/* format: file name, no indent, no timestamp
 * foo:15 val=2
 *
 * #define log_f(level, fmt, args...)                            \
 *   debug((level), false, 0, __FILE__, __LINE__, fmt, args)
 */

#else
#define log(level, fmt, args...)
#define log_i(...)
#define log_f(...)
#define log_if(...)
#define log_it(...)
#define log_f(...)

#endif  /* DEBUG_H */
