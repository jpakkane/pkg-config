#!/usr/bin/env python

import sys
from pkgchecker import PkgChecker

tests = [
# expect cflags from requires-test and public-dep
    (0, '-I/requires-test/include -I/private-dep/include -I/public-dep/include', '', {}, ['--cflags', 'requires-test']),
    (0, '-I/requires-test/include -I/private-dep/include -I/public-dep/include', '', {}, ['--static', '--cflags', 'requires-test']),

# # expect libs for just requires-test and public-dep
# RESULT="-L/requires-test/lib -L/public-dep/lib -lrequires-test -lpublic-dep"
# if [ "$list_indirect_deps" = no ]; then
#     run_test --libs requires-test
# fi

# expect libs for requires-test, public-dep and private-dep in static case
    (0, '-L/requires-test/lib -L/private-dep/lib -L/public-dep/lib -lrequires-test -lprivate-dep -lpublic-dep', '', {}, ['--static', '--libs', 'requires-test']),
#if [ "$list_indirect_deps" = yes ]; then
#    run_test --libs requires-test
#fi
]

if __name__ == '__main__':
    checker = PkgChecker(__file__, sys.argv)
    sys.exit(checker.check(tests))
