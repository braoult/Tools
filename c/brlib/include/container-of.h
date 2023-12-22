/* SPDX-License-Identifier: GPL-2.0 */

/* adaptation of Linux kernel's <linux/container_of.h>
 */
#ifndef _BR_CONTAINER_OF_H
#define _BR_CONTAINER_OF_H

/* Are two types/vars the same type (ignoring qualifiers)? */
#define __same_type(a, b) __builtin_types_compatible_p(typeof(a), typeof(b))

/**
 * typeof_member -
 */
#define typeof_member(T, m)     typeof(((T*)0)->m)

/**
 * container_of - cast a member of a structure out to the containing structure
 * @ptr:        the pointer to the member.
 * @type:       the type of the container struct this is embedded in.
 * @member:     the name of the member within the struct.
 *
 */
#define container_of(ptr, type, member) ({                              \
        void *__mptr = (void *)(ptr);                                   \
        _Static_assert(__same_type(*(ptr), ((type *)0)->member) ||       \
                      __same_type(*(ptr), void),                        \
                      "pointer type mismatch in container_of()");       \
        ((type *)(__mptr - offsetof(type, member))); })

#endif /* BR_CONTAINER_OF_H */
