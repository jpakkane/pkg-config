#!/usr/bin/env python

import sys
from pkgchecker import PkgChecker

tests = [(1, '', 'Unknown option --blah', {}, ['--blah']),
# # all of these should fail, but when '=' or ' ' aren't used consistently
# # between the two options, broken popt sets the version to compare to be
# # "a=b"
         (1, '', '', {}, ['--define-variable=a=b', '--atleast-pkgconfig-version=999.999',]),
         (1, '', '', {}, ['--define-variable=a=b', '--atleast-pkgconfig-version', '999.999']),
         (1, '', '', {}, ['--define-variable', 'a=b', '--atleast-pkgconfig-version', '999.999']),
         (1, '', '', {}, ['--define-variable', 'a=b', '--atleast-pkgconfig-version=999.999']),

]

if __name__ == '__main__':
    checker = PkgChecker(__file__, sys.argv)
    sys.exit(checker.check(tests))
