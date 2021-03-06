/*  arith05.c                         Copyright (C) 1990-2002 Codemist Ltd */

/*
 * Arithmetic functions.
 *    low-level 64/32 bit arithmetic, <=, print_bignum
 */

/*
 * This code may be used and modified, and redistributed in binary
 * or source form, subject to the "CCL Public License", which should
 * accompany it. This license is a variant on the BSD license, and thus
 * permits use of code derived from this in either open and commercial
 * projects: but it does require that updates to this code be made
 * available back to the originators of the package.
 * Before merging other code in with this or linking this code
 * with other packages or libraries please check that the license terms
 * of the other material are compatible with those of this.
 */


/* Signature: 50767ab9 08-Apr-2002 */

#include <stdarg.h>
#include <string.h>
#include <ctype.h>
#include <math.h>

#include "machine.h"
#include "tags.h"
#include "cslerror.h"
#include "externs.h"
#include "arith.h"
#include "stream.h"
#ifdef TIMEOUT
#include "timeout.h"
#endif


/*
 * I provide symbols IMULTIPLY and IDIVIDE which can be asserted if the
 * corresponding routines have been provided elsewhere (e.g. in machine
 * code for extra speed)
 */

#ifndef IDIVIDE
#ifdef MULDIV64

unsigned32 Idiv10_9(unsigned32 *qp, unsigned32 high, unsigned32 low)
/*
 * Same behaviour as Idivide(qp, high, low, 1000000000U).
 * Used for printing only - i.e. only in this file
 */
{
    unsigned64 p = ((unsigned64)high << 31) | (unsigned64)low;
    *qp = (unsigned32)(p / (unsigned64)1000000000U);
    return (unsigned32)(p % (unsigned64)1000000000U);
}


#else

unsigned32 Idiv10_9(unsigned32 *qp, unsigned32 high, unsigned32 low)
/*
 * Same behaviour as Idivide(qp, high, low, 1000000000U).
 * If Idivide is coded in assembler then this will probably be
 * easy and sensible to implement as an alternative entrypoint.
 * The code given here is intended for use on computers where
 * division is a slow operation - it works by a sort of long
 * division, forming guessed for the partial quotients my
 * multiplying by a (binary scaled) reciprocal of 1000000000.
 *
 * Used for printing only - i.e. only in this file
 */
{
#define RECIP_10_9  70368U   /* 2^46/10^9 */
#define TEN_9_16H   15258U
/*
 * The APOLLO conditionalisation is a work-round for a bug present
 * July 1992 in at least some versions of the APOLLO C compiler, whereby
 * multiplication by 51712 was treated as multiplication by
 * (65536-51712).  Putting the constant in a variable is a temporary
 * patch and will be removed as soon as we hear reports of a newer
 * and mended Apollo C compiler!
 */
#ifdef __APOLLO__
static unsigned32 TEN_9_16L = 51712U;
#else
#define TEN_9_16L   51712U    /* 10^9 in 2 chunks, base 2^16 */
#endif
#define TEN_9_15H   30517U
#define TEN_9_15L   18944U    /* 10^9 in 2 chunks, base 2^15 */

    unsigned32 w = ((high >> 14) * RECIP_10_9) >> 16;
/*
 * The above line sets w to the first partial quotient.  Multiply
 * it back up by 10^9 (working base 2^16 while so doing) and subtract
 * that off from the original number to get a residue.
 */
    unsigned32 w1 = w * TEN_9_16L, w2, w3, w4, w5;
    w2 = w1 >> 16;
    high -= (w * TEN_9_16H + w2);
    low -= ((w1 << 15) & 0x7fffffff);
    if ((int32)low < 0)
    {   high--;
        low &= 0x7fffffff;
    }
/*
 * Now do the same sort of operation again to get the next
 * part of the quotient.
 */
    w3 = (high * RECIP_10_9) >> 15;
/*
 * when I multiply back up by 10^9 and subtract off I need to use
 * all the bits that there are in my 32-bit words, and it seems to
 * turn out that working base 2^15 rather than 2^16 here is best.
 */
    w4 = w3 * TEN_9_15H;
    w5 = w4 >> 16;
    high -= w5;
    w4 -= (w5 << 16);
    low -= (w3 * TEN_9_15L);
    if ((int32)low < 0)
    {   high--;         /* propage a borrow */
        low &= 0x7fffffff;
    }
    low -= (w4 << 15);
    if ((int32)low < 0)
    {   high--;         /* propagate another borrow */
        low &= 0x7fffffff;
    }
/*
 * The quotient that I compute here is almost correct - I will
 * adjust it by 1, 2, 3 or 4..
 */
    w = (w << 15) + w3;
/*
 * If high was nonzero I subtract (2*high*10^9) from low, and need not
 * consider high again.
 */
    if (high != 0)
    {   low -= (2000000000U + 0x80000000U);
        w += 2;
        if (high != 1)
        {   low -= (2000000000U + 0x80000000U);
            w += 2;
        }
    }
/*
 * final adjustment..
 */
    if (low >= 1000000000U)
    {   low -= 1000000000U;
        w += 1;
        if (low >= 1000000000U)
        {   low -= 1000000000U;
            w += 1;
        }
    }
    *qp = w;
    return low;
}

