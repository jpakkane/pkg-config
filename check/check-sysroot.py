#!/usr/bin/env python

import sys
from pkgchecker import PkgChecker

# MSYS mangles / paths to its own root in windows format. This probably
# means sysroot doesn't work there, but match what pkg-config passes
# back anyway.
#[ "$OSTYPE" = msys ] && root=$(cd / && pwd -W) || root=
root=''

sr = {'PKG_CONFIG_SYSROOT_DIR': '/sysroot'}

tests = [(0, '', '', sr, ['--cflags', 'simple']),
#          RESULT="-lsimple"
#if [ "$list_indirect_deps" = no ]; then
#    run_test --libs simple
#fi

#RESULT="-lsimple -lm"
#if [ "$list_indirect_deps" = yes ]; then
#    run_test --libs simple
#fi
         (0, '-lsimple -lm', '', sr, ['--libs', '--static', 'simple']),
         (0, '-I%s/sysroot/public-dep/include' % root, '', sr, ['--cflags', 'public-dep']),
         (0, '-L%s/sysroot/public-dep/lib -lpublic-dep' % root, '', sr, ['--libs', 'public-dep']),
         (0, '-g -ffoo -I%s/sysroot/foo -isystem %s/sysroot/system1 -idirafter %s/sysroot/after1 -I%s/sysroot/bar -idirafter %s/sysroot/after2 -isystem %s/sysroot/system2' % (root, root, root, root, root, root), '', sr, ['--cflags', 'special-flags']),
         (0, '-L%s/sysroot/foo -L%s/sysroot/bar -framework Foo -lsimple -framework Bar -Wl,-framework -Wl,Baz' % (root, root), '', sr, ['--libs', 'special-flags']),
         ]

if __name__ == '__main__':
    checker = PkgChecker(__file__, sys.argv)
    sys.exit(checker.check(tests))
