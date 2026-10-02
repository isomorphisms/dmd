// See ../README.md for information about DMD unit tests.

module arm32target;

import dmd.globals : Param;
import dmd.target : CPU, Target, TargetC;

@("ARM32 target uses Android AAPCS scalar layout")
unittest
{
    Param params;
    Target t;
    t.os = Target.OS.linux;
    t.isARM32 = true;
    t.cpu = CPU.baseline;
    t._init(params);

    assert(t.isARM32);
    assert(!t.isAArch64);
    assert(!t.isX86);
    assert(!t.isX86_64);
    assert(!t.isLP64);

    assert(t.ptrsize == 4);
    assert(t.realsize == 8);
    assert(t.realpad == 0);
    assert(t.realalignsize == 8);
    assert(t.stackAlign == 8);
    assert(t.architectureName == "ARM");

    assert(t.c.longsize == 4);
    assert(t.c.long_longsize == 8);
    assert(t.c.long_doublesize == 8);
    assert(t.c.wchar_tsize == 4);

    t.setCPU();
    assert(t.cpu == CPU.baseline);
}

@("Android target identity is Linux plus Bionic")
unittest
{
    Param params;
    Target t;
    t.os = Target.OS.linux;
    t.isARM32 = true;
    t._init(params);

    assert(!t.isAndroid);
    t.c.runtime = TargetC.Runtime.Bionic;
    assert(t.isAndroid);
}