#endif
#endif /* IDIVIDE */


/*
 * Arithmetic comparison: lesseq
 * Note that for floating point values on a system which supports
 * IEEE arithmetic (and in particular Nans) it may not be the case
 * that (a < b) = !(b <= a).  Note also Common Lisp requires that
 * floating point values get widened to ratios in many cases here,
 * despite the vast cost thereof.
 */

#ifdef COMMON
static CSLbool lesseqis(Lisp_Object a, Lisp_Object b)
{
    Float_union bb;
    bb.i = b - TAG_SFLOAT;
    return (double)int_of_fixnum(a) <= (double)bb.f;
}
#endif

#define lesseqib(a, b) lesspib(a, b)

#ifdef COMMON
static CSLbool lesseqir(Lisp_Object a, Lisp_Object b)
{
/*
 * compute a <= p/q  as a*q <= p
 */
    push(numerator(b));
    a = times2(a, denominator(b));
    pop(b);
    return lesseq2(a, b);
}
#endif

#define lesseqif(a, b) ((double)int_of_fixnum(a) <= float_of_number(b))

#ifdef COMMON
static CSLbool lesseqsi(Lisp_Object a, Lisp_Object b)
{
    Float_union aa;
    aa.i = a - TAG_SFLOAT;
    return (double)aa.f <= (double)int_of_fixnum(b);
}

static CSLbool lesseqsb(Lisp_Object a, Lisp_Object b)
{
    Float_union aa;
    aa.i = a - TAG_SFLOAT;
    return !lesspbd(b, (double)aa.f);
}

static CSLbool lesseqsr(Lisp_Object a, Lisp_Object b)
{
    Float_union aa;
    aa.i = a - TAG_SFLOAT;
    return !lessprd(b, (double)aa.f);
}

static CSLbool lesseqsf(Lisp_Object a, Lisp_Object b)
{
    Float_union aa;
    aa.i = a - TAG_SFLOAT;
    return (double)aa.f <= float_of_number(b);
}
#endif

#define lesseqbi(a, b) lesspbi(a, b)

#ifdef COMMON
static CSLbool lesseqbs(Lisp_Object a, Lisp_Object b)
{
    Float_union bb;
    bb.i = b - TAG_SFLOAT;
    return !lesspdb((double)bb.f, a);
}
#endif

