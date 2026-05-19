/*
 * xxHash - Extremely Fast Hash algorithm
 * Copyright (C) 2012-2021 Yann Collet
 *
 * BSD 2-Clause License (https://www.opensource.org/licenses/bsd-license.php)
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are
 * met:
 *
 *    * Redistributions of source code must retain the above copyright
 *      notice, this list of conditions and the following disclaimer.
 *    * Redistributions in binary form must reproduce the above
 *      copyright notice, this list of conditions and the following disclaimer
 *      in the documentation and/or other materials provided with the
 *      distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * You can contact the author at:
 *   - xxHash homepage: https://www.xxhash.com
 *   - xxHash source repository: https://github.com/Cyan4973/xxHash
 */

// Claude Code rewrite of the original library
// Released under the same BSD 2-Clause License as the original xxHash

namespace Eden
{

// XXH3 streaming (used by the engine via XXH3_64bits_update + _digest) produces the same
// digest as XXH3_64bits applied to the concatenation of all updates, so this oneshot
// implementation is bit-for-bit equivalent to the C++ hash for any input.
//
// Verify against the C++ reference before relying on the result.
public static class XxHash3
{
    private const ulong PRIME64_1 = 0x9E3779B185EBCA87UL;
    private const ulong PRIME64_2 = 0xC2B2AE3D27D4EB4FUL;
    private const ulong PRIME64_3 = 0x165667B19E3779F9UL;
    private const ulong PRIME64_4 = 0x85EBCA77C2B2AE63UL;
    private const ulong PRIME64_5 = 0x27D4EB2F165667C5UL;
    private const uint  PRIME32_1 = 0x9E3779B1U;
    private const uint  PRIME32_2 = 0x85EBCA77U;
    private const uint  PRIME32_3 = 0xC2B2AE3DU;

    private const int STRIPE_LEN          = 64;
    private const int SECRET_CONSUME_RATE = 8;
    private const int ACC_NB              = STRIPE_LEN / 8;          // 8
    private const int SECRET_DEFAULT_SIZE = 192;
    private const int SECRET_SIZE_MIN     = 136;                     // referenced by len_129to240

    private const int MIDSIZE_STARTOFFSET   = 3;
    private const int MIDSIZE_LASTOFFSET    = 17;
    private const int SECRET_LASTACC_START  = 7;
    private const int SECRET_MERGEACCS_START = 11;

    private static readonly byte[] kSecret = new byte[SECRET_DEFAULT_SIZE]
    {
        0xb8,0xfe,0x6c,0x39,0x23,0xa4,0x4b,0xbe, 0x7c,0x01,0x81,0x2c,0xf7,0x21,0xad,0x1c,
        0xde,0xd4,0x6d,0xe9,0x83,0x90,0x97,0xdb, 0x72,0x40,0xa4,0xa4,0xb7,0xb3,0x67,0x1f,
        0xcb,0x79,0xe6,0x4e,0xcc,0xc0,0xe5,0x78, 0x82,0x5a,0xd0,0x7d,0xcc,0xff,0x72,0x21,
        0xb8,0x08,0x46,0x74,0xf7,0x43,0x24,0x8e, 0xe0,0x35,0x90,0xe6,0x81,0x3a,0x26,0x4c,
        0x3c,0x28,0x52,0xbb,0x91,0xc3,0x00,0xcb, 0x88,0xd0,0x65,0x8b,0x1b,0x53,0x2e,0xa3,
        0x71,0x64,0x48,0x97,0xa2,0x0d,0xf9,0x4e, 0x38,0x19,0xef,0x46,0xa9,0xde,0xac,0xd8,
        0xa8,0xfa,0x76,0x3f,0xe3,0x9c,0x34,0x3f, 0xf9,0xdc,0xbb,0xc7,0xc7,0x0b,0x4f,0x1d,
        0x8a,0x51,0xe0,0x4b,0xcd,0xb4,0x59,0x31, 0xc8,0x9f,0x7e,0xc9,0xd9,0x78,0x73,0x64,
        0xea,0xc5,0xac,0x83,0x34,0xd3,0xeb,0xc3, 0xc5,0x81,0xa0,0xff,0xfa,0x13,0x63,0xeb,
        0x17,0x0d,0xdd,0x51,0xb7,0xf0,0xda,0x49, 0xd3,0x16,0x55,0x26,0x29,0xd4,0x68,0x9e,
        0x2b,0x16,0xbe,0x58,0x7d,0x47,0xa1,0xfc, 0x8f,0xf8,0xb8,0xd1,0x7a,0xd0,0x31,0xce,
        0x45,0xcb,0x3a,0x8f,0x95,0x16,0x04,0x28, 0xaf,0xd7,0xfb,0xca,0xbb,0x4b,0x40,0x7e,
    };

    public static ulong Hash64(byte[] data)
    {
        return Hash64(data, 0, data.Length);
    }

    public static ulong Hash64(byte[] data, int offset, int len)
    {
        if (len <= 16)  return Len0to16(data, offset, len);
        if (len <= 128) return Len17to128(data, offset, len);
        if (len <= 240) return Len129to240(data, offset, len);
        return HashLong(data, offset, len);
    }

