#!/usr/bin/env python

import sys
from pkgchecker import PkgChecker

v1='0.9.9'
v2='1.0.0'
v3='1.0.1'

tests = [
# --atleast-pkgconfig-version
    (0, '', '', {}, ['--atleast-pkgconfig-version=$PACKAGE_VERSION']),

    (1, '', '', {}, ['--atleast-pkgconfig-version=999']),

# exact version testing
    (1, '', "Requested 'simple = %s' but version of Simple test is %s" % (v1, v2), {}, ['--print-errors', 'simple = ' + v1]),

    (1, '', "Requested 'simple = %s' but version of Simple test is %s" % (v1, v2), {}, ['--print-errors', '--exact-version='+v1, 'simple']),

    (0, '', '', {}, ['--print-errors', 'simple = ' + v2]),

    (0, '', '', {}, ['--print-errors', '--exact-version=' + v2, 'simple']),

    (1, '', "Requested 'simple = %s' but version of Simple test is %s" % (v3, v2), {}, ['--print-errors', 'simple = ' + v3]),

    (1, '', "Requested 'simple = %s' but version of Simple test is %s" % (v3, v2), {}, ['--print-errors', '--exact-version='+v3, 'simple']),

# atleast version testing
    (0, '', '', {}, ['--print-errors', 'simple >= ' + v1]),

    (0, '', '', {}, ['--print-errors', '--atleast-version='+v1, 'simple']),

    (0, '', '', {}, ['--print-errors', 'simple >= '+v2]),

    (0, '', '', {}, ['--print-errors', '--atleast-version='+v2, 'simple']),

    (1, '', "Requested 'simple >= %s' but version of Simple test is %s" % (v3, v2), {}, ['--print-errors', 'simple >= '+v3]),

    (1, '', "Requested 'simple >= %s' but version of Simple test is %s" % (v3, v2), {}, ['--print-errors', '--atleast-version='+v3, 'simple']),

# max version testing
    (1, '', "Requested 'simple <= %s' but version of Simple test is %s" % (v1, v2), {}, ['--print-errors', 'simple <= '+v1]),

    (1, '', "Requested 'simple <= %s' but version of Simple test is %s" % (v1, v2), {}, ['--print-errors', '--max-version='+v1, 'simple']),

    (0, '', '', {}, ['--print-errors', 'simple <= '+v2]),

    (0, '', '', {}, ['--print-errors', '--max-version='+v2, 'simple']),

    (0, '', '', {}, ['--print-errors', 'simple <= '+v3]),

    (0, '', '', {}, ['--print-errors', '--max-version='+v3, 'simple']),

# mixing version compare testing is not allowed
    (0, '', 'Ignoring incompatible output option "--exact-version"', {}, ['--atleast-version=1.0.0', '--exact-version=1.0.0', 'simple']),
    ]

if __name__ == '__main__':
    checker = PkgChecker(__file__, sys.argv)
    sys.exit(checker.check(tests))
