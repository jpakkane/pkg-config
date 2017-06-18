#!/usr/bin/env python
import sys
from pkgchecker import PkgChecker

tests = [(0, '-DOTHER -I/other/include -L/other/lib -Wl,--as-needed -lother', '', {}, ['--cflags', '--libs', 'other']),
         (0, '-DOTHER -I/other/include -L/other/lib -Wl,--as-needed -lother', '', {}, ['--libs', '--cflags', 'other']),
         (0, '-DOTHER -I/other/include -L/other/lib -Wl,--as-needed -lother', '', {}, ['--cflags-only-I', '--cflags-only-other', '--libs-only-l', '--libs-only-L', '--libs-only-other', 'other']),

         (0, '-I/other/include -lother', '', {}, ['--cflags-only-I', '--libs-only-l', 'other']),
         (0, '-I/other/include -lother', '', {}, ['--libs-only-l', '--cflags-only-I', 'other']),

         (0, '-DOTHER -lother', '', {}, ['--cflags-only-other', '--libs-only-l', 'other']),
         (0, '-DOTHER -lother', '', {}, ['--libs-only-l', '--cflags-only-other', 'other']),

         (0, '-I/other/include -L/other/lib', '', {}, ['--cflags-only-I', '--libs-only-L', 'other']),
         (0, '-I/other/include -L/other/lib', '', {}, ['--libs-only-L', '--cflags-only-I', 'other']),

         (0, '-DOTHER -L/other/lib', '', {}, ['--cflags-only-other', '--libs-only-L', 'other']),
         (0, '-DOTHER -L/other/lib', '', {}, ['--libs-only-L', '--cflags-only-other', 'other']),

         (0, '-I/other/include -Wl,--as-needed', '', {}, ['--cflags-only-I', '--libs-only-other', 'other']),
         (0, '-I/other/include -Wl,--as-needed', '', {}, ['--libs-only-other', '--cflags-only-I', 'other']),

         (0, '-DOTHER -Wl,--as-needed', '', {}, ['--cflags-only-other', '--libs-only-other', 'other']),
         (0, '-DOTHER -Wl,--as-needed', '', {}, ['--libs-only-other', '--cflags-only-other', 'other']),

         (0, '-I/other/include -L/other/lib -lother', '', {}, ['--cflags-only-I', '--libs-only-L', '--libs-only-l', 'other']),
         (0, '-I/other/include -L/other/lib -lother', '', {}, ['--libs-only-l', '--libs-only-L', '--cflags-only-I', 'other']),

         (0, '-DOTHER -L/other/lib -lother', '', {}, ['--cflags-only-other', '--libs-only-L', '--libs-only-l', 'other']),
         (0, '-DOTHER -L/other/lib -lother', '', {}, ['--libs-only-l', '--libs-only-L', '--cflags-only-other', 'other']),

         (0, '-I/other/include -Wl,--as-needed -lother', '', {}, ['--cflags-only-I', '--libs-only-other', '--libs-only-l', 'other']),
         (0, '-I/other/include -Wl,--as-needed -lother', '', {}, ['--libs-only-l', '--libs-only-other', '--cflags-only-I', 'other']),

         (0, '-DOTHER -Wl,--as-needed -lother', '', {}, ['--cflags-only-other', '--libs-only-other', '--libs-only-l', 'other']),
         (0, '-DOTHER -Wl,--as-needed -lother', '', {}, ['--libs-only-l', '--libs-only-other', '--cflags-only-other', 'other']),

         (0, '-I/other/include -L/other/lib -Wl,--as-needed', '', {}, ['--cflags-only-I', '--libs-only-other', '--libs-only-L', 'other']),
         (0, '-I/other/include -L/other/lib -Wl,--as-needed', '', {}, ['--libs-only-L', '--libs-only-other', '--cflags-only-I', 'other']),

         (0, '-DOTHER -L/other/lib -Wl,--as-needed', '', {}, ['--cflags-only-other', '--libs-only-other', '--libs-only-L', 'other']),
         (0, '-DOTHER -L/other/lib -Wl,--as-needed', '', {}, ['--libs-only-L', '--libs-only-other', '--cflags-only-other', 'other']),

         (0, '-DOTHER -I/other/include -lother', '', {}, ['--cflags', '--libs-only-l', 'other']),
         (0, '-DOTHER -I/other/include -lother', '', {}, ['--cflags-only-I', '--cflags-only-other', '--libs-only-l', 'other']),

         (0, '-DOTHER -I/other/include -L/other/lib', '', {}, ['--cflags', '--libs-only-L', 'other']),
         (0, '-DOTHER -I/other/include -L/other/lib', '', {}, ['--cflags-only-I', '--cflags-only-other', '--libs-only-L', 'other']),

         (0, '-DOTHER -I/other/include -Wl,--as-needed', '', {}, ['--cflags', '--libs-only-other', 'other']),
         (0, '-DOTHER -I/other/include -Wl,--as-needed', '', {}, ['--cflags-only-I', '--cflags-only-other', '--libs-only-other', 'other']),

         (0, '-I/other/include -L/other/lib -Wl,--as-needed -lother', '', {}, ['--cflags-only-I', '--libs', 'other']),
         (0, '-I/other/include -L/other/lib -Wl,--as-needed -lother', '', {}, ['--cflags-only-I', '--libs-only-l', '--libs-only-L', '--libs-only-other', 'other']),

         (0, '-DOTHER -L/other/lib -Wl,--as-needed -lother', '', {}, ['--cflags-only-other', '--libs', 'other']),
         (0, '-DOTHER -L/other/lib -Wl,--as-needed -lother', '', {}, ['--cflags-only-other', '--libs-only-l', '--libs-only-L', '--libs-only-other', 'other']),
         ]

if __name__ == '__main__':
    checker = PkgChecker(__file__, sys.argv)
    sys.exit(checker.check(tests))