static CSLbool lesseqbb(Lisp_Object a, Lisp_Object b)
{
    int32 lena = bignum_length(a),
          lenb = bignum_length(b);
    if (lena > lenb)
    {   int32 msd = bignum_digits(a)[(lena-CELL-4)/4];
        return (msd < 0);
    }
    else if (lenb > lena)
    {   int32 msd = bignum_digits(b)[(lenb-CELL-4)/4];
        return (msd >= 0);
    }
    lena = (lena-CELL-4)/4;
    /* lenb == lena here */
    {   int32 msa = bignum_digits(a)[lena],
              msb = bignum_digits(b)[lena];
        if (msa < msb) return YES;
        else if (msa > msb) return NO;
/*
 * Now the leading digits of the numbers agree, so in particular the numbers
 * have the same sign.
 */
        while (--lena >= 0)
        {   unsigned32 da = bignum_digits(a)[lena],
                       db = bignum_digits(b)[lena];
            if (da == db) continue;
            return (da < db);
        }
        return YES;     /* numbers are the same */
    }
}

#define lesseqbr(a, b) lesseqir(a, b)

#define lesseqbf(a, b) (!lesspdb(float_of_number(b), a))

#ifdef COMMON
static CSLbool lesseqri(Lisp_Object a, Lisp_Object b)
{
    push(numerator(a));
    b = times2(b, denominator(a));
    pop(a);
    return lesseq2(a, b);
}

static CSLbool lesseqrs(Lisp_Object a, Lisp_Object b)
{
    Float_union bb;
    bb.i = b - TAG_SFLOAT;
    return !lesspdr((double)bb.f, a);
}

#define lesseqrb(a, b) lesseqri(a, b)

static CSLbool lesseqrr(Lisp_Object a, Lisp_Object b)
{
    Lisp_Object c;
    push2(a, b);
    c = times2(numerator(a), denominator(b));
    pop2(b, a);
    push(c);
    b = times2(numerator(b), denominator(a));
    pop(c);
    return lesseq2(c, b);
}

#define lesseqrf(a, b) (!lesspdr(float_of_number(b), a))

#endif

#define lesseqfi(a, b) (float_of_number(a) <= (double)int_of_fixnum(b))

#ifdef COMMON
static CSLbool lesseqfs(Lisp_Object a, Lisp_Object b)
{
    Float_union bb;
    bb.i = b - TAG_SFLOAT;
    return float_of_number(a) <= (double)bb.f;
}
#endif

#define lesseqfb(a, b) (!lesspbd(b, float_of_number(a)))

#define lesseqfr(a, b) (!lessprd(b, float_of_number(a)))

#define lesseqff(a, b) (float_of_number(a) <= float_of_number(b))


CSLbool geq2(Lisp_Object a, Lisp_Object b)
{
    return lesseq2(b, a);
}

