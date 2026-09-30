#include <stdio.h>

typedef struct
{
    double x;
    double y;
} Pair;

typedef struct
{
    double x;
    long y;
} Mixed;

extern Pair passPair(Pair value, double scale);
extern Mixed passMixed(Mixed value, long delta);
extern long double passReal(long double value);

int main(void)
{
    _Static_assert(sizeof(void *) == 8, "NetBSD amd64 pointer size");
    _Static_assert(sizeof(long) == 8, "NetBSD amd64 C long size");
    _Static_assert(sizeof(long double) == 16, "NetBSD amd64 long double size");
    _Static_assert(sizeof(Pair) == 16, "Pair layout");
    _Static_assert(sizeof(Mixed) == 16, "Mixed layout");

    const Pair p = passPair((Pair){1.5, -2.0}, 2.0);
    if (p.x != 3.0 || p.y != -4.0)
    {
        fprintf(stderr, "Pair ABI mismatch: %.17g %.17g\n", p.x, p.y);
        return 1;
    }

    const Mixed m = passMixed((Mixed){3.25, 7}, 5);
    if (m.x != 3.25 || m.y != 12)
    {
        fprintf(stderr, "Mixed ABI mismatch: %.17g %ld\n", m.x, m.y);
        return 2;
    }

    const long double r = passReal(1.25L);
    if (r != 1.25L)
    {
        fprintf(stderr, "real/long double ABI mismatch\n");
        return 3;
    }

    puts("NetBSD amd64 D/C ABI probe passed");
    return 0;
}
