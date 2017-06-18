#!/usr/bin/env python

import sys
from pkgchecker import PkgChecker

tests = [(0, '$PACKAGE_VERSION', '''PKG_CONFIG_DEBUG_SPEW variable enabling debug spew
Adding directory '$srcdir' from PKG_CONFIG_PATH
Global variable definition 'pc_sysrootdir' = '/'
Global variable definition 'pc_top_builddir' = '$(top_builddir)'
Error printing enabled by default due to use of output options besides --exists, --atleast/exact/max-version or --list-all. Value of --silence-errors: 0
Error printing enabled''', {'PKG_CONFIG_DEBUG_SPEW': '1'}, ['--version']),
         (0, '$PACKAGE_VERSION', '''Error printing enabled by default due to use of output options besides --exists, --atleast/exact/max-version or --list-all. Value of --silence-errors: 0
Error printing enabled
''', {}, ['--debug', '--version']),
]

if __name__ == '__main__':
    checker = PkgChecker(__file__, sys.argv)
    sys.exit(checker.check(tests))
