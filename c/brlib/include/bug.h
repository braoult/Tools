/* SPDX-License-Identifier: GPL-2.0 */
#ifndef _BR_BUG_H
#define _BR_BUG_H

#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include "likely.h"
#include "debug.h"

/* BUG functions inspired by Linux kernel's <asm/bug.h>
 */

#define panic() exit(0xff)

/*
 * Don't use BUG() or BUG_ON() unless there's really no way out; one
 * example might be detecting data structure corruption in the middle
 * of an operation that can't be backed out of.  If the (sub)system
 * can somehow continue operating, perhaps with reduced functionality,
 * it's probably not BUG-worthy.
 *
 * If you're tempted to BUG(), think again:  is completely giving up
 * really the *only* solution?  There are usually better options, where
 * users don't need to reboot ASAP and can mostly shut down cleanly.
 */
#define BUG() do {                                                                      \
        fprintf(stderr, "BUG: failure at %s:%d/%s()!\n", __FILE__, __LINE__, __func__); \
        panic();                                                                        \
    } while (0)

#define BUG_ON(condition) do { if (unlikely(condition)) BUG(); } while (0)

/*
 * WARN(), WARN_ON(), WARN_ON_ONCE, and so on can be used to report
 * significant kernel issues that need prompt attention if they should ever
 * appear at runtime.
 *
 * Do not use these macros when checking for invalid external inputs
 * (e.g. invalid system call arguments, or invalid data coming from
 * network/devices), and on transient conditions like ENOMEM or EAGAIN.
 * These macros should be used for recoverable kernel issues only.
 * For invalid external inputs, transient conditions, etc use
 * pr_err[_once/_ratelimited]() followed by dump_stack(), if necessary.
 * Do not include "BUG"/"WARNING" in format strings manually to make these
 * conditions distinguishable from kernel issues.
 *
 * Use the versions with printk format strings to provide better diagnostics.
 */
#define __WARN() do {                                                      \
        fprintf(stderr, "WARNING: failure at %s:%d/%s()!\n", __FILE__, __LINE__, __func__); \
    } while (0)
#define __WARN_printf(arg...) do {              \
        vfprintf(stderr, arg);                  \
    } while (0)

#define WARN_ON(condition) ({                   \
            int __ret_warn_on = !!(condition);  \
            if (unlikely(__ret_warn_on))        \
		__WARN();                       \
            unlikely(__ret_warn_on);            \
        })

#define WARN(condition, format...) ({           \
            int __ret_warn_on = !!(condition);  \
            if (unlikely(__ret_warn_on))        \
		__WARN_printf(format);          \
            unlikely(__ret_warn_on);            \
        })

#endif /* _BR_BUG_H */
