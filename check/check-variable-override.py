#!/usr/bin/env python

import sys
from pkgchecker import PkgChecker

simple_pref = {'PKG_CONFIG_SIMPLE_PREFIX': "/foo"}

tests = [
# Check the normal behavior
    (0, "/usr", '', {}, ['--variable=prefix', 'simple']),
    (0, '/usr/lib', '', {}, ['--variable=libdir', 'simple']),

# Override prefix with correct environment variable
    (0, "/foo", '', simple_pref, ['--variable=prefix', 'simple']),
    (0, "/foo/lib", '', simple_pref, ['--variable=libdir', 'simple']),
    (0, "-I/foo/include", '', simple_pref, ['--cflags', 'simple']),

# # Override prefix with incorrect environment variable case. On Windows
# # this will have no effect as environment variables are case
# # insensitive.
# if [ "$native_win32" != yes ]; then
#     export PKG_CONFIG_SIMPLE_prefix="/foo"
#     RESULT="/usr"
#     run_test --variable=prefix simple
#     RESULT="/usr/lib"
#     run_test --variable=libdir simple
#     RESULT=""
#     run_test --cflags simple
#     unset PKG_CONFIG_SIMPLE_prefix
# fi
]

if __name__ == '__main__':
    checker = PkgChecker(__file__, sys.argv)
    sys.exit(checker.check(tests))
