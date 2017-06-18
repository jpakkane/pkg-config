tests = ['check-cflags.py',
  'check-circular-requires.py',
  'check-cmd-options.py',
  'check-conflicts.py',
  'check-debug.py',
  'check-define-variable.py',
  'check-dependencies.py',
  'check-duplicate-flags.py',
  'check-gtk.py',
  'check-includedir.py',
  'check-libs.py',
  'check-libs-private.py',
  'check-missing.py',
  'check-mixed-flags.py',
  'check-non-l-flags.py',
  'check-path.py',
  'check-print-options.py',
  'check-relocatable.py',
  'check-requires-private.py',
  'check-requires-version.py',
  'check-sort-order.py',
  'check-special-flags.py',
  ]

foreach t: tests
  test(t, py3_exe, args: files(t) + [pkgconfig])
endforeach

configure_file(input : 'config.sh.in',
  output : 'config.txt',
  configuration : cdata)
