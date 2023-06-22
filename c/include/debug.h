/* debug.h - debug/log management.
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

#ifndef DEBUG_H
#define DEBUG_H

#include <stdbool.h>
#include <stdint.h>

#include <bits.h>

#define _unused __attribute__((__unused__))
#define _printf __attribute__ ((format (printf, 6, 7)))

#ifdef DEBUG_DEBUG
void debug_init(u32 level);
void debug_level_set(u32 level);
u32  debug_level_get(void);
void _printf debug(u32 level, bool timestamp,
                   u32 indent, const char *src,
                   u32 line, const char *fmt, ...);
#else  /* DEBUG_DEBUG */
static inline void debug_init(_unused u32 level) {}
static inline void debug_level_set(_unused u32 level) {}
static inline void _printf debug(_unused u32 level, _unused bool timestamp,
                                 _unused u32 indent, _unused const char *src,
                                 _unused u32 line, _unused const char *fmt, ...) {}
#endif  /* DEBUG_DEBUG */
#undef _unused
#undef _printf

/**
 * log - simple log (no function name, no indent, no timestamp)
 * @level:      log level
 * @fmt:        printf format string
 * @args:       subsequent arguments to printf
 */
#define log(level, fmt, args...) \
    debug((level), false, 0, NULL, 0, fmt, ##args)

/**
 * log_i - log with indent (no function name, no timestamp)
 * @level:      log level
 * @fmt:        printf format string
 * @args:       subsequent arguments to printf
 *
 * Output example:
 * >>>>val=2
 */
#define log_i(level, fmt, args...) \
    debug((level), false, (level), NULL, 0, fmt, ##args)

/**
 * log_f - log with function name (no indent name, no timestamp)
 * @level:      log level
 * @fmt:        printf format string
 * @args:       subsequent arguments to printf
 *
 * Output example:
 * [function] val=2
 */
#define log_f(level, fmt, args...) \
    debug((level), false, 0, __func__, 0, fmt, ##args)

/**
 * log_if - log with function name and line number (no indent name, no timestamp)
 * @level:      log level
 * @fmt:        printf format string
 * @args:       subsequent arguments to printf
 *
 * Output example:
 * >>>> [function:15] val=2
 */
#define log_if(level, fmt, args...) \
    debug((level), false, (level), __func__, __LINE__, fmt, ##args)

/**
 * log_it - log with function name, line number, indent, and timestamp
 * @level:      log level
 * @fmt:        printf format string
 * @args:       subsequent arguments to printf
 *
 * Output example:
 * >>>> [function:15] val=2
 */
#define log_it(level, fmt, args...) \
    debug((level), true, (level), __func__, __LINE__, fmt, ##args)

#endif /* DEBUG_H */
