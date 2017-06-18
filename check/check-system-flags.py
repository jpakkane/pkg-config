#!/usr/bin/env python

import sys
from pkgchecker import PkgChecker

def dictjoin(d1, d2):
    result = d1.copy()
    result.update(d2)
    return result

pgenv = {'PKG_CONFIG_SYSTEM_INCLUDE_PATH': '/usr/include',
         'PKG_CONFIG_SYSTEM_LIBRARY_PATH': '/usr/lib:/lib'
         }
fake_pgenv = {'PKG_CONFIG_SYSTEM_INCLUDE_PATH': '/foo/include',
              'PKG_CONFIG_SYSTEM_LIBRARY_PATH': '/foo/lib',
}

# if [ "$native_win32" = yes ]; then
#     PKG_CONFIG_SYSTEM_LIBRARY_PATH="/usr/lib;/lib"
# else
#     PKG_CONFIG_SYSTEM_LIBRARY_PATH=/usr/lib:/lib
# fi

tests = [(0, '', '', pgenv, ['--cflags', 'system']),
         (0, '-lsystem', '', pgenv, ['--libs', 'system']),

# Make sure that the full paths come out when the *_ALLOW_SYSTEM_*
# variables are set
         (0, '-I/usr/include', '', dictjoin(pgenv, {'PKG_CONFIG_ALLOW_SYSTEM_CFLAGS': '1'}), ['--cflags', 'system']),
         (0, '-L/usr/lib -lsystem', '', dictjoin(pgenv, {'PKG_CONFIG_ALLOW_SYSTEM_LIBS': '1'}), ['--libs', 'system']),

# Set the system paths to something else and test that the output
# contains the full paths
         (0, '-I/usr/include', '', fake_pgenv, ['--cflags', 'system']),
         (0, '-L/usr/lib -lsystem', '', fake_pgenv, ['--libs', 'system']),

# # Now check that the various GCC environment variables also update the
# # system include path
# for var in CPATH C_INCLUDE_PATH CPP_INCLUDE_PATH; do
#     RESULT=""
#     eval $var=/usr/include run_test --cflags system
# 
#     # Make sure these are not skipped in --msvc-syntax mode
#     if [ "$native_win32" = yes ]; then
#         RESULT="-I/usr/include"
#         eval $var=/usr/include run_test --cflags --msvc-syntax system
#     fi
# done
# 
# # Check that the various MSVC environment variables also update the
# # system include path when --msvc-syntax is in use
# for var in INCLUDE; do
#     RESULT="-I/usr/include"
#     eval $var=/usr/include run_test --cflags system
# 
#     # Make sure these are skipped in --msvc-syntax mode
#     if [ "$native_win32" = yes ]; then
#         RESULT=""
#         eval $var=/usr/include run_test --cflags --msvc-syntax system
#     fi
# done
]

if __name__ == '__main__':
    checker = PkgChecker(__file__, sys.argv)
    sys.exit(checker.check(tests))
