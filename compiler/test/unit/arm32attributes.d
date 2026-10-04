// See ../README.md for information about DMD unit tests.

module arm32attributes;

import dmd.backend.arm32.attributes : androidArmeabiV7aAttributes;

@("Android armeabi-v7a AEABI attributes are structurally fixed")
unittest
{
    assert(androidArmeabiV7aAttributes.length == 52);
    assert(androidArmeabiV7aAttributes[0] == 'A');
    assert(androidArmeabiV7aAttributes[1] == 0x33); // vendor subsection length
    assert(androidArmeabiV7aAttributes[11] == 1);   // Tag_File
    assert(androidArmeabiV7aAttributes[12] == 0x29); // file subsection length

    // Conservative ABI-critical tags.
    assert(androidArmeabiV7aAttributes[16] == 0x06);
    assert(androidArmeabiV7aAttributes[17] == 0x0A); // CPU arch v7
    assert(androidArmeabiV7aAttributes[24] == 0x0A);
    assert(androidArmeabiV7aAttributes[25] == 0x04); // VFPv3-D16
    assert(androidArmeabiV7aAttributes[26] == 0x0E);
    assert(androidArmeabiV7aAttributes[27] == 0x00); // r9=v6
}
