#!/usr/bin/env python

import sys
from pkgchecker import PkgChecker

tests = [(0, '-lcirc1 -lcirc2 -lcirc3', '', {}, ['--libs', 'circular-1']),
]

if __name__ == '__main__':
    checker = PkgChecker(__file__, sys.argv)
    sys.exit(checker.check(tests))
