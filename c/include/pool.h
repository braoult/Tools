/* pool.h - A simple memory pool manager.
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

#ifndef POOL_H
#define POOL_H

#include <stdint.h>
#include <stddef.h>
#include "list.h"
#include "bits.h"

#define POOL_NAME_LENGTH (16)                     /* max name length including trailing \0 */

typedef struct {
    struct list_head list_blocks;                 /* list of allocated blocks in pool */
    char data[];                                  /* objects block */
} block_t;

typedef struct {
    char name[POOL_NAME_LENGTH];                  /* pool name */
    u32 available;                                /* current available elements */
    u32 allocated;                                /* total objects allocated */
    u32 growsize;                                 /* number of objects per block allocated */
    size_t eltsize;                               /* object size */
    u32 nblocks;                                  /* number of blocks allocated */
    struct list_head list_available;              /* available nodes */
    struct list_head list_blocks;                 /* allocated blocks */
} pool_t;

/**
 * pool_stats - display some pool statistics
 * @pool:    the pool address.
 */
void pool_stats(pool_t *pool);

/**
 * pool_create - create a new memory pool
 * @name:    the name to give to the pool.
 * @grow:    the number of elements to add when no more available.
 * @size:    the size of an element in pool.
 */
pool_t *pool_create(const char *name, u32 grow, size_t size);

/**
 * pool_get - get an element from a pool
 * @pool:    the pool address.
 */
void *pool_get(pool_t *pool);

/**
 * pool_add - add (release) an element to a pool
 * @pool:    the pool address.
 * @elt:     the address of the object to add to the pool.
 */
u32 pool_add(pool_t *pool, void *elt);

/**
 * pool_destroy - destroy a pool.
 * @pool:    the pool address.
 *
 * Attention: All memory is freed, but no check is done whether all pool
 * elements has been released. Referencing any pool object after this call
 * is strongly discouraged.
 */
void pool_destroy(pool_t *pool);

#endif
