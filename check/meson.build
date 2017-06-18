tests = ['check-cflags.py', 'check-debug.py']

foreach t: tests
  test(t, py3_exe, args: files(t) + [pkgconfig])
endforeach

configure_file(input : 'config.sh.in',
  output : 'config.txt',
  configuration : cdata)
