/* SPDX-License-Identifier: GPL-2.0 */
/*
 * See Documentation/core-api/circular-buffers.rst for more information.
 */

#include <stdlib.h>
#include <stdio.h>

#define CIRC_BUF(name, type, bits)               \
    struct s##name {                             \
        type buf[1 << (bits)];                   \
        int head;                                \
        int tail;                                \
    } name = {                                   \
        { 0 },                                   \
        0,                                       \
        0 };

struct circ_buf {
	char *buf;
	int head;
	int tail;
};

/* Return count in buffer.  */
#define CIRC_CNT(head,tail,size) (((head) - (tail)) & ((size)-1))

/* Return space available, 0..size-1.  We always leave one free char
   as a completely full buffer has head == tail, which is the same as
   empty.  */
#define CIRC_SPACE(head,tail,size) CIRC_CNT((tail),((head)+1),(size))

/* Return count up to the end of the buffer.  Carefully avoid
   accessing head and tail more than once, so they can change
   underneath us without returning inconsistent results.  */
#define CIRC_CNT_TO_END(head,tail,size) \
	({int end = (size) - (tail); \
	  int n = ((head) + end) & ((size)-1); \
	  n < end ? n : end;})

/* Return space available up to the end of the buffer.  */
#define CIRC_SPACE_TO_END(head,tail,size) \
	({int end = (size) - 1 - (head); \
	  int n = (end + (tail)) & ((size)-1); \
	  n <= end ? n : end+1;})


int main(int ac, char **av)
{
    int size = 5;

    if (ac > 8) {
        size = atoi(*(av + 1));
    }
    printf("size-%d\n", size);

    CIRC_BUF(foo, int, 5);
    printf("sizeof(elt)=%lu\n", sizeof(foo.buf[0]));
    printf("sizeof(buf)=%lu\n", sizeof(foo.buf));

}
