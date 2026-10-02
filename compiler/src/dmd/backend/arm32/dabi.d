/**
 * D frontend scalar types mapped onto AAPCS32 Stage B machine arguments.
 *
 * Compiler implementation of the
 * $(LINK2 https://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 2026 by The D Language Foundation, All Rights Reserved
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 */

module dmd.backend.arm32.dabi;

import dmd.astenums : TY;
import dmd.backend.arm32.aapcs :
    FundamentalArgument, MarshalledArgument, marshalComposite, marshalFundamental;

nothrow:
@safe:

/**
 * Map scalar D frontend types to the Android ARM32 base PCS.
 *
 * Returns false for types whose D ABI needs more than a scalar machine-type
 * choice (aggregates, slices, delegates, enums, vectors, complex values, etc.).
 *
 * DMD's frontend continues to represent D real as TY.Tfloat80. On Android
 * ARM32 Target.realsize is 8, so real uses the float64 AAPCS machine type.
 */
bool tryMarshalDScalar(TY ty, out MarshalledArgument argument)
{
    final switch (ty)
    {
        case TY.Tint8:
            argument = marshalFundamental(FundamentalArgument.signedByte);
            return true;

        case TY.Tuns8:
        case TY.Tbool:
        case TY.Tchar:
            argument = marshalFundamental(FundamentalArgument.unsignedByte);
            return true;

        case TY.Tint16:
            argument = marshalFundamental(FundamentalArgument.signedHalf);
            return true;

        case TY.Tuns16:
        case TY.Twchar:
            argument = marshalFundamental(FundamentalArgument.unsignedHalf);
            return true;

        case TY.Tint32:
        case TY.Tuns32:
        case TY.Tdchar:
            argument = marshalFundamental(FundamentalArgument.word);
            return true;

        case TY.Tint64:
        case TY.Tuns64:
            argument = marshalFundamental(FundamentalArgument.doubleWord);
            return true;

        case TY.Tfloat32:
            argument = marshalFundamental(FundamentalArgument.float32);
            return true;

        case TY.Tfloat64:
        case TY.Tfloat80:
            argument = marshalFundamental(FundamentalArgument.float64);
            return true;

        case TY.Tpointer:
        case TY.Treference:
        case TY.Tclass:
            argument = marshalFundamental(FundamentalArgument.pointer);
            return true;

        case TY.Tarray:
        case TY.Tsarray:
        case TY.Taarray:
        case TY.Tfunction:
        case TY.Tident:
        case TY.Tstruct:
        case TY.Tenum:
        case TY.Tdelegate:
        case TY.Tnone:
        case TY.Tvoid:
        case TY.Timaginary32:
        case TY.Timaginary64:
        case TY.Timaginary80:
        case TY.Tcomplex32:
        case TY.Tcomplex64:
        case TY.Tcomplex80:
        case TY.Terror:
        case TY.Tinstance:
        case TY.Ttypeof:
        case TY.Ttuple:
        case TY.Tslice:
        case TY.Treturn:
        case TY.Tnull:
        case TY.Tvector:
        case TY.Tint128:
        case TY.Tuns128:
        case TY.Ttraits:
        case TY.Tmixin:
        case TY.Tnoreturn:
        case TY.Ttag:
            argument = MarshalledArgument.init;
            return false;
    }
}


/**
 * Map D builtin argument shapes whose ABI is fixed without inspecting a
 * declaration or aggregate layout.
 *
 * Dynamic arrays and delegates are two pointer-sized fields. On ARM32 their
 * natural alignment is 4, so they occupy two consecutive AAPCS words but do
 * not use the 8-byte/even-register rule applied to uint64/double.
 *
 * Associative arrays are represented by one pointer-sized handle.
 */
bool tryMarshalDBuiltinArgument(TY ty, out MarshalledArgument argument)
{
    if (tryMarshalDScalar(ty, argument))
        return true;

    final switch (ty)
    {
        case TY.Tarray:
        case TY.Tdelegate:
            argument = marshalComposite(8, 4);
            return true;

        case TY.Taarray:
            argument = marshalFundamental(FundamentalArgument.pointer);
            return true;

        case TY.Tsarray:
        case TY.Tfunction:
        case TY.Tident:
        case TY.Tstruct:
        case TY.Tenum:
        case TY.Tnone:
        case TY.Tvoid:
        case TY.Timaginary32:
        case TY.Timaginary64:
        case TY.Timaginary80:
        case TY.Tcomplex32:
        case TY.Tcomplex64:
        case TY.Tcomplex80:
        case TY.Terror:
        case TY.Tinstance:
        case TY.Ttypeof:
        case TY.Ttuple:
        case TY.Tslice:
        case TY.Treturn:
        case TY.Tnull:
        case TY.Tvector:
        case TY.Tint128:
        case TY.Tuns128:
        case TY.Ttraits:
        case TY.Tmixin:
        case TY.Tnoreturn:
        case TY.Ttag:

        // Handled by tryMarshalDScalar above.
        case TY.Tpointer:
        case TY.Treference:
        case TY.Tclass:
        case TY.Tint8:
        case TY.Tuns8:
        case TY.Tbool:
        case TY.Tchar:
        case TY.Tint16:
        case TY.Tuns16:
        case TY.Twchar:
        case TY.Tint32:
        case TY.Tuns32:
        case TY.Tdchar:
        case TY.Tint64:
        case TY.Tuns64:
        case TY.Tfloat32:
        case TY.Tfloat64:
        case TY.Tfloat80:
            argument = MarshalledArgument.init;
            return false;
    }
}
