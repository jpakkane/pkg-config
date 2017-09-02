project('pkg-config', 'cpp',
  default_options: 'cpp_std=c++14',
  version: '0.29.2',
  license: 'GPLv2+')

py3_mod = import('python3')
py3_exe = py3_mod.find_python()

cdata = configuration_data()

cdata.set_quoted('VERSION', meson.project_version())
cdata.set('ENABLE_DEFINE_PREFIX', 'true')
cdata.set('ENABLE_INDIRECT_DEPS', 'true')
# These need to be /usr instead of prefix, which can point to /usr/local or something like that.
cdata.set_quoted('PKG_CONFIG_SYSTEM_INCLUDE_PATH', join_paths('/usr', get_option('includedir')))
cdata.set_quoted('PKG_CONFIG_SYSTEM_LIBRARY_PATH', join_paths('/usr', get_option('libdir')))
cdata.set_quoted('PKG_CONFIG_PC_PATH', join_paths(get_option('prefix'), get_option('libdir'), 'pkgconfig'))

cdata.set('PACKAGE_VERSION', meson.project_version())

cdata.set('srcdir', join_paths(meson.current_source_dir(), 'check'))
cdata.set('use_indirect_deps', cdata.get('ENABLE_INDIRECT_DEPS'))
cdata.set('abs_srcdir', join_paths(meson.current_source_dir(), 'check'))
cdata.set('abs_top_srcdir', meson.current_source_dir())

configure_file(output : 'config.h',
  configuration : cdata)

pkgconfig = executable('pkg-config',
  'pkg.cpp',
  'parse.cpp',
  'rpmvercmp.cpp',
  'quoter.cpp',
  'utils.cpp',
  'main.cpp',
  install : true)

subdir('check')

