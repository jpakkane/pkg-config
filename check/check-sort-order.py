#!/usr/bin/env python

# These tests check that the order of the flags in .pc files are correct
# after resolving the package list. There are two things that are
# critical in the current algorithm: the ordering of packages on the
# command line, the ordering of packages based on Requires and the place
# in the pkg-config path the .pc file was found, with packages earlier
# in the path getting higher priority. There is one other factor that
# makes the output currently work correctly that's only implicitly
# tested here: stripping of all duplicates from the output string.
#
# There are 3 sets of packages here:
#
# 1. A typical setup where highest level package is earliest in the path
# and has a straight dependency chain. 3-1 -> 2-1 -> 1-1 with 3-1 in the
# first part of the user supplied path, 2-1 in the second part, and 1-1
# found from the system path.
#
# 2. A similar setup to 1 except that now both 3-2 and 2-2 depend on
# 1-2. This has a subtle effect on the algorithm when combined with the
# order of the command line arguments. It only currently works because
# duplicates get strip out in (hopefully) the correct order, so 1-2's
# flags come out in the appropriate spot even though it was in the
# package list twice.
#
# 3. Reverse the order of requirements so that the system level package
# (1-3) depends on something in the user's path (2-3), which depends on
# something earlier in the user's path (3-3). This is pretty unusual
# since the user is typically overriding something higher in the stack
# rather than lower, but it does illustrate the path ordering vs.
# dependency ordering.

import sys
from pkgchecker import PkgChecker

# [ "$native_win32" = yes ] && sep=';' || sep=':'
sep = ':'
order1 = {'PKG_CONFIG_PATH': '${srcdir}/sort/sort%s${srcdir}/sort' % sep}
order2 = {'PKG_CONFIG_PATH': '${srcdir}/sort%s${srcdir}/sort/sort' % sep}

PKG_CONFIG_PATH="$order1"

