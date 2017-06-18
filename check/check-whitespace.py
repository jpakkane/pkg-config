#!/usr/bin/env python

import sys
from pkgchecker import PkgChecker

tests = [
# variables come out unquoted. In 0.28 and earlier, this would also
# contain the ""s quoting the variable.
    (0, '/usr/white space/include', '', {}, ['--variable=includedir', 'whitespace']),

# expect cflags from whitespace
    (0, '-Dlala=misc -I/usr/white\ space/include -I$(top_builddir) -Iinclude\ dir -Iother\ include\ dir', '', {}, ['--cflags', 'whitespace']),

# expect libs from whitespace
    (0, "-L/usr/white\\ space/lib -lfoo\\ bar -lbar\\ baz -r:foo", '', {}, ['--libs', 'whitespace']),
]

if __name__ == '__main__':
    checker = PkgChecker(__file__, sys.argv)
    sys.exit(checker.check(tests))
