tests = ['check-cflags.py',
  'check-circular-requires.py',
  'check-cmd-options.py',
  'check-conflicts.py',
  'check-debug.py',
  'check-define-variable.py',
  'check-dependencies.py',
  'check-duplicate-flags.py',
  ]

foreach t: tests
  test(t, py3_exe, args: files(t) + [pkgconfig])
endforeach

configure_file(input : 'config.sh.in',
  output : 'config.txt',
  configuration : cdata)
