#!/usr/bin/env python

import sys
from pkgchecker import PkgChecker

tests = [(0, '-g -ffoo -I/foo -isystem /system1 -idirafter /after1 -I/bar -idirafter /after2 -isystem /system2', '', {}, ['--cflags', 'special-flags']),
         (0, '-L/foo -L/bar -framework Foo -lsimple -framework Bar -Wl,-framework -Wl,Baz', '', {}, ['--libs', 'special-flags']),
         ]

if __name__ == '__main__':
    checker = PkgChecker(__file__, sys.argv)
    sys.exit(checker.check(tests))
