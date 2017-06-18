#!/usr/bin/env python

import sys
from pkgchecker import PkgChecker

tests = [

# # Convert absolute directories to Windows format if necessary.
# if [ "$native_win32" = yes ]; then
#     # Assume we have cmd to do the conversion, except we have to escape
#     # the command switch on MSYS.
#     [ "$OSTYPE" = msys ] && opt="\\/C" || opt="/C"
#     abs_top_srcdir=$($WINE cmd $opt echo "$abs_top_srcdir" | tr -d '\r')
#     abs_srcdir=$($WINE cmd $opt echo "$abs_srcdir" | tr -d '\r')
# fi

# See if the pcfiledir variable is defined. First, with the path
# built from the relative PKG_CONFIG_LIBDIR. Second, with the path
# built from the full path to the pc file.
    (0, '$srcdir', '', {}, ['--variable=pcfiledir', 'pcfiledir']),
    (0, '$abs_srcdir', '', {}, ['--variable=pcfiledir', '$abs_srcdir/pcfiledir.pc']),

# Test if pcfiledir metadata variable is substituted correctly
    (0, '-I${srcdir}/include -L${srcdir}/lib -lfoo', '', {}, ['--cflags', '--libs', 'pcfiledir']),

# # Test prefix redefinition for .pc files in pkgconfig directory. Try .pc
# # files with both unexpanded and expanded variables. Use the absolute
# # directory for the search path so that pkg-config can strip enough
# # components of the file directory to be useful.
# prefixdeffor pkg in prefixdef prefixdef-expanded; do
#     # Typical redefinition
    (0, '-I${abs_top_srcdir}/include -L${abs_top_srcdir}/lib -lfoo', '', {'PKG_CONFIG_LIBDIR': '${abs_srcdir}/pkgconfig'}, ['--define-prefix', '--cflags', '--libs', 'prefixdef']),
    (0, '-I/reloc/include -L/reloc/lib -lfoo', '', {'PKG_CONFIG_LIBDIR': '${abs_srcdir}/pkgconfig'}, ['--dont-define-prefix', '--cflags', '--libs', 'prefixdef']),
#     # Non-standard redefinition
    (0, '-I/reloc/include -L${abs_top_srcdir} -lfoo', '', {'PKG_CONFIG_LIBDIR': '${abs_srcdir}/pkgconfig'}, ['--define-prefix', '--prefix-variable=libdir', '--cflags', '--libs', 'prefixdef']),
    (0, '-I/reloc/include -L/reloc/lib -lfoo', '', {'PKG_CONFIG_LIBDIR': '${abs_srcdir}/pkgconfig'}, ['--dont-define-prefix', '--cflags', '--libs', 'prefixdef']),
# prefixdef-expanded
#     # Typical redefinition
    (0, '-I${abs_top_srcdir}/include -L${abs_top_srcdir}/lib -lfoo', '', {'PKG_CONFIG_LIBDIR': '${abs_srcdir}/pkgconfig'}, ['--define-prefix', '--cflags', '--libs', 'prefixdef-expanded']),
    (0, '-I/reloc/include -L/reloc/lib -lfoo', '', {'PKG_CONFIG_LIBDIR': '${abs_srcdir}/pkgconfig'}, ['--dont-define-prefix', '--cflags', '--libs', 'prefixdef-expanded']),
#     # Non-standard redefinition
    (0, '-I/reloc/include -L${abs_top_srcdir} -lfoo', '', {'PKG_CONFIG_LIBDIR': '${abs_srcdir}/pkgconfig'}, ['--define-prefix', '--prefix-variable=libdir', '--cflags', '--libs', 'prefixdef-expanded']),
    (0, '-I/reloc/include -L/reloc/lib -lfoo', '', {'PKG_CONFIG_LIBDIR': '${abs_srcdir}/pkgconfig'}, ['--dont-define-prefix', '--cflags', '--libs', 'prefixdef-expanded']),

# Test prefix redefinition for .pc files with an empty prefix. In this
# case, there should be no prefix adjustment to the other variables. The
# result should be the same regardless of prefix redefinition.
    (0, "-I/some/path/include -L/some/path/lib -lfoo", '', {'PKG_CONFIG_LIBDIR': '${abs_srcdir}/pkgconfig'}, ['--define-prefix', '--cflags', '--libs', 'empty-prefix']),
    (0, "-I/some/path/include -L/some/path/lib -lfoo", '', {'PKG_CONFIG_LIBDIR': '${abs_srcdir}/pkgconfig'}, ['--dont-define-prefix', '--cflags', '--libs', 'empty-prefix'])
    ]

if __name__ == '__main__':
    checker = PkgChecker(__file__, sys.argv)
    sys.exit(checker.check(tests))
