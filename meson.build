project('pkg-config', 'c',
  version: '0.29.2',
  license: 'GPLv2+')

py3_mod = import('python3')
py3_exe = py3_mod.find_python()

glib_dep = dependency('glib-2.0')

cdata = configuration_data()

cdata.set_quoted('VERSION', meson.project_version())
cdata.set('ENABLE_DEFINE_PREFIX', 'TRUE')
cdata.set('ENABLE_INDIRECT_DEPS', 'TRUE')
# These need to be /usr instead of prefix, which can point to /usr/local or something like that.
cdata.set_quoted('PKG_CONFIG_SYSTEM_INCLUDE_PATH', join_paths('/usr', get_option('includedir')))
cdata.set_quoted('PKG_CONFIG_SYSTEM_LIBRARY_PATH', join_paths('/usr', get_option('libdir')))
cdata.set_quoted('PKG_CONFIG_PC_PATH', join_paths(get_option('prefix'), get_option('libdir'), 'pkgconfig'))

cdata.set('PACKAGE_VERSION', meson.project_version())

cdata.set('srcdir', join_paths(meson.current_source_dir(), 'check'))

configure_file(output : 'config.h',
  configuration : cdata)

pkgconfig = executable('pkg-config',
  'pkg.c',
  'parse.c',
  'rpmvercmp.c',
  'main.c',
  c_args : '-DHAVE_CONFIG_H=1',
  dependencies : glib_dep)

subdir('check')

