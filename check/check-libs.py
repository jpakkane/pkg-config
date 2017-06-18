#!/usr/bin/env python

import sys
from pkgchecker import PkgChecker

tests = [

#RESULT="-lsimple"
#if [ "$list_indirect_deps" = no ]; then
#    run_test --libs simple
#fi
#
#RESULT="-lsimple -lm"
#if [ "$list_indirect_deps" = yes ]; then
#    run_test --libs simple
#fi
         (0, '-lsimple -lm', '', {}, ['--libs', '--static', 'simple']),
         (0, '', '', {}, ['--libs', 'fields-blank',]),
         (0, '-L/other/lib -Wl,--as-needed -lother', '', {}, ['--libs', 'other']),
         (0, '-lother', '', {}, ['--libs-only-l', 'other']),
         (0, '-L/other/lib', '', {}, ['--libs-only-L', 'other']),
         (0, '-Wl,--as-needed', '', {}, ['--libs-only-other', 'other']),
# Try various mixed combinations
         (0, '-L/other/lib -lother', '', {}, ['--libs-only-l', '--libs-only-L', 'other']),
         (0, '-L/other/lib -lother', '', {}, ['--libs-only-L', '--libs-only-l', 'other']),
         (0, '-Wl,--as-needed -lother', '', {}, ['--libs-only-l', '--libs-only-other', 'other']),
         (0, '-Wl,--as-needed -lother', '', {}, ['--libs-only-other', '--libs-only-l', 'other']),
         (0, '-L/other/lib -Wl,--as-needed', '', {}, ['--libs-only-L', '--libs-only-other', 'other']),
         (0, '-L/other/lib -Wl,--as-needed', '', {}, ['--libs-only-other', '--libs-only-L', 'other']),

         (0, '-L/other/lib -Wl,--as-needed -lother', '', {}, ['--libs-only-l', '--libs-only-L', '--libs-only-other', 'other']),
         (0, '-L/other/lib -Wl,--as-needed -lother', '', {}, ['--libs', '--libs-only-l', '--libs-only-L', '--libs-only-other', 'other']),
         (0, '-L/other/lib -Wl,--as-needed -lother', '', {}, ['--libs', '--libs-only-l', 'other']),
         (0, '-L/other/lib -Wl,--as-needed -lother', '', {}, ['--libs', '--libs-only-L', 'other']),
         (0, '-L/other/lib -Wl,--as-needed -lother', '', {}, ['--libs', '--libs-only-other', 'other']),

]

if __name__ == '__main__':
    checker = PkgChecker(__file__, sys.argv)
    sys.exit(checker.check(tests))
