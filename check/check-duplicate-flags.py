#!/usr/bin/env python

import sys
from pkgchecker import PkgChecker

tests = [(0, '-DPATH2 -DFOO -DPATH1 -DFOO -I/path/include', '', {}, ['--cflags', 'flag-dup-1', 'flag-dup-2']),
         (0, '-L/path/lib -lpath2 -Wl,--whole-archive -lm --Wl,--no-whole-archive -Xlinker -R -Xlinker /path/lib -lpath1 -Wl,--whole-archive -lm --Wl,--no-whole-archive -Xlinker -R -Xlinker /path/lib', '', {}, ['--libs', 'flag-dup-1', 'flag-dup-2']),
         (0, '-L/path/lib -lpath2 -Wl,--whole-archive -lm --Wl,--no-whole-archive -Xlinker -R -Xlinker /path/lib -lpath1 -Wl,--whole-archive -lm --Wl,--no-whole-archive -Xlinker -R -Xlinker /path/lib', '', {}, ['--libs', 'flag-dup-2', 'flag-dup-1',]),
         ]

if __name__ == '__main__':
    checker = PkgChecker(__file__, sys.argv)
    sys.exit(checker.check(tests))
