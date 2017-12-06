/*
 * This code is taken from the RPM package manager.
 *
 * RPM is Copyright (c) 1998 by Red Hat Software, Inc.,
 * and may be distributed under the terms of the GPL and LGPL.
 * See http://rpm.org/gitweb?p=rpm.git;a=blob_plain;f=COPYING;hb=HEAD
 *
 * The code should follow upstream as closely as possible.
 * See http://rpm.org/gitweb?p=rpm.git;a=blob_plain;f=lib/rpmvercmp.c;hb=HEAD
 *
 * Currently the only difference as a policy is that upstream uses C99
 * features and pkg-config does not require a C99 compiler yet.
 */

module rpmvercomp;

import std.string;
import core.stdc.ctype;
import core.stdc.string;

/* compare alpha and numeric segments of two versions */
/* return 1: a is newer than b */
/*        0: a and b are the same version */
/*       -1: b is newer than a */
int rpmvercmp(const ref string a, const ref string b) {
    int str1, str2;
    int one=0, two=0;
    int rc;
    int isnum;

    /* easy comparison to see if versions are identical */
    if(a == b)
        return 0;

    /* loop through each version segment of str1 and str2 and compare them */
    while(one<a.length && two<b.length) {
        while(one<a.length && !isalnum(a[one]))
            one++;
        while(two<b.length && !isalnum(b[two]))
            two++;

        /* If we ran to the end of either, we are finished with the loop */
        if(!(one<a.length && two<b.length))
            break;

        str1 = one;
        str2 = two;

        /* grab first completely alpha or completely numeric segment */
        /* leave one and two pointing to the start of the alpha or numeric */
        /* segment and walk str1 and str2 to end of segment */
        if(isdigit(a[str1])) {
            while(str1<a.length && isdigit(a[str1]))
                str1++;
            while(str2<b.length && isdigit(b[str2]))
                str2++;
            isnum = 1;
        } else {
            while(str1<a.length && isalpha(a[str1]))
                str1++;
            while(str2<b.length && isalpha(b[str2]))
                str2++;
            isnum = 0;
        }

        /* this cannot happen, as we previously tested to make sure that */
        /* the first string has a non-null segment */
        if(one == str1)
            return -1; /* arbitrary */

        /* take care of the case where the two version segments are */
        /* different types: one numeric, the other alpha (i.e. empty) */
        /* numeric segments are always newer than alpha segments */
        /* XXX See patch #60884 (and details) from bugzilla #50977. */
        if(two == str2)
            return (isnum ? 1 : -1);

        string dig1, dig2;
        if(isnum) {
            /* this used to be done by converting the digit segments */
            /* to ints using atoi() - it's changed because long  */
            /* digit segments can overflow an int - this should fix that. */

            /* throw away any leading zeros - it's a number, right? */
            while(a[one] == '0')
                one++;
            while(b[two] == '0')
                two++;

            dig1 = a[one .. str1];
            dig2 = b[two .. str2];
            /* whichever number has more digits wins */
            if(dig1.length > dig2.length)
                return 1;
            if(dig2.length > dig1.length)
                return -1;
        }

        /* strcmp will return which one is greater - even if the two */
        /* segments are alpha or if they are numeric.  don't return  */
        /* if they are equal because there might be more segments to */
        /* compare */
        rc = strcmp(toStringz(dig1), toStringz(dig2));
        if(rc)
            return (rc < 1 ? -1 : 1);
        /* restore character that was replaced by null above */
        one = str1;
        two = str2;

    }

    /* this catches the case where all numeric and alpha segments have */
    /* compared identically but the segment sepparating characters were */
    /* different */
    if((one>=a.length) && (two>=b.length))
        return 0;

    /* whichever version still has characters left over wins */
    if(one>=a.length)
        return -1;
    else
        return 1;
}
