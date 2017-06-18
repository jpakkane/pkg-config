#!/usr/bin/env python

import sys
from pkgchecker import PkgChecker

# These tests check the evaluation of the 'recursive_fill_list' function to
# verify that for any package s that depends on t, that the library defined by
# package s occurs before that of package t

tests = [(0, '-la_dep_c -lb_dep_c -lc_dep', '', {'PKG_CONFIG_PATH': '${srcdir}/dependencies'}, ['--libs', 'a_dep_c', 'b_dep_c']),
         (0, '-la_dep_c -lb_dep_c -lc_dep', '', {'PKG_CONFIG_PATH': '${srcdir}/dependencies'}, ['--libs', 'c_dep', 'a_dep_c', 'b_dep_c']),
         (0, '-la_dep_c -lb_dep_c -lc_dep', '', {'PKG_CONFIG_PATH': '${srcdir}/dependencies'}, ['--libs', 'a_dep_c', 'c_dep', 'b_dep_c']),
         (0, '-la_dep_c -lb_dep_c -lc_dep', '', {'PKG_CONFIG_PATH': '${srcdir}/dependencies'}, ['--libs', 'a_dep_c', 'b_dep_c', 'c_dep']),
# # Redundancy test.
# #
# # Redundancy on the input line should not pass through.
         (0, '-la_dep_c -lb_dep_c -lc_dep', '', {'PKG_CONFIG_PATH': '${srcdir}/dependencies'}, ['--libs', 'a_dep_c', 'a_dep_c', 'b_dep_c']),
         (0, '-la_dep_c -lb_dep_c -lc_dep', '', {'PKG_CONFIG_PATH': '${srcdir}/dependencies'}, ['--libs', 'b_dep_c', 'a_dep_c', 'b_dep_c']),
# # Diamond pattern test.
# #
# # One dependency of d depends on the other.
# # Both dependencies of d depend on g
         (0, '-ld_dep_e_f -le_dep_g_f -lf_dep_g -lg_dep', '', {'PKG_CONFIG_PATH': '${srcdir}/dependencies'}, ['--libs', 'd_dep_e_f']),
         (0, '-ld_dep_f_e -le_dep_g_f -lf_dep_g -lg_dep', '', {'PKG_CONFIG_PATH': '${srcdir}/dependencies'}, ['--libs', 'd_dep_f_e']),
# # Nested inclusion.
# #
# # Each package depends on all downsteam packages.
         (0, '-lh_dep_k_i_j -li_dep_k_j -lj_dep_k -lk_dep', '', {'PKG_CONFIG_PATH': '${srcdir}/dependencies'}, ['--libs', 'h_dep_k_i_j']),
         (0, '-lh_dep_k_i_j -li_dep_k_j -lj_dep_k -lk_dep', '', {'PKG_CONFIG_PATH': '${srcdir}/dependencies'}, ['--libs', 'i_dep_k_j', 'h_dep_k_i_j']),
         (0, '-lh_dep_k_i_j -li_dep_k_j -lj_dep_k -lk_dep', '', {'PKG_CONFIG_PATH': '${srcdir}/dependencies'}, ['--libs', 'k_dep', 'j_dep_k', 'i_dep_k_j', 'h_dep_k_i_j']),
        ]

if __name__ == '__main__':
    checker = PkgChecker(__file__, sys.argv)
    sys.exit(checker.check(tests))
