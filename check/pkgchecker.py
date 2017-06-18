#!/usr/bin/env python

import subprocess, sys, os

class PkgChecker:
    def __init__(self, caller_file, cmd_args):
        self.data_dir = os.path.realpath(os.path.split(__file__)[0])
        self.pkgconfig_bin = os.path.join(os.getcwd(), cmd_args[1])
        assert(os.path.isabs(self.data_dir))
        assert(os.path.isabs(self.pkgconfig_bin)) # To ensure we do not run the pkg-config that is in path by accident,
        conf_file = os.path.join(os.getcwd(), 'check/config.txt')
        self.replacements = {}
        for line in open(conf_file):
            line = line.split('#')[0].strip()
            if not line:
                continue
            k, v = line.split('=', 1)
            self.replacements[k.strip()] = v.strip()


    def varsubst(self, text):
        for k, v in self.replacements.items():
            text = text.replace('$' + k, v)
            text = text.replace('${%s}' % k, v)
        return text

    def check(self, tests):
        total_errors = 0
        for expected_rc, expected_stdout, expected_stderr, envvars, arguments in tests:
            env = os.environ.copy()
            if 'PKG_CONFIG_PATH' in env:
                del env['PKG_CONFIG_PATH']
            env['PKG_CONFIG_LIBDIR'] = self.data_dir
            env['LC_ALL'] = 'C'
            for k, v in envvars.items():
                env[k] = self.varsubst(v)
            is_problem = False
            full_cmd = [self.pkgconfig_bin] + [self.varsubst(x) for x in arguments]
            pc = subprocess.Popen(full_cmd,
                                  universal_newlines=True,
                                  stdout=subprocess.PIPE,
                                  stderr=subprocess.PIPE,
                                  env=env)
            stdo, stde = pc.communicate()
            stdo = stdo.strip()
            stde = stde.strip()
            expected_stdout = self.varsubst(expected_stdout.strip())
            expected_stderr = self.varsubst(expected_stderr.strip())
            if pc.returncode != expected_rc:
                print('Error running command')
                print(stdo)
                print(stde)
                is_problem = True
            if stdo != expected_stdout:
                print('\nError for command', ' '.join(full_cmd))
                print(' expected stdout:\n\n', expected_stdout)
                print('\n received stdout:\n\n', stdo)
                is_problem = True
            if stde != expected_stderr:
                print('\nError for command', ' '.join(full_cmd))
                print(' expected stderr:\n\n', expected_stderr)
                print('\n received stderr:\n\n', stde)
                is_problem = True
            if is_problem:
                total_errors += 1
        return total_errors
