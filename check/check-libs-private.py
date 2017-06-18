#/usr/bin/env python

import sys
from pkgchecker import PkgChecker

tests = [(0, '-lsimple -lm', '', {}, ['--static', '--libs', 'simple']),
]

if __name__ == '__main__':
    checker = PkgChecker(__file__, sys.argv)
    sys.exit(checker.check(tests))
