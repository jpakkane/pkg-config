#!/usr/bin/env python

import subprocess, sys, os

tests = [('', ['--cflags', 'simple']),
         ('', ['--cflags', 'fields-blank']),
         ('-DOTHER -I/other/include', ['--cflags', 'other']),
         ('-I/other/include', ['--cflags-only-I', 'other']),
         ('-DOTHER', ['--cflags-only-other', 'other']),
         # Try various mixed combinations
         ('-DOTHER -I/other/include', ['--cflags-only-I', '--cflags-only-other', 'other']),
         ('-DOTHER -I/other/include', ['--cflags-only-other', '--cflags-only-I', 'other']),
         ('-DOTHER -I/other/include', ['--cflags', '--cflags-only-I', '--cflags-only-other', 'other']),
         ('-DOTHER -I/other/include', ['--cflags', '--cflags-only-I', 'other']),
         ('-DOTHER -I/other/include', ['--cflags', '--cflags-only-other', 'other']),
         ]

def run_tests(data_dir, pkgconfig_bin, tests):
    assert(os.path.isabs(data_dir))
    assert(os.path.isabs(pkgconfig_bin)) # To ensure we do not run the pkg-config that is in path by accident,
    total_errors = 0
    env = os.environ.copy()
    env['PKG_CONFIG_PATH'] = data_dir
    for expected, arguments in tests:
        pc = subprocess.Popen([pkgconfig_bin] + arguments, universal_newlines=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=env)
        stdo, stde = pc.communicate()
        stdo = stdo.rstrip()
        if pc.returncode != 0:
            print('Error running command')
            print(stdo)
            print(stde)
            total_errors += 1
        elif stdo != expected:
            print('Error for arguments', ' '.join(arguments))
            print(' expected:', expected)
            print(' received:', stdo)
            total_errors += 1
    return total_errors

if __name__ == '__main__':
    src_dir = os.path.realpath(os.path.split(__file__)[0])
    sys.exit(run_tests(src_dir, os.path.join(os.getcwd(), sys.argv[1]), tests))
