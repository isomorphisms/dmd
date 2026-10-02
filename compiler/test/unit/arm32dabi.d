// See ../README.md for information about DMD unit tests.

module arm32dabi;

import dmd.astenums : TY;
import dmd.backend.arm32.aapcs :
    AAPCS32Allocator, ArgumentExtension, FundamentalArgument,
    MarshalledArgument, marshalFundamental;
import dmd.backend.arm32.dabi :
    tryMarshalDBuiltinArgument, tryMarshalDScalar;

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


@("D dynamic arrays and delegates are two 4-byte-aligned words")
unittest
{
    MarshalledArgument a;

    assert(tryMarshalDBuiltinArgument(TY.Tarray, a));
    assert(a.size == 8);
    assert(a.alignment == 4);
    assert(!a.indirect);

    assert(tryMarshalDBuiltinArgument(TY.Tdelegate, a));
    assert(a.size == 8);
    assert(a.alignment == 4);
    assert(!a.indirect);
}

@("D associative arrays are one pointer word")
unittest
{
    MarshalledArgument a;
    assert(tryMarshalDBuiltinArgument(TY.Taarray, a));
    assert(a.size == 4 && a.alignment == 4);
    assert(!a.indirect);
}

@("D slice pair does not acquire uint64 even-register alignment")
unittest
{
    MarshalledArgument slice;
    assert(tryMarshalDBuiltinArgument(TY.Tarray, slice));

    AAPCS32Allocator sliceAbi;
    sliceAbi.place(marshalFundamental(FundamentalArgument.word)); // r0
    auto slicePlacement = sliceAbi.place(slice);
    assert(slicePlacement.firstRegister == 1);
    assert(slicePlacement.registerCount == 2);

    AAPCS32Allocator wideAbi;
    wideAbi.place(marshalFundamental(FundamentalArgument.word)); // r0
    auto widePlacement =
        wideAbi.place(marshalFundamental(FundamentalArgument.doubleWord));
    assert(widePlacement.firstRegister == 2);
    assert(widePlacement.registerCount == 2);
}
