#!/usr/bin/env python

import sys
from pkgchecker import PkgChecker

tests = [
# expect unescaped tilde from cflags
    (0, '-I~', '', {}, ['--cflags', 'tilde']),

# expect unescaped tilde from libs
    (0, '-L~', '', {}, ['--libs', 'tilde']),
]

if __name__ == '__main__':
    checker = PkgChecker(__file__, sys.argv)
    sys.exit(checker.check(tests))
