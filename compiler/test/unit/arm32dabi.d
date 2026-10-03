// See ../README.md for information about DMD unit tests.

module arm32dabi;

import dmd.astenums : TY;
import dmd.backend.arm32.aapcs : ArgumentExtension, MarshalledArgument;
import dmd.backend.arm32.dabi : tryMarshalDScalar;

@("D narrow integer scalars receive AAPCS32 extension")
unittest
{
    MarshalledArgument a;

    assert(tryMarshalDScalar(TY.Tint8, a));
    assert(a.size == 4 && a.alignment == 4);
    assert(a.extension == ArgumentExtension.signExtend);

    assert(tryMarshalDScalar(TY.Tbool, a));
    assert(a.extension == ArgumentExtension.zeroExtend);

    assert(tryMarshalDScalar(TY.Twchar, a));
    assert(a.extension == ArgumentExtension.zeroExtend);
}

@("D ARM32 word and double-word scalars map to base PCS sizes")
unittest
{
    MarshalledArgument a;

    assert(tryMarshalDScalar(TY.Tint32, a));
    assert(a.size == 4 && a.alignment == 4);

    assert(tryMarshalDScalar(TY.Tint64, a));
    assert(a.size == 8 && a.alignment == 8);

    assert(tryMarshalDScalar(TY.Tfloat32, a));
    assert(a.size == 4 && a.alignment == 4);

    assert(tryMarshalDScalar(TY.Tfloat64, a));
    assert(a.size == 8 && a.alignment == 8);

    // D real retains TY.Tfloat80 in the frontend, but Android ARM32 real is
    // binary64 in the target ABI.
    assert(tryMarshalDScalar(TY.Tfloat80, a));
    assert(a.size == 8 && a.alignment == 8);
}

@("D pointer-like scalar references are one ARM32 word")
unittest
{
    MarshalledArgument a;

    foreach (ty; [TY.Tpointer, TY.Treference, TY.Tclass])
    {
        assert(tryMarshalDScalar(ty, a));
        assert(a.size == 4 && a.alignment == 4);
        assert(!a.indirect);
    }
}

@("D non-scalar ABI cases remain explicit")
unittest
{
    MarshalledArgument a;

    foreach (ty; [
        TY.Tstruct,
        TY.Tarray,
        TY.Tdelegate,
        TY.Tenum,
        TY.Tcomplex64,
        TY.Tvector,
        TY.Tint128,
    ])
    {
        assert(!tryMarshalDScalar(ty, a));
    }
}