CSLbool lesseq2(Lisp_Object a, Lisp_Object b)
{
    Lisp_Object nil = C_nil;
    if (exception_pending()) return NO;
    switch ((int)a & TAG_BITS)
    {
case TAG_FIXNUM:
        switch ((int)b & TAG_BITS)
        {
    case TAG_FIXNUM:
/* For fixnums the comparison can be done directly */
            return ((int32)a <= (int32)b);
#ifdef COMMON
    case TAG_SFLOAT:
            return lesseqis(a, b);
#endif
    case TAG_NUMBERS:
            {   int32 hb = type_of_header(numhdr(b));
                switch (hb)
                {
        case TYPE_BIGNUM:
                return lesseqib(a, b);
#ifdef COMMON
        case TYPE_RATNUM:
                return lesseqir(a, b);
#endif
        default:
                return (CSLbool)aerror2("bad arg for leq", a, b);
                }
            }
    case TAG_BOXFLOAT:
            return lesseqif(a, b);
    default:
            return (CSLbool)aerror2("bad arg for leq", a, b);
        }
#ifdef COMMON
case TAG_SFLOAT:
        switch (b & TAG_BITS)
        {
    case TAG_FIXNUM:
            return lesseqsi(a, b);
    case TAG_SFLOAT:
            {   Float_union aa, bb;
                aa.i = a - TAG_SFLOAT;
                bb.i = b - TAG_SFLOAT;
                return (aa.f <= bb.f);
            }
    case TAG_NUMBERS:
            {   int32 hb = type_of_header(numhdr(b));
                switch (hb)
                {
        case TYPE_BIGNUM:
                return lesseqsb(a, b);
        case TYPE_RATNUM:
                return lesseqsr(a, b);
        default:
                return (CSLbool)aerror2("bad arg for leq", a, b);
                }
            }
    case TAG_BOXFLOAT:
            return lesseqsf(a, b);
    default:
            return (CSLbool)aerror2("bad arg for leq", a, b);
        }
#endif
case TAG_NUMBERS:
        {   int32 ha = type_of_header(numhdr(a));
            switch (ha)
            {
    case TYPE_BIGNUM:
                switch ((int)b & TAG_BITS)
                {
            case TAG_FIXNUM:
                    return lesseqbi(a, b);
#ifdef COMMON
            case TAG_SFLOAT:
                    return lesseqbs(a, b);
#endif
            case TAG_NUMBERS:
                    {   int32 hb = type_of_header(numhdr(b));
                        switch (hb)
                        {
                case TYPE_BIGNUM:
                        return lesseqbb(a, b);
#ifdef COMMON
                case TYPE_RATNUM:
                        return lesseqbr(a, b);
#endif
                default:
                        return (CSLbool)aerror2("bad arg for leq", a, b);
                        }
                    }
            case TAG_BOXFLOAT:
                    return lesseqbf(a, b);
            default:
                    return (CSLbool)aerror2("bad arg for leq", a, b);
                }
#ifdef COMMON
    case TYPE_RATNUM:
                switch (b & TAG_BITS)
                {
            case TAG_FIXNUM:
                    return lesseqri(a, b);
            case TAG_SFLOAT:
                    return lesseqrs(a, b);
            case TAG_NUMBERS:
                    {   int32 hb = type_of_header(numhdr(b));
                        switch (hb)
                        {
                case TYPE_BIGNUM:
                        return lesseqrb(a, b);
                case TYPE_RATNUM:
                        return lesseqrr(a, b);
                default:
                        return (CSLbool)aerror2("bad arg for leq", a, b);
                        }
                    }
            case TAG_BOXFLOAT:
                    return lesseqrf(a, b);
            default:
                    return (CSLbool)aerror2("bad arg for leq", a, b);
                }
#endif
    default:    return (CSLbool)aerror2("bad arg for leq", a, b);
            }
        }
case TAG_BOXFLOAT:
        switch ((int)b & TAG_BITS)
        {
    case TAG_FIXNUM:
            return lesseqfi(a, b);
#ifdef COMMON
    case TAG_SFLOAT:
            return lesseqfs(a, b);
#endif
    case TAG_NUMBERS:
            {   int32 hb = type_of_header(numhdr(b));
                switch (hb)
                {
        case TYPE_BIGNUM:
                return lesseqfb(a, b);
#ifdef COMMON
        case TYPE_RATNUM:
                return lesseqfr(a, b);
#endif
        default:
                return (CSLbool)aerror2("bad arg for leq", a, b);
                }
            }
    case TAG_BOXFLOAT:
            return lesseqff(a, b);
    default:
            return (CSLbool)aerror2("bad arg for leq", a, b);
        }
default:
        return (CSLbool)aerror2("bad arg for leq", a, b);
    }
}


