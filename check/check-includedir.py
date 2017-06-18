#!/usr/bin/env python

import sys
from pkgchecker import PkgChecker

tests = [(0, '-I/usr/include/somedir', '', {}, ['--cflags', 'includedir']),
]

if __name__ == '__main__':
    checker = PkgChecker(__file__, sys.argv)
    sys.exit(checker.check(tests))
