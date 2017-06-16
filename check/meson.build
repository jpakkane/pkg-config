tests = ['check-cflags.py']

foreach t: tests
  test(t, py3_exe, args: files(t) + [pkgconfig])
endforeach