void print_bignum(Lisp_Object u, CSLbool blankp, int nobreak)
{
    int32 len = length_of_header(numhdr(u))-CELL;
    int32 i, len1;
    Lisp_Object w, nil = C_nil;
    char my_buff[24];    /* Big enough for 2-word bignum value */
    int line_length = other_write_action(WRITE_GET_INFO+WRITE_GET_LINE_LENGTH,
                                         active_stream);
    int column =
        other_write_action(WRITE_GET_INFO+WRITE_GET_COLUMN, active_stream);
#ifdef NEED_TO_CHECK_BIGNUM_FORMAT
/* The next few lines are to help me track down bugs... */
    {   int32 d1 = bignum_digits(u)[(len-4)/4];
        if (len == 4)
        {   int32 m = d1 & fix_mask;
            if (m == 0 || m == fix_mask)
                myprintf("[%.8lx should be fixnum]", (long)d1);
            if (signed_overflow(d1))
                myprintf("[%.8lx needs 2 words]", (long)d1);
        }
        else
        {   int32 d0 = bignum_digits(u)[(len-8)/4];
            if (signed_overflow(d1)) myprintf("[needs more words]");
            else if (d1 == 0 && (d0 & 0x40000000) == 0) myprintf("[shrink]");
            else if (d1 == -1 &&(d0 & 0x40000000) != 0) myprintf("[shrink]");
        }
    }
/* end of temp code */
#endif
    switch (len)
    {
case 4:         /* one word bignum - especially easy! */
        {   int32 dig0 = bignum_digits(u)[0];
            unsigned32 dig = dig0;
            int i = 0;
            if (dig0 < 0) dig = -dig0;
/*
 * I do all my conversion from binary to decimal by hand in this code,
 * where once I used sprintf - but sprintf is somewhat more powerful
 * than I need, and thus I expect it to be somewhat more costly.
 */
            do
            {   int32 nxt = dig % 10;
                dig = dig / 10;
                my_buff[i++] = (int)nxt + '0';
            } while (dig != 0);
            if (dig0 < 0) my_buff[i++] = '-';
            if (blankp)
            {   if (nobreak==0 && column+i >= line_length)
                {   if (column != 0) putc_stream('\n', active_stream);
                }
                else putc_stream(' ', active_stream);
            }
            else if (nobreak==0 && column != 0 && column+i > line_length)
                putc_stream('\n', active_stream);
            while (--i >= 0) putc_stream(my_buff[i], active_stream);
        }
        return;
case 8:        /* two word bignum */
        {   unsigned32 d0 = bignum_digits(u)[0], d1 = bignum_digits(u)[1];
            unsigned32 d0high, d0low, w;
            unsigned32 p0, p1, p2;
            CSLbool negativep = NO;
            int i, j;
            if (((int32)d1) < 0)
            {   negativep = YES;
                d0 = clear_top_bit(-(int32)d0);
                if (d0 == 0) d1 = -(int32)d1;
                else d1 = ~d1;
            }
            d0high = ((unsigned32)d0)>>16;
            d0low = d0 - (d0high << 16);
/* Adjust for the fact that I packed just 31 bits into each word.. */
            if ((d1 & 1) != 0) d0high |= 0x8000U;
            w = d1 >> 1;
/* d1 is at most 0x40000000 here, so no problem wrt sign */
            d1 = w / 10000;
            w = d0high + ((w % 10000) << 16);
            d0high = w / 10000;
            w = d0low + ((w % 10000) << 16);
            d0low = w / 10000;
            p0 = w % 10000;        /* last 4 digits of value */

            w = d1;
            d1 = w / 10000;
            w = d0high + ((w % 10000) << 16);
            d0high = w / 10000;
            w = d0low + ((w % 10000) << 16);
            d0low = w / 10000;
            p1 = w % 10000;        /* 4 more digits of value */

/* By now d1 is certainly less then 10000 */
            w = d0high + (d1 << 16);
            d0high = w / 10000;
            w = d0low + ((w % 10000) << 16);
            d0 = (w / 10000) + (d0high << 16);
            p2 = w % 10000;
            i = 0;
            for (j=0; j<4; j++)
                my_buff[i++] = (int)(p0 % 10) + '0', p0 = p0/10;
            for (j=0; j<4; j++)
                my_buff[i++] = (int)(p1 % 10) + '0', p1 = p1/10;
/*
 * Because the value used 2 words it must have more than 8 digits in it,
 * but it may not have more than 12.  Therefore I am not certain whether
 * all 4 digits of p2 are needed.
 */
            if (d0 == 0)
            {   while (p2 != 0)
                    my_buff[i++] = (int)(p2 % 10) + '0', p2 = p2/10;
            }
            else
            {   for (j=0; j<4; j++)
                    my_buff[i++] = (int)(p2 % 10) + '0', p2 = p2/10;
                while (d0 != 0)
                    my_buff[i++] = (int)(d0 % 10) + '0', d0 = d0/10;
            }
            if (negativep) my_buff[i++] = '-';
            if (blankp)
            {   if (nobreak==0 && column+i >= line_length)
                {    if (column != 0) putc_stream('\n', active_stream);
                }
                else putc_stream(' ', active_stream);
            }
            else if (nobreak==0 && column != 0 && column+i > line_length)
                putc_stream('\n', active_stream);
            while (--i >= 0) putc_stream(my_buff[i], active_stream);
            return;
        }
default:
        break;  /* general big case */
    }
    push(u);
    len1 = CELL+4+(11*len)/10;
/*
 * To print a general big number I will convert it from radix 2^31 to
 * radix 10^9.  This can involve increasing the number of digits by a factor
 * of about 1.037, so the 10% expansion I allow for in len1 above should
 * keep me safe.
 */
    len1 = (intxx)doubleword_align_up(len1);
    w = getvector(TAG_NUMBERS, TYPE_BIGNUM, len1);
    pop(u);
    nil = C_nil;
    if (!exception_pending())
    {   CSLbool sign = NO;
        int32 len2;
        len = len/4;
        len1 = (len1-CELL)/4;
        if (((int32)bignum_digits(u)[len-1]) >= 0)
            for (i=0; i<len; i++) bignum_digits(w)[i] = bignum_digits(u)[i];
        else
        {   int32 carry = -1;
            sign = YES;
            for (i=0; i<len; i++)
            /* negate the number so I am working with a +ve value */
            {   carry = clear_top_bit(~bignum_digits(u)[i]) + top_bit(carry);
                bignum_digits(w)[i] = clear_top_bit(carry);
            }
        }
        len2 = len1;
        while (len > 1)
        {   int32 k;
            int32 carry = 0;
/*
 * This stack-check is so that I can respond to interrupts
 */
            if (stack >= stacklimit)
            {   w = reclaim(w, "stack", GC_STACK, 0);
                errexitv();
            }
            /* divide by 10^9 to obtain remainder */
            for (k=len-1; k>=0; k--)
                Ddiv10_9(carry, bignum_digits(w)[k],
                                carry, bignum_digits(w)[k]);
            if (bignum_digits(w)[len-1] == 0) len--;
            bignum_digits(w)[--len2] = carry; /* 9 digits in decimal format */
        }
        push(w);
        {   unsigned32 dig;
            int i;
            int32 len;
            if (bignum_digits(w)[0] == 0) dig = bignum_digits(w)[len2++];
            else dig = bignum_digits(w)[0];
            i = 0;
            do
            {   int32 nxt = dig % 10;
                dig = dig / 10;
                my_buff[i++] = (int)nxt + '0';
            } while (dig != 0);
            if (sign) my_buff[i++] = '-';
            len = i + 9*(len1-len2);
            if (blankp)
            {   if (nobreak==0 && column+len >= line_length)
                {    if (column != 0) putc_stream('\n', active_stream);
                }
                else putc_stream(' ', active_stream);
            }
            else if (nobreak==0 && column != 0 && column+len > line_length)
                putc_stream('\n', active_stream);
            while (--i >= 0) putc_stream(my_buff[i], active_stream);
        }
        pop(w);
        while (len2 < len1)
        {   unsigned32 dig = bignum_digits(w)[len2++];
            int i;
            push(w);
            for (i=8; i>=0; i--)
            {   int32 nxt = dig % 10;
                dig = dig / 10;
                my_buff[i] = (int)nxt + '0';
            }
            for (i=0; i<=8; i++) putc_stream(my_buff[i], active_stream);
            pop(w);
            errexitv();
            if (stack >= stacklimit)
            {   w = reclaim(w, "stack", GC_STACK, 0);
                errexitv();
            }
        }
    }
}

