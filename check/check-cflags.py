#!/usr/bin/env python

import sys
from pkgchecker import PkgChecker

tests = [(0, '', '', {}, ['--cflags', 'simple']),
         (0, '', '', {}, ['--cflags', 'fields-blank']),
         (0, '-DOTHER -I/other/include', '', {}, ['--cflags', 'other']),
         (0, '-I/other/include', '', {}, ['--cflags-only-I', 'other']),
         (0, '-DOTHER', '', {}, ['--cflags-only-other', 'other']),
         #0,  Try various mixed combination
         (0, '-DOTHER -I/other/include', '', {}, ['--cflags-only-I', '--cflags-only-other', 'other']),
         (0, '-DOTHER -I/other/include', '', {}, ['--cflags-only-other', '--cflags-only-I', 'other']),
         (0, '-DOTHER -I/other/include', '', {}, ['--cflags', '--cflags-only-I', '--cflags-only-other', 'other']),
         (0, '-DOTHER -I/other/include', '', {}, ['--cflags', '--cflags-only-I', 'other']),
         (0, '-DOTHER -I/other/include', '', {}, ['--cflags', '--cflags-only-other', 'other']),
         ]

if __name__ == '__main__':
    checker = PkgChecker(__file__, sys.argv)
    sys.exit(checker.check(tests))
