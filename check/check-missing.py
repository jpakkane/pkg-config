#/usr/bin/env python
import sys
from pkgchecker import PkgChecker

tests = [

# non-existent package; call should fail and cause no output
    (1, '', '', {}, ['--exists', 'pkg-non-existent']),

# existing package, but with missing Requires
    (1, '', '', {}, ['--exists', 'missing-requires']),

# tests below are on an existing package, but with missing Requires.private;
# when pkg-config outputs error, the actual error text isn't checked
# package exists, but should fail since deps can't be resolved
    (1, '', '', {}, ['--exists', 'missing-requires-private']),

# get Libs
#    (0, '-L/missing-requires-private/lib -lmissing-requires-private', ['--libs', 'missing-requires-private']),
#if [ "$list_indirect_deps" = no ]; then
#    run_test --libs missing-requires-private
#fi

# Libs.private should fail (verbosely, but the output isn't verified)
#EXPECT_RETURN=1
#RESULT=""
#if [ "$list_indirect_deps" = yes ]; then
#    run_test --silence-errors --libs missing-requires-private
#fi
    (1, '', '', {}, ['--silence-errors', '--static', '--libs', 'missing-requires-private']),

# Cflags.private should fail (verbosely, but the output isn't verified)
    (1, '', '', {}, ['--silence-errors', '--static', '--cflags', 'missing-requires-private']),

# Cflags should fail (verbosely, but the output isn't verified)
    (1, '', '', {}, ['--silence-errors', '--cflags', 'missing-requires-private']),

# get includedir var
    (0, '/usr/include/somedir', '', {}, ['--variable', 'includedir', 'missing-requires-private']),

# tests below are on an existing package, but with missing Requires;
# when pkg-config outputs error, the actual error text isn't checked
# package exists
    (1, '', '', {}, ['missing-requires']),

# Libs should fail
    (1, '', '', {}, ['--silence-errors', '--libs', 'missing-requires']),

# Cflags should fail
    (1, '', '', {}, ['--silence-errors', '--cflags', 'missing-requires']),

# get includedir var
    (0, '/usr/include/somedir', '', {}, ['--variable', 'includedir', 'missing-requires']),
]

if __name__ == '__main__':
    checker = PkgChecker(__file__, sys.argv)
    sys.exit(checker.check(tests))
