/* SPDX-License-Identifier: GPL-2.0 */

/*
 * Taken from linux kernel: lib/list_sort.c
 */

#ifndef _BR_LIST_SORT_H
#define _BR_LIST_SORT_H

//#include <linux/types.h>

struct list_head;

typedef int __attribute__((nonnull(2,3))) (*list_cmp_func_t)(void *,
		const struct list_head *, const struct list_head *);

__attribute__((nonnull(2,3)))
void list_sort(void *priv, struct list_head *head, list_cmp_func_t cmp);

#endif  /* _BR_LIST_SORT */
