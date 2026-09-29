// REQUIRED_ARGS: -m64 -os=netbsd -betterC -c

version (NetBSD) {}
else static assert(0, "NetBSD must be predefined");

version (Posix) {}
else static assert(0, "Posix must be predefined");

version (ELFv1) {}
else static assert(0, "ELFv1 must be predefined");

version (FreeBSD) static assert(0, "NetBSD must not define FreeBSD");
version (OpenBSD) static assert(0, "NetBSD must not define OpenBSD");
version (linux) static assert(0, "NetBSD must not define linux");

struct Pair
{
    double x;
    double y;
}

struct Mixed
{
    double x;
    long y;
}

extern(C) Pair passPair(Pair value, double scale)
{
    value.x *= scale;
    value.y *= scale;
    return value;
}

extern(C) Mixed passMixed(Mixed value, long delta)
{
    value.y += delta;
    return value;
}
