#!/usr/bin/env python

import sys
from pkgchecker import PkgChecker

topbuild_env = {'PKG_CONFIG_TOP_BUILD_DIR': '$(abs_top_builddir)'}
disable_env = {'PKG_CONFIG_DISABLE_UNINSTALLED': '1'}

tests = [

# Check to see if we find the uninstalled version
    (0, '', '', {}, ['--uninstalled', 'inst']),
    (0, '', '', {}, ['--exists', 'inst', '>= 2.0']),

    (0, '-I$(top_builddir)/include', '', {}, ['--cflags', 'inst',]),
    (0, '-L$(top_builddir)/lib -linst', '', {}, ['--libs', 'inst']),

# Alter PKG_CONFIG_TOP_BUILD_
    (0, '-I$(abs_top_builddir)/include', '', topbuild_env, ['--cflags', 'inst']),
    (0, '-L$(abs_top_builddir)/lib -linst', '', topbuild_env, ['--libs', 'inst']),

# Check to see if we get the original back
    (1, '', '', disable_env, ['--uninstalled', 'inst']),
    (1, '', '', disable_env, ['--exists', 'inst', '>= 2.0']),

    (0, '-I/inst/include', '', disable_env, ['--cflags', 'inst']),
    (0, '-L/inst/lib -linst', '', disable_env, ['--libs', 'inst']),
]

if __name__ == '__main__':
    checker = PkgChecker(__file__, sys.argv)
    sys.exit(checker.check(tests))