    // --- bit helpers ---

    private static ulong ReadLE64(byte[] b, int o)
    {
        return  (ulong)b[o]
             | ((ulong)b[o + 1] << 8)
             | ((ulong)b[o + 2] << 16)
             | ((ulong)b[o + 3] << 24)
             | ((ulong)b[o + 4] << 32)
             | ((ulong)b[o + 5] << 40)
             | ((ulong)b[o + 6] << 48)
             | ((ulong)b[o + 7] << 56);
    }

    private static uint ReadLE32(byte[] b, int o)
    {
        return  (uint)b[o]
             | ((uint)b[o + 1] << 8)
             | ((uint)b[o + 2] << 16)
             | ((uint)b[o + 3] << 24);
    }

    private static ulong Swap64(ulong x)
    {
        return ((x & 0x00000000000000FFUL) << 56) | ((x & 0x000000000000FF00UL) << 40)
             | ((x & 0x0000000000FF0000UL) << 24) | ((x & 0x00000000FF000000UL) << 8)
             | ((x & 0x000000FF00000000UL) >> 8)  | ((x & 0x0000FF0000000000UL) >> 24)
             | ((x & 0x00FF000000000000UL) >> 40) | ((x & 0xFF00000000000000UL) >> 56);
    }

    private static ulong Rotl64(ulong x, int n) => (x << n) | (x >> (64 - n));

    private static ulong XorShift64(ulong v, int s) => v ^ (v >> s);

    // 64x64 -> 128 multiplication, returns low64 ^ high64
    private static ulong Mul128Fold64(ulong a, ulong b)
    {
        ulong aL = a & 0xFFFFFFFFUL, aH = a >> 32;
        ulong bL = b & 0xFFFFFFFFUL, bH = b >> 32;

        ulong t0 = aL * bL;
        ulong t1 = aH * bL + (t0 >> 32);
        ulong t2 = aL * bH + (t1 & 0xFFFFFFFFUL);

        ulong lo = (t2 << 32) | (t0 & 0xFFFFFFFFUL);
        ulong hi = aH * bH + (t1 >> 32) + (t2 >> 32);
        return lo ^ hi;
    }

    // --- avalanche stages ---

    private static ulong Avalanche(ulong h64)
    {
        h64 = XorShift64(h64, 37);
        h64 *= 0x165667919E3779F9UL;
        h64 = XorShift64(h64, 32);
        return h64;
    }

    private static ulong Avalanche64(ulong h)
    {
        h ^= h >> 33;
        h *= PRIME64_2;
        h ^= h >> 29;
        h *= PRIME64_3;
        h ^= h >> 32;
        return h;
    }

    private static ulong Rrmxmx(ulong h, ulong len)
    {
        h ^= Rotl64(h, 49) ^ Rotl64(h, 24);
        h *= 0x9FB21C651E98DF25UL;
        h ^= (h >> 35) + len;
        h *= 0x9FB21C651E98DF25UL;
        return XorShift64(h, 28);
    }

    // 16-byte mix used by all medium paths (seed always 0 here, so + and - of seed cancel)
    private static ulong Mix16B(byte[] input, int inOff, int secOff)
    {
        ulong inLo = ReadLE64(input, inOff);
        ulong inHi = ReadLE64(input, inOff + 8);
        return Mul128Fold64(
            inLo ^ ReadLE64(kSecret, secOff),
            inHi ^ ReadLE64(kSecret, secOff + 8));
    }

    // --- short input paths (only used if Hash64 ever sees len <= 16) ---

    private static ulong Len0to16(byte[] input, int o, int len)
    {
        if (len > 8)  return Len9to16(input, o, len);
        if (len >= 4) return Len4to8(input, o, len);
        if (len > 0)  return Len1to3(input, o, len);
        return Avalanche64(ReadLE64(kSecret, 56) ^ ReadLE64(kSecret, 64));
    }

    private static ulong Len1to3(byte[] input, int o, int len)
    {
        byte c1 = input[o];
        byte c2 = input[o + (len >> 1)];
        byte c3 = input[o + len - 1];
        uint combined = ((uint)c1 << 16) | ((uint)c2 << 24) | (uint)c3 | ((uint)len << 8);
        ulong bitflip = ReadLE32(kSecret, 0) ^ ReadLE32(kSecret, 4);
        return Avalanche64((ulong)combined ^ bitflip);
    }

    private static ulong Len4to8(byte[] input, int o, int len)
    {
        uint i1 = ReadLE32(input, o);
        uint i2 = ReadLE32(input, o + len - 4);
        ulong bitflip = ReadLE64(kSecret, 8) ^ ReadLE64(kSecret, 16);
        ulong input64 = i2 + ((ulong)i1 << 32);
        return Rrmxmx(input64 ^ bitflip, (ulong)len);
    }

