/* pjwhash.h - PJW hash function, extern version.
 *
 * Copyright (C) 2021-2022 Bruno Raoult ("br")
 * Licensed under the GNU General Public License v3.0 or later.
 * Some rights reserved. See COPYING.
 *
 * You should have received a copy of the GNU General Public License along with this
 * program. If not, see <https://www.gnu.org/licenses/gpl-3.0-standalone.html>.
 *
 * SPDX-License-Identifier: GPL-3.0-or-later <https://spdx.org/licenses/GPL-3.0-or-later.html>
 */

#ifndef _PJWHASH_H
#define _PJWHASH_H

#include "bits.h"

/**
 * unsigned int pjwhash - PJW hash function
 * @key:    the key address.
 * @length: the length of key.
 *
 * This hash was created by Peter Jay Weinberger (AT&T Bell Labs):
 * https://en.wikipedia.org/wiki/PJW_hash_function
 *
 * Return: the PJW hash.
 */
extern uint  pjwhash (const void* key, uint length);

#endif  /* _PJWHASH_H */
