#!/usr/bin/env python

import sys
from pkgchecker import PkgChecker

tests = [
# Test != comparison fails
    (1, '', '', {}, ['--exists', 'requires-version-1']),

# Test >=, > and = succeed
    (0, '', '', {}, ['--exists', 'requires-version-2']),

# Test <=, < and != succeed
    (0, '', '', {}, ['--exists', 'requires-version-3']),
    ]


if __name__ == '__main__':
    checker = PkgChecker(__file__, sys.argv)
    sys.exit(checker.check(tests))