    private static ulong Len9to16(byte[] input, int o, int len)
    {
        ulong bitflip1 = ReadLE64(kSecret, 24) ^ ReadLE64(kSecret, 32);
        ulong bitflip2 = ReadLE64(kSecret, 40) ^ ReadLE64(kSecret, 48);
        ulong inLo = ReadLE64(input, o) ^ bitflip1;
        ulong inHi = ReadLE64(input, o + len - 8) ^ bitflip2;
        ulong acc = (ulong)len + Swap64(inLo) + inHi + Mul128Fold64(inLo, inHi);
        return Avalanche(acc);
    }

    // --- mid paths ---

    private static ulong Len17to128(byte[] input, int o, int len)
    {
        ulong acc = (ulong)len * PRIME64_1;
        if (len > 32)
        {
            if (len > 64)
            {
                if (len > 96)
                {
                    acc += Mix16B(input, o + 48,           96);
                    acc += Mix16B(input, o + len - 64,    112);
                }
                acc += Mix16B(input, o + 32,               64);
                acc += Mix16B(input, o + len - 48,         80);
            }
            acc += Mix16B(input, o + 16,                   32);
            acc += Mix16B(input, o + len - 32,             48);
        }
        acc += Mix16B(input, o,                             0);
        acc += Mix16B(input, o + len - 16,                 16);
        return Avalanche(acc);
    }

    private static ulong Len129to240(byte[] input, int o, int len)
    {
        ulong acc = (ulong)len * PRIME64_1;
        int nbRounds = len / 16;
        for (int i = 0; i < 8; i++)
            acc += Mix16B(input, o + 16 * i, 16 * i);
        acc = Avalanche(acc);
        for (int i = 8; i < nbRounds; i++)
            acc += Mix16B(input, o + 16 * i, 16 * (i - 8) + MIDSIZE_STARTOFFSET);
        acc += Mix16B(input, o + len - 16, SECRET_SIZE_MIN - MIDSIZE_LASTOFFSET);
        return Avalanche(acc);
    }

    // --- long path (>240 bytes) ---

    private static void ScalarRound(ulong[] acc, byte[] input, int inOff, int secOff, int lane)
    {
        ulong dataVal = ReadLE64(input, inOff + lane * 8);
        ulong dataKey = dataVal ^ ReadLE64(kSecret, secOff + lane * 8);
        acc[lane ^ 1] += dataVal;
        acc[lane]     += (dataKey & 0xFFFFFFFFUL) * (dataKey >> 32);
    }

    private static void Accumulate512(ulong[] acc, byte[] input, int inOff, int secOff)
    {
        for (int i = 0; i < ACC_NB; i++)
            ScalarRound(acc, input, inOff, secOff, i);
    }

    private static void Accumulate(ulong[] acc, byte[] input, int inOff, int secOff, int nbStripes)
    {
        for (int n = 0; n < nbStripes; n++)
            Accumulate512(acc, input, inOff + n * STRIPE_LEN, secOff + n * SECRET_CONSUME_RATE);
    }

    private static void ScrambleAcc(ulong[] acc, int secOff)
    {
        for (int lane = 0; lane < ACC_NB; lane++)
        {
            ulong key64 = ReadLE64(kSecret, secOff + lane * 8);
            ulong v     = acc[lane];
            v  = XorShift64(v, 47);
            v ^= key64;
            v *= PRIME32_1;
            acc[lane] = v;
        }
    }

    private static ulong Mix2Accs(ulong[] acc, int accOff, int secOff)
    {
        return Mul128Fold64(
            acc[accOff]     ^ ReadLE64(kSecret, secOff),
            acc[accOff + 1] ^ ReadLE64(kSecret, secOff + 8));
    }

    private static ulong MergeAccs(ulong[] acc, int secOff, ulong start)
    {
        ulong result = start;
        for (int i = 0; i < 4; i++)
            result += Mix2Accs(acc, 2 * i, secOff + 16 * i);
        return Avalanche(result);
    }

    private static ulong HashLong(byte[] input, int o, int len)
    {
        ulong[] acc = new ulong[ACC_NB]
        {
            PRIME32_3, PRIME64_1, PRIME64_2, PRIME64_3,
            PRIME64_4, PRIME32_2, PRIME64_5, PRIME32_1,
        };

        const int secretSize = SECRET_DEFAULT_SIZE;
        int nbStripesPerBlock = (secretSize - STRIPE_LEN) / SECRET_CONSUME_RATE; // 16
        int blockLen          = STRIPE_LEN * nbStripesPerBlock;                   // 1024
        int nbBlocks          = (len - 1) / blockLen;

        for (int n = 0; n < nbBlocks; n++)
        {
            Accumulate(acc, input, o + n * blockLen, 0, nbStripesPerBlock);
            ScrambleAcc(acc, secretSize - STRIPE_LEN);
        }

        // last partial block
        int nbStripes = ((len - 1) - blockLen * nbBlocks) / STRIPE_LEN;
        Accumulate(acc, input, o + nbBlocks * blockLen, 0, nbStripes);

        // last stripe (always full)
        Accumulate512(acc, input, o + len - STRIPE_LEN, secretSize - STRIPE_LEN - SECRET_LASTACC_START);

        return MergeAccs(acc, SECRET_MERGEACCS_START, (ulong)len * PRIME64_1);
    }
}

}
