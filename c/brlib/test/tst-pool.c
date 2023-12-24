#include <stdio.h>
#include "bits.h"
#include "pool.h"

struct d {
    u16 data1;
    char c;
    struct list_head list;
};

static LIST_HEAD (head);

int main(int ac, char**av)
{
    pool_t *pool;
    int total;
    int action=0;
    u16 icur=0;
    char ccur='z';
    struct d *elt;

    debug_init(3);
    log_f(1, "%s: sizeof(d)=%lu sizeof(*d)=%lu off=%lu\n", *av, sizeof(elt),
          sizeof(*elt), offsetof(struct d, list));

    if ((pool = pool_create("dummy", 3, sizeof(*elt)))) {
        pool_stats(pool);
        for (int cur=1; cur<ac; ++cur) {
            total = atoi(av[cur]);
            if (action == 0) {                    /* add elt to list */
                log_f(2, "adding %d elements\n", total);
                for (int i = 0; i < total; ++i) {
                    elt = pool_get(pool);
                    elt->data1 = icur++;
                    elt->c = ccur--;
                    list_add(&elt->list, &head);
                }
                pool_stats(pool);
                action = 1;
            } else {                              /* remove one elt from list */
                log_f(2, "deleting %d elements\n", total);
                for (int i = 0; i < total; ++i) {
                    if (!list_empty(&head)) {
                        elt = list_last_entry(&head, struct d, list);
                        printf("elt=[%d, %c]\n", elt->data1, elt->c);
                        list_del(&elt->list);
                        pool_add(pool, elt);
                    }
                }
                pool_stats(pool);
                action = 0;
            }
        }
    }
    pool_stats(pool);
    pool_destroy(pool);
}