tests = [
# Check package set -1
    (0, '-DPATH3 -DPATH2 -DPATH1 -I/path3/include -I/path2/include -I/path1/include', '', order1, ['--cflags', 'sort-order-3-1']),
    (0, '-DPATH3 -DPATH2 -DPATH1 -I/path3/include -I/path2/include -I/path1/include', '', order1, ['--cflags', 'sort-order-3-1', 'sort-order-2-1']),
    (0, '-DPATH3 -DPATH2 -DPATH1 -I/path3/include -I/path2/include -I/path1/include', '', order1, ['--cflags', 'sort-order-2-1', 'sort-order-3-1']),
    (0, '-DPATH3 -DPATH2 -DPATH1 -I/path3/include -I/path2/include -I/path1/include', '', order1, ['--cflags', 'sort-order-3-1', 'sort-order-2-1', 'sort-order-1-1']),
    (0, '-DPATH3 -DPATH2 -DPATH1 -I/path3/include -I/path2/include -I/path1/include', '', order1, ['--cflags', 'sort-order-3-1', 'sort-order-1-1', 'sort-order-2-1']),
    (0, '-DPATH3 -DPATH2 -DPATH1 -I/path3/include -I/path2/include -I/path1/include', '', order1, ['--cflags', 'sort-order-2-1', 'sort-order-3-1', 'sort-order-1-1']),
    (0, '-DPATH3 -DPATH2 -DPATH1 -I/path3/include -I/path2/include -I/path1/include', '', order1, ['--cflags', 'sort-order-2-1', 'sort-order-1-1', 'sort-order-3-1']),
    (0, '-DPATH3 -DPATH2 -DPATH1 -I/path3/include -I/path2/include -I/path1/include', '', order1, ['--cflags', 'sort-order-1-1', 'sort-order-3-1', 'sort-order-2-1']),
    (0, '-DPATH3 -DPATH2 -DPATH1 -I/path3/include -I/path2/include -I/path1/include', '', order1, ['--cflags', 'sort-order-1-1', 'sort-order-2-1', 'sort-order-3-1']),

    (0, '-L/path3/lib -L/path2/lib -L/path1/lib -Wl,-O3 -lpath3 -Wl,-O2 -lpath2 -Wl,-O1 -lpath1', '', order1, ['--libs', 'sort-order-3-1']),
    (0, '-L/path3/lib -L/path2/lib -L/path1/lib -Wl,-O3 -lpath3 -Wl,-O2 -lpath2 -Wl,-O1 -lpath1', '', order1, ['--libs', 'sort-order-3-1', 'sort-order-2-1']),
    (0, '-L/path3/lib -L/path2/lib -L/path1/lib -Wl,-O3 -lpath3 -Wl,-O2 -lpath2 -Wl,-O1 -lpath1', '', order1, ['--libs', 'sort-order-2-1', 'sort-order-3-1']),
    (0, '-L/path3/lib -L/path2/lib -L/path1/lib -Wl,-O3 -lpath3 -Wl,-O2 -lpath2 -Wl,-O1 -lpath1', '', order1, ['--libs', 'sort-order-3-1', 'sort-order-2-1', 'sort-order-1-1']),
    (0, '-L/path3/lib -L/path2/lib -L/path1/lib -Wl,-O3 -lpath3 -Wl,-O2 -lpath2 -Wl,-O1 -lpath1', '', order1, ['--libs', 'sort-order-3-1', 'sort-order-1-1', 'sort-order-2-1']),
    (0, '-L/path3/lib -L/path2/lib -L/path1/lib -Wl,-O3 -lpath3 -Wl,-O2 -lpath2 -Wl,-O1 -lpath1', '', order1, ['--libs', 'sort-order-2-1', 'sort-order-3-1', 'sort-order-1-1']),
    (0, '-L/path3/lib -L/path2/lib -L/path1/lib -Wl,-O3 -lpath3 -Wl,-O2 -lpath2 -Wl,-O1 -lpath1', '', order1, ['--libs', 'sort-order-2-1', 'sort-order-1-1', 'sort-order-3-1']),
    (0, '-L/path3/lib -L/path2/lib -L/path1/lib -Wl,-O3 -lpath3 -Wl,-O2 -lpath2 -Wl,-O1 -lpath1', '', order1, ['--libs', 'sort-order-1-1', 'sort-order-3-1', 'sort-order-2-1']),
    (0, '-L/path3/lib -L/path2/lib -L/path1/lib -Wl,-O3 -lpath3 -Wl,-O2 -lpath2 -Wl,-O1 -lpath1', '', order1, ['--libs', 'sort-order-1-1', 'sort-order-2-1', 'sort-order-3-1']),

# Check package set -2
    (0, '-DPATH3 -DPATH2 -DPATH1 -I/path3/include -I/path2/include -I/path1/include', '', order1, ['--cflags', 'sort-order-3-2']),
    (0, '-DPATH3 -DPATH2 -DPATH1 -I/path3/include -I/path2/include -I/path1/include', '', order1, ['--cflags', 'sort-order-3-2', 'sort-order-2-2']),
    (0, '-DPATH3 -DPATH2 -DPATH1 -I/path3/include -I/path2/include -I/path1/include', '', order1, ['--cflags', 'sort-order-2-2', 'sort-order-3-2']),
    (0, '-DPATH3 -DPATH2 -DPATH1 -I/path3/include -I/path2/include -I/path1/include', '', order1, ['--cflags', 'sort-order-3-2', 'sort-order-2-2', 'sort-order-1-2']),
    (0, '-DPATH3 -DPATH2 -DPATH1 -I/path3/include -I/path2/include -I/path1/include', '', order1, ['--cflags', 'sort-order-3-2', 'sort-order-1-2', 'sort-order-2-2']),
    (0, '-DPATH3 -DPATH2 -DPATH1 -I/path3/include -I/path2/include -I/path1/include', '', order1, ['--cflags', 'sort-order-2-2', 'sort-order-3-2', 'sort-order-1-2']),
    (0, '-DPATH3 -DPATH2 -DPATH1 -I/path3/include -I/path2/include -I/path1/include', '', order1, ['--cflags', 'sort-order-2-2', 'sort-order-1-2', 'sort-order-3-2']),
    (0, '-DPATH3 -DPATH2 -DPATH1 -I/path3/include -I/path2/include -I/path1/include', '', order1, ['--cflags', 'sort-order-1-2', 'sort-order-3-2', 'sort-order-2-2']),
    (0, '-DPATH3 -DPATH2 -DPATH1 -I/path3/include -I/path2/include -I/path1/include', '', order1, ['--cflags', 'sort-order-1-2', 'sort-order-2-2', 'sort-order-3-2']),

    (0, '-L/path3/lib -L/path2/lib -L/path1/lib -Wl,-O3 -lpath3 -Wl,-O2 -lpath2 -Wl,-O1 -lpath1', '', order1, ['--libs', 'sort-order-3-2']),
    (0, '-L/path3/lib -L/path2/lib -L/path1/lib -Wl,-O3 -lpath3 -Wl,-O2 -lpath2 -Wl,-O1 -lpath1', '', order1, ['--libs', 'sort-order-3-2', 'sort-order-2-2']),
    (0, '-L/path3/lib -L/path2/lib -L/path1/lib -Wl,-O3 -lpath3 -Wl,-O2 -lpath2 -Wl,-O1 -lpath1', '', order1, ['--libs', 'sort-order-2-2', 'sort-order-3-2']),
    (0, '-L/path3/lib -L/path2/lib -L/path1/lib -Wl,-O3 -lpath3 -Wl,-O2 -lpath2 -Wl,-O1 -lpath1', '', order1, ['--libs', 'sort-order-3-2', 'sort-order-2-2', 'sort-order-1-2']),
    (0, '-L/path3/lib -L/path2/lib -L/path1/lib -Wl,-O3 -lpath3 -Wl,-O2 -lpath2 -Wl,-O1 -lpath1', '', order1, ['--libs', 'sort-order-3-2', 'sort-order-1-2', 'sort-order-2-2']),
    (0, '-L/path3/lib -L/path2/lib -L/path1/lib -Wl,-O3 -lpath3 -Wl,-O2 -lpath2 -Wl,-O1 -lpath1', '', order1, ['--libs', 'sort-order-2-2', 'sort-order-3-2', 'sort-order-1-2']),
    (0, '-L/path3/lib -L/path2/lib -L/path1/lib -Wl,-O3 -lpath3 -Wl,-O2 -lpath2 -Wl,-O1 -lpath1', '', order1, ['--libs', 'sort-order-2-2', 'sort-order-1-2', 'sort-order-3-2']),
    (0, '-L/path3/lib -L/path2/lib -L/path1/lib -Wl,-O3 -lpath3 -Wl,-O2 -lpath2 -Wl,-O1 -lpath1', '', order1, ['--libs', 'sort-order-1-2', 'sort-order-3-2', 'sort-order-2-2']),
    (0, '-L/path3/lib -L/path2/lib -L/path1/lib -Wl,-O3 -lpath3 -Wl,-O2 -lpath2 -Wl,-O1 -lpath1', '', order1, ['--libs', 'sort-order-1-2', 'sort-order-2-2', 'sort-order-3-2']),

# Check package set -3
    (0, "-DPATH1 -DPATH2 -DPATH3 -I/path3/include -I/path2/include -I/path1/include", '', order1, ['--cflags', 'sort-order-1-3']),
    (0, "-DPATH1 -DPATH2 -DPATH3 -I/path3/include -I/path2/include -I/path1/include", '', order1, ['--cflags', 'sort-order-1-3', 'sort-order-2-3']),
    (0, "-DPATH1 -DPATH2 -DPATH3 -I/path3/include -I/path2/include -I/path1/include", '', order1, ['--cflags', 'sort-order-2-3', 'sort-order-1-3']),
    (0, "-DPATH1 -DPATH2 -DPATH3 -I/path3/include -I/path2/include -I/path1/include", '', order1, ['--cflags', 'sort-order-3-3', 'sort-order-2-3', 'sort-order-1-3']),
    (0, "-DPATH1 -DPATH2 -DPATH3 -I/path3/include -I/path2/include -I/path1/include", '', order1, ['--cflags', 'sort-order-3-3', 'sort-order-1-3', 'sort-order-2-3']),
    (0, "-DPATH1 -DPATH2 -DPATH3 -I/path3/include -I/path2/include -I/path1/include", '', order1, ['--cflags', 'sort-order-2-3', 'sort-order-3-3', 'sort-order-1-3']),
    (0, "-DPATH1 -DPATH2 -DPATH3 -I/path3/include -I/path2/include -I/path1/include", '', order1, ['--cflags', 'sort-order-2-3', 'sort-order-1-3', 'sort-order-3-3']),
    (0, "-DPATH1 -DPATH2 -DPATH3 -I/path3/include -I/path2/include -I/path1/include", '', order1, ['--cflags', 'sort-order-1-3', 'sort-order-3-3', 'sort-order-2-3']),
    (0, "-DPATH1 -DPATH2 -DPATH3 -I/path3/include -I/path2/include -I/path1/include", '', order1, ['--cflags', 'sort-order-1-3', 'sort-order-2-3', 'sort-order-3-3']),

    (0, '-L/path3/lib -L/path2/lib -L/path1/lib -Wl,-O1 -lpath1 -Wl,-O2 -lpath2 -Wl,-O3 -lpath3', '', order1, ['--libs', 'sort-order-1-3']),
    (0, '-L/path3/lib -L/path2/lib -L/path1/lib -Wl,-O1 -lpath1 -Wl,-O2 -lpath2 -Wl,-O3 -lpath3', '', order1, ['--libs', 'sort-order-1-3', 'sort-order-2-3']),
    (0, '-L/path3/lib -L/path2/lib -L/path1/lib -Wl,-O1 -lpath1 -Wl,-O2 -lpath2 -Wl,-O3 -lpath3', '', order1, ['--libs', 'sort-order-2-3', 'sort-order-1-3']),
    (0, '-L/path3/lib -L/path2/lib -L/path1/lib -Wl,-O1 -lpath1 -Wl,-O2 -lpath2 -Wl,-O3 -lpath3', '', order1, ['--libs', 'sort-order-3-3', 'sort-order-2-3', 'sort-order-1-3']),
    (0, '-L/path3/lib -L/path2/lib -L/path1/lib -Wl,-O1 -lpath1 -Wl,-O2 -lpath2 -Wl,-O3 -lpath3', '', order1, ['--libs', 'sort-order-3-3', 'sort-order-1-3', 'sort-order-2-3']),
    (0, '-L/path3/lib -L/path2/lib -L/path1/lib -Wl,-O1 -lpath1 -Wl,-O2 -lpath2 -Wl,-O3 -lpath3', '', order1, ['--libs', 'sort-order-2-3', 'sort-order-3-3', 'sort-order-1-3']),
    (0, '-L/path3/lib -L/path2/lib -L/path1/lib -Wl,-O1 -lpath1 -Wl,-O2 -lpath2 -Wl,-O3 -lpath3', '', order1, ['--libs', 'sort-order-2-3', 'sort-order-1-3', 'sort-order-3-3']),
    (0, '-L/path3/lib -L/path2/lib -L/path1/lib -Wl,-O1 -lpath1 -Wl,-O2 -lpath2 -Wl,-O3 -lpath3', '', order1, ['--libs', 'sort-order-1-3', 'sort-order-3-3', 'sort-order-2-3']),
    (0, '-L/path3/lib -L/path2/lib -L/path1/lib -Wl,-O1 -lpath1 -Wl,-O2 -lpath2 -Wl,-O3 -lpath3', '', order1, ['--libs', 'sort-order-1-3', 'sort-order-2-3', 'sort-order-3-3']),

# Switch pkg-config path order
# Check package set -1
    (0, '-DPATH3 -DPATH2 -DPATH1 -I/path2/include -I/path3/include -I/path1/include', '', order2, ['--cflags', 'sort-order-3-1']),
    (0, '-DPATH3 -DPATH2 -DPATH1 -I/path2/include -I/path3/include -I/path1/include', '', order2, ['--cflags', 'sort-order-3-1', 'sort-order-2-1']),
    (0, '-DPATH3 -DPATH2 -DPATH1 -I/path2/include -I/path3/include -I/path1/include', '', order2, ['--cflags', 'sort-order-2-1', 'sort-order-3-1']),
    (0, '-DPATH3 -DPATH2 -DPATH1 -I/path2/include -I/path3/include -I/path1/include', '', order2, ['--cflags', 'sort-order-3-1', 'sort-order-2-1', 'sort-order-1-1']),
    (0, '-DPATH3 -DPATH2 -DPATH1 -I/path2/include -I/path3/include -I/path1/include', '', order2, ['--cflags', 'sort-order-3-1', 'sort-order-1-1', 'sort-order-2-1']),
    (0, '-DPATH3 -DPATH2 -DPATH1 -I/path2/include -I/path3/include -I/path1/include', '', order2, ['--cflags', 'sort-order-2-1', 'sort-order-3-1', 'sort-order-1-1']),
    (0, '-DPATH3 -DPATH2 -DPATH1 -I/path2/include -I/path3/include -I/path1/include', '', order2, ['--cflags', 'sort-order-2-1', 'sort-order-1-1', 'sort-order-3-1']),
    (0, '-DPATH3 -DPATH2 -DPATH1 -I/path2/include -I/path3/include -I/path1/include', '', order2, ['--cflags', 'sort-order-1-1', 'sort-order-3-1', 'sort-order-2-1']),
    (0, '-DPATH3 -DPATH2 -DPATH1 -I/path2/include -I/path3/include -I/path1/include', '', order2, ['--cflags', 'sort-order-1-1', 'sort-order-2-1', 'sort-order-3-1']),

    (0, '-L/path2/lib -L/path3/lib -L/path1/lib -Wl,-O3 -lpath3 -Wl,-O2 -lpath2 -Wl,-O1 -lpath1', '', order2, ['--libs', 'sort-order-3-1']),
    (0, '-L/path2/lib -L/path3/lib -L/path1/lib -Wl,-O3 -lpath3 -Wl,-O2 -lpath2 -Wl,-O1 -lpath1', '', order2, ['--libs', 'sort-order-3-1', 'sort-order-2-1']),
    (0, '-L/path2/lib -L/path3/lib -L/path1/lib -Wl,-O3 -lpath3 -Wl,-O2 -lpath2 -Wl,-O1 -lpath1', '', order2, ['--libs', 'sort-order-2-1', 'sort-order-3-1']),
    (0, '-L/path2/lib -L/path3/lib -L/path1/lib -Wl,-O3 -lpath3 -Wl,-O2 -lpath2 -Wl,-O1 -lpath1', '', order2, ['--libs', 'sort-order-3-1', 'sort-order-2-1', 'sort-order-1-1']),
    (0, '-L/path2/lib -L/path3/lib -L/path1/lib -Wl,-O3 -lpath3 -Wl,-O2 -lpath2 -Wl,-O1 -lpath1', '', order2, ['--libs', 'sort-order-3-1', 'sort-order-1-1', 'sort-order-2-1']),
    (0, '-L/path2/lib -L/path3/lib -L/path1/lib -Wl,-O3 -lpath3 -Wl,-O2 -lpath2 -Wl,-O1 -lpath1', '', order2, ['--libs', 'sort-order-2-1', 'sort-order-3-1', 'sort-order-1-1']),
    (0, '-L/path2/lib -L/path3/lib -L/path1/lib -Wl,-O3 -lpath3 -Wl,-O2 -lpath2 -Wl,-O1 -lpath1', '', order2, ['--libs', 'sort-order-2-1', 'sort-order-1-1', 'sort-order-3-1']),
    (0, '-L/path2/lib -L/path3/lib -L/path1/lib -Wl,-O3 -lpath3 -Wl,-O2 -lpath2 -Wl,-O1 -lpath1', '', order2, ['--libs', 'sort-order-1-1', 'sort-order-3-1', 'sort-order-2-1']),
    (0, '-L/path2/lib -L/path3/lib -L/path1/lib -Wl,-O3 -lpath3 -Wl,-O2 -lpath2 -Wl,-O1 -lpath1', '', order2, ['--libs', 'sort-order-1-1', 'sort-order-2-1', 'sort-order-3-1']),

# Check package set -2
    (0, '-DPATH3 -DPATH2 -DPATH1 -I/path2/include -I/path3/include -I/path1/include', '', order2, ['--cflags', 'sort-order-3-2']),
    (0, '-DPATH3 -DPATH2 -DPATH1 -I/path2/include -I/path3/include -I/path1/include', '', order2, ['--cflags', 'sort-order-3-2', 'sort-order-2-2']),
    (0, '-DPATH3 -DPATH2 -DPATH1 -I/path2/include -I/path3/include -I/path1/include', '', order2, ['--cflags', 'sort-order-2-2', 'sort-order-3-2']),
    (0, '-DPATH3 -DPATH2 -DPATH1 -I/path2/include -I/path3/include -I/path1/include', '', order2, ['--cflags', 'sort-order-3-2', 'sort-order-2-2', 'sort-order-1-2']),
    (0, '-DPATH3 -DPATH2 -DPATH1 -I/path2/include -I/path3/include -I/path1/include', '', order2, ['--cflags', 'sort-order-3-2', 'sort-order-1-2', 'sort-order-2-2']),
    (0, '-DPATH3 -DPATH2 -DPATH1 -I/path2/include -I/path3/include -I/path1/include', '', order2, ['--cflags', 'sort-order-2-2', 'sort-order-3-2', 'sort-order-1-2']),
    (0, '-DPATH3 -DPATH2 -DPATH1 -I/path2/include -I/path3/include -I/path1/include', '', order2, ['--cflags', 'sort-order-2-2', 'sort-order-1-2', 'sort-order-3-2']),
    (0, '-DPATH3 -DPATH2 -DPATH1 -I/path2/include -I/path3/include -I/path1/include', '', order2, ['--cflags', 'sort-order-1-2', 'sort-order-3-2', 'sort-order-2-2']),
    (0, '-DPATH3 -DPATH2 -DPATH1 -I/path2/include -I/path3/include -I/path1/include', '', order2, ['--cflags', 'sort-order-1-2', 'sort-order-2-2', 'sort-order-3-2']),

    (0, '-L/path2/lib -L/path3/lib -L/path1/lib -Wl,-O3 -lpath3 -Wl,-O2 -lpath2 -Wl,-O1 -lpath1', '', order2, ['--libs', 'sort-order-3-2']),
    (0, '-L/path2/lib -L/path3/lib -L/path1/lib -Wl,-O3 -lpath3 -Wl,-O2 -lpath2 -Wl,-O1 -lpath1', '', order2, ['--libs', 'sort-order-3-2', 'sort-order-2-2']),
    (0, '-L/path2/lib -L/path3/lib -L/path1/lib -Wl,-O3 -lpath3 -Wl,-O2 -lpath2 -Wl,-O1 -lpath1', '', order2, ['--libs', 'sort-order-2-2', 'sort-order-3-2']),
    (0, '-L/path2/lib -L/path3/lib -L/path1/lib -Wl,-O3 -lpath3 -Wl,-O2 -lpath2 -Wl,-O1 -lpath1', '', order2, ['--libs', 'sort-order-3-2', 'sort-order-2-2', 'sort-order-1-2']),
    (0, '-L/path2/lib -L/path3/lib -L/path1/lib -Wl,-O3 -lpath3 -Wl,-O2 -lpath2 -Wl,-O1 -lpath1', '', order2, ['--libs', 'sort-order-3-2', 'sort-order-1-2', 'sort-order-2-2']),
    (0, '-L/path2/lib -L/path3/lib -L/path1/lib -Wl,-O3 -lpath3 -Wl,-O2 -lpath2 -Wl,-O1 -lpath1', '', order2, ['--libs', 'sort-order-2-2', 'sort-order-3-2', 'sort-order-1-2']),
    (0, '-L/path2/lib -L/path3/lib -L/path1/lib -Wl,-O3 -lpath3 -Wl,-O2 -lpath2 -Wl,-O1 -lpath1', '', order2, ['--libs', 'sort-order-2-2', 'sort-order-1-2', 'sort-order-3-2']),
    (0, '-L/path2/lib -L/path3/lib -L/path1/lib -Wl,-O3 -lpath3 -Wl,-O2 -lpath2 -Wl,-O1 -lpath1', '', order2, ['--libs', 'sort-order-1-2', 'sort-order-3-2', 'sort-order-2-2']),
    (0, '-L/path2/lib -L/path3/lib -L/path1/lib -Wl,-O3 -lpath3 -Wl,-O2 -lpath2 -Wl,-O1 -lpath1', '', order2, ['--libs', 'sort-order-1-2', 'sort-order-2-2', 'sort-order-3-2']),

# Check package set -3
    (0, '-DPATH1 -DPATH2 -DPATH3 -I/path2/include -I/path3/include -I/path1/include', '', order2, ['--cflags', 'sort-order-1-3']),
    (0, '-DPATH1 -DPATH2 -DPATH3 -I/path2/include -I/path3/include -I/path1/include', '', order2, ['--cflags', 'sort-order-1-3', 'sort-order-2-3']),
    (0, '-DPATH1 -DPATH2 -DPATH3 -I/path2/include -I/path3/include -I/path1/include', '', order2, ['--cflags', 'sort-order-2-3', 'sort-order-1-3']),
    (0, '-DPATH1 -DPATH2 -DPATH3 -I/path2/include -I/path3/include -I/path1/include', '', order2, ['--cflags', 'sort-order-3-3', 'sort-order-2-3', 'sort-order-1-3']),
    (0, '-DPATH1 -DPATH2 -DPATH3 -I/path2/include -I/path3/include -I/path1/include', '', order2, ['--cflags', 'sort-order-3-3', 'sort-order-1-3', 'sort-order-2-3']),
    (0, '-DPATH1 -DPATH2 -DPATH3 -I/path2/include -I/path3/include -I/path1/include', '', order2, ['--cflags', 'sort-order-2-3', 'sort-order-3-3', 'sort-order-1-3']),
    (0, '-DPATH1 -DPATH2 -DPATH3 -I/path2/include -I/path3/include -I/path1/include', '', order2, ['--cflags', 'sort-order-2-3', 'sort-order-1-3', 'sort-order-3-3']),
    (0, '-DPATH1 -DPATH2 -DPATH3 -I/path2/include -I/path3/include -I/path1/include', '', order2, ['--cflags', 'sort-order-1-3', 'sort-order-3-3', 'sort-order-2-3']),
    (0, '-DPATH1 -DPATH2 -DPATH3 -I/path2/include -I/path3/include -I/path1/include', '', order2, ['--cflags', 'sort-order-1-3', 'sort-order-2-3', 'sort-order-3-3']),

    (0, '-L/path2/lib -L/path3/lib -L/path1/lib -Wl,-O1 -lpath1 -Wl,-O2 -lpath2 -Wl,-O3 -lpath3', '', order2, ['--libs', 'sort-order-1-3']),
    (0, '-L/path2/lib -L/path3/lib -L/path1/lib -Wl,-O1 -lpath1 -Wl,-O2 -lpath2 -Wl,-O3 -lpath3', '', order2, ['--libs', 'sort-order-1-3', 'sort-order-2-3']),
    (0, '-L/path2/lib -L/path3/lib -L/path1/lib -Wl,-O1 -lpath1 -Wl,-O2 -lpath2 -Wl,-O3 -lpath3', '', order2, ['--libs', 'sort-order-2-3', 'sort-order-1-3']),
    (0, '-L/path2/lib -L/path3/lib -L/path1/lib -Wl,-O1 -lpath1 -Wl,-O2 -lpath2 -Wl,-O3 -lpath3', '', order2, ['--libs', 'sort-order-3-3', 'sort-order-2-3', 'sort-order-1-3']),
    (0, '-L/path2/lib -L/path3/lib -L/path1/lib -Wl,-O1 -lpath1 -Wl,-O2 -lpath2 -Wl,-O3 -lpath3', '', order2, ['--libs', 'sort-order-3-3', 'sort-order-1-3', 'sort-order-2-3']),
    (0, '-L/path2/lib -L/path3/lib -L/path1/lib -Wl,-O1 -lpath1 -Wl,-O2 -lpath2 -Wl,-O3 -lpath3', '', order2, ['--libs', 'sort-order-2-3', 'sort-order-3-3', 'sort-order-1-3']),
    (0, '-L/path2/lib -L/path3/lib -L/path1/lib -Wl,-O1 -lpath1 -Wl,-O2 -lpath2 -Wl,-O3 -lpath3', '', order2, ['--libs', 'sort-order-2-3', 'sort-order-1-3', 'sort-order-3-3']),
    (0, '-L/path2/lib -L/path3/lib -L/path1/lib -Wl,-O1 -lpath1 -Wl,-O2 -lpath2 -Wl,-O3 -lpath3', '', order2, ['--libs', 'sort-order-1-3', 'sort-order-3-3', 'sort-order-2-3']),
    (0, '-L/path2/lib -L/path3/lib -L/path1/lib -Wl,-O1 -lpath1 -Wl,-O2 -lpath2 -Wl,-O3 -lpath3', '', order2, ['--libs', 'sort-order-1-3', 'sort-order-2-3', 'sort-order-3-3']),
]

if __name__ == '__main__':
    checker = PkgChecker(__file__, sys.argv)
    sys.exit(checker.check(tests))

