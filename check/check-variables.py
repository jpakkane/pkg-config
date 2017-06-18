#!/usr/bin/env python

import sys
from pkgchecker import PkgChecker

tests = [
# Check quoted variables are stripped. In 0.28 and earlier, this would
# contain the "" quotes.
    (0, '/local/include', '', {}, ['--variable=includedir', 'variables']),

# Non-quoted variables are output as is. In 0.29, the \ would be stripped.
    (0, '-I"/local/include"/foo  -DFOO=\\"/bar\\"', '', {}, ['--variable=cppflags', 'variables']),

# Check the entire cflags output
    (0, '-DFOO=\\"/bar\\" -I/local/include -I/local/include/foo', '', {}, ['--cflags', 'variables']),
]

if __name__ == '__main__':
    checker = PkgChecker(__file__, sys.argv)
    sys.exit(checker.check(tests))