void print_bighexoctbin(Lisp_Object u, int radix, int width,
                        CSLbool blankp, int nobreak)
/*
 * This prints a bignum in base 16, 8 or 2.  The main misery about this is
 * that internally bignums are stored in chunks of 31 bits, so I have
 * to collect digits for printing in a way that can span across word
 * boundaries.  There is also potential fun with regard to the display
 * of negative values - here I will print a "~" mark in front but will
 * then show them revealing the 2s complement representation used.
 * The width specifier is intended to specify a minimum width to be
 * used in the sense that printf uses the word "precision", so numbers
 * will be padded with leading zeros (of f/7/1 if negative) if necessary.
 * Well actually I have not implemented support for width specification
 * yet. It will be wanted so that (prinhex 1 8) comes out as 00000001,
 * for instance.
 */
{
    int32 n = (bignum_length(u)-CELL-4)/4;
    unsigned32 a=0, b=0;
    int32 len = 31*(n+1);
    int flag = 0, bits;
    CSLbool sign = NO, started = NO;
    nil_as_base
    int line_length = other_write_action(WRITE_GET_INFO+WRITE_GET_LINE_LENGTH,
                                         active_stream);
    int column =
        other_write_action(WRITE_GET_INFO+WRITE_GET_COLUMN, active_stream);
    if (radix == 16)
    {   bits = len % 4;
        len = len / 4;
        if (bits != 0) len++, bits = 4 - bits;
    }
    else if (radix == 8)
    {   bits = len % 3;
        len = len / 3;
        if (bits != 0) len++, bits = 3 - bits;
    }
    else
    {   bits = 0;
    }
/*
 * As I work down the bignum, b holds the next chunk of digits to be printed,
 * and bits tells me how many valid bits are present in it.  I start off
 * with bits non-zero to (in effect) adjoin a few bits from an implicit
 * extra leading digit so as to make up to an integral multiple of 3 or 4
 * bits in all when I am printing base 8 or 16.  The variable (len) now tells
 * me how many digits remain to be printed.
 */
    push(u);
    if ((int32)bignum_digits(u)[n] < 0)
    {   sign = YES;
        len+=2;    /* Allow extra length for sign marker and initial f/7/1 */
        if (radix == 16) flag = 0xf;
        else if (radix == 8) flag = 0x7;
        else flag = 0x1;
/*
 * Set the buffer b to have a few '1' bits at its top.
 */
        if (bits != 0) b = ((int32)-1) << (32-bits);
    }
/*
 * I kill leading zeros - and since this is a real bignum there MUST be
 * at least one nonzero digit somewhere, so I do not have to worry about the
 * total supression of the value 0.  I will do something with leading 'f' or
 * '7' digits for negative numbers.
 */
    while (n >= 0 || bits > 0)
    {   if (radix == 16)
        {   a = (b >> 28);    /* Grab the next 4 bits of the number      */
            b = b << 4;       /* shift buffer to position the next four  */
            bits -= 4;
        }
        else if (radix == 8)
        {   a = (b >> 29);    /* 3 bits */
            b = b << 3;
            bits -= 3;
        }
        else
        {   a = (b >> 31);    /* just 1 bit */
            b = b << 1;
            bits -= 1;
        }
        if (bits < 0)     /* there had not been enough buffered bits */
        {   u = stack[0];
            b = bignum_digits(u)[n] << 1;
            n--;
            a |= b >> (32+bits);
            b = b << (-bits);
            bits += 31;
        }
        if ((int)a != flag)  /* leading '0' or 'f' (or '7') supression code */
        {
            if (!started)
            {
                if (blankp)
                {   if (nobreak==0 && column+len >= line_length)
                    {   if (column != 0) putc_stream('\n', active_stream);
                    }
                    else putc_stream(' ', active_stream);
                }
                else if (nobreak==0 && column != 0 && column+len > line_length)
                    putc_stream('\n', active_stream);
                if (sign) putc_stream('~', active_stream);
                started = YES;
                if (flag > 0) putc_stream(radix == 16 ? 'f' :
                                 radix == 8  ? '7' : '1', active_stream);
                flag = -1;
            }
        }
        len--;
        if (flag >= 0) continue;        /* lose leading zeros (or F digits) */
        if (a < 10) a += '0';
        else a += ('a' - 10);
        putc_stream((int)a, active_stream);
    }
    popv(1);
}

/* end of arith05.c */
