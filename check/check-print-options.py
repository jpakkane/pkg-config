#!/usr/bin/env python

import sys
from pkgchecker import PkgChecker

tests = [(0, '$PACKAGE_VERSION', '', {}, ['--version']),
         (0, '1.0.0', '', {}, ['--modversion', 'simple']),

# --print-variables, make sure having no variables doesn't crash
         (0, 'pcfiledir', '', {}, ['--print-variables', 'no-variables']),
         (0, '''exec_prefix
includedir
libdir
pcfiledir
prefix''', '', {}, ['--print-variables', 'simple']),

         (0, 'simple = 1.0.0', '', {}, ['--print-provides', 'simple']),
         (0, 'public-dep >= 1', '', {}, ['--print-requires', 'requires-test']),

         (0, 'private-dep >= 1', '', {}, ['--print-requires-private', 'requires-test',]),

# --list-all, limit to a subdirectory
         (0, '''sub1   Subdirectory package 1 - Test package 1 for subdirectory
sub2   Subdirectory package 2 - Test package 2 for subdirectory
broken Broken package - Module with broken .pc file''', '', {'PKG_CONFIG_LIBDIR': '$srcdir/sub'}, ['--list-all']),

# Check handling when multiple incompatible options are set
         (0, '$PACKAGE_VERSION', 'Ignoring incompatible output option "--modversion"', {}, ['--version', '--modversion', 'simple']),

         (0, '1.0.0''', 'Ignoring incompatible output option "--version"', {}, ['--modversion', '--version', 'simple']),

# --print-requires/--print-requires-private allowed together
         (0, '''public-dep >= 1
private-dep >= 1''', '', {}, ['--print-requires', '--print-requires-private', 'requires-test']),
         (0, '''public-dep >= 1
private-dep >= 1''', '', {}, ['--print-requires-private', '--print-requires', 'requires-test']),

# --exists and --atleast/exact/max-version can be mixed
         (0, '', '', {}, ['--exists', '--atleast-version=1.0.0', 'simple']),
         (0, '', '', {}, ['--exists', '--exact-version=1.0.0', 'simple']),
         (0, '', '', {}, ['--exists', '--max-version=1.0.0', 'simple']),
]

if __name__ == '__main__':
    checker = PkgChecker(__file__, sys.argv)
    sys.exit(checker.check(tests))
