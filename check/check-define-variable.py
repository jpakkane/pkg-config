#!/usr/bin/env python

import sys
from pkgchecker import PkgChecker

tests = [(0, '-I/includedir/', '', {}, ['--define-variable=includedir=/includedir/', '--cflags', 'simple']),
         (0, 'bar', '', {}, ['--define-variable=  foo  =  bar ',  '--variable=foo', 'simple']),
         (1, '', '--define-variable argument does not have a value for the variable', {}, ['--define-variable=foo=', '--variable=foo', 'simple']),
         ]

if __name__ == '__main__':
    checker = PkgChecker(__file__, sys.argv)
    sys.exit(checker.check(tests))

