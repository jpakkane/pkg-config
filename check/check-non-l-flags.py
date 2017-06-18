#/usr/bin/env python
import sys
from pkgchecker import PkgChecker

tests = [(0, '-I/non-l/include -I/non-l-required/include', '', {}, ['--cflags', 'non-l-required', 'non-l']),
         (0, '-I/non-l/include -I/non-l-required/include', '', {}, ['--cflags', '--static', 'non-l-required non-l']),

         (0, '/non-l.a /non-l-required.a -pthread', '', {}, ['--libs', 'non-l-required', 'non-l']),
         (0, '/non-l.a /non-l-required.a -pthread', '', {}, ['--libs', '--static', 'non-l-required', 'non-l']),
        ]

if __name__ == '__main__':
    checker = PkgChecker(__file__, sys.argv)
    sys.exit(checker.check(tests))
