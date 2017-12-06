/*
 * Copyright (C) 2001, 2002 Red Hat Inc.
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of the
 * License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
 * 02111-1307, USA.
 */

module main;
import std.stdio;
import std.format;
import pkg;
import utils;
import parse: define_prefix, parse_module_list, parse_strict;
import core.stdc.stdlib;
import std.algorithm.sorting;
import std.conv;
import std.string;

string pcsysrootdir;
string pkg_config_pc_path;

const bool ENABLE_INDIRECT_DEPS = true;
const string PKG_CONFIG_PC_PATH = "/usr/lib/pkgconfig";

string prefix_variable = "prefix";

string VERSION;
bool want_my_version = false;
bool want_version = false;
FlagType pkg_flags = FlagType.NO_FLAGS;
bool want_list = false;
bool want_static_lib_list = ENABLE_INDIRECT_DEPS;
bool want_short_errors = false;
bool want_uninstalled = false;
string variable_name;
bool want_exists = false;
bool want_provides = false;
bool want_requires = false;
bool want_requires_private = false;
bool want_validate = false;
string required_atleast_version;
string required_exact_version;
string required_max_version;
string required_pkgconfig_version;
bool want_silence_errors = false;
bool want_variable_list = false;
bool want_debug_spew = false;
bool want_verbose_errors = false;
bool want_stdout_errors = false;
bool output_opt_set = false;

bool vercmp_opt_set = false;

void debug_spew(const char *format, ...) {
    /*
    va_list args;
    FILE* stream;

    if(!format) {
        throw "NULL format string given to debug_spew.";
    }

    if(!want_debug_spew)
        return;

    if(want_stdout_errors)
        stream = stdout;
    else
        stream = stderr;

    va_start(args, format);
    vfprintf(stream, format, args);
    va_end(args);

    fflush(stream);
*/
}

void verbose_error(const string format, ...) {
    writeln(format);
    /*
    va_list args;
    FILE* stream = want_stdout_errors ? stdout : stderr;

    assert(format);

    if(!want_verbose_errors)
        return;

    va_start(args, format);
    vfprintf(stream, format, args);
    va_end(args);
    fflush(stream);
*/
}



static bool pkg_uninstalled(const Package pkg) {
    /* See if > 0 pkgs were uninstalled */

    if(pkg.uninstalled) {
        return true;
    }

    foreach(pkg_name; pkg.requires) {
        auto pkg_ = packages[pkg_name];
        if(pkg_uninstalled(pkg_)) {
            return true;
        }
    }

    return false;
}

void print_list_data(ref string data, void * user_data) {
    writefln("%s\n", data);
}

static void init_pc_path() {
/*
#ifdef _WIN32
    char *instdir, *lpath, *shpath;

    instdir = g_win32_get_package_installation_directory_of_module (null);
    if (instdir == null)
    {
        // This only happens when GetModuleFilename() fails. If it does, that
        // failure should be investigated and fixed.
        debug_spew ("g_win32_get_package_installation_directory_of_module failed\n");
        return;
    }

    lpath = g_build_filename (instdir, "lib", "pkgconfig", null);
    shpath = g_build_filename (instdir, "share", "pkgconfig", null);
    pkg_config_pc_path = g_strconcat (lpath, SEARCHPATH_SEPARATOR_S, shpath,
            null);
    g_free (instdir);
    g_free (lpath);
    g_free (shpath);
#else
*/
    pkg_config_pc_path = PKG_CONFIG_PC_PATH;
/*
#endif
*/
}

static bool process_package_args(const ref string cmdline, ref Package[] packages, ref File log) {
    bool success = true;

    auto reqs = parse_module_list(null, cmdline, "(command line arguments)");
    if(reqs.length == 0 && !cmdline.length == 0) {
        stderr.write("Must specify package names on the command line\n");
        return false;
    }
    string foo;
    foreach(ver; reqs) {
        Package req;

        /* override requested versions with cmdline options */
        if(required_exact_version != "") {
            ver.comparison = ComparisonType.EQUAL;
            ver.version_ = required_exact_version;
        } else if(required_atleast_version != "") {
            ver.comparison = ComparisonType.GREATER_THAN_EQUAL;
            ver.version_ = required_atleast_version;
        } else if(required_max_version != "") {
            ver.comparison = ComparisonType.LESS_THAN_EQUAL;
            ver.version_ = required_max_version;
        }

        if(want_short_errors)
            req = get_package_quiet(ver.name);
        else
            req = get_package(ver.name);

        if(!log.error()) {
            if(req.empty())
                log.writef("%s NOT-FOUND\n", ver.name);
            else
                log.writef("%s %s %s\n", ver.name, comparison_to_str(ver.comparison),
                        (ver.version_.length==0) ? "(null)" : ver.version_);
        }

        if(req.empty()) {
            success = false;
            verbose_error("No package '%s' found\n", ver.name);
            continue;
        }

        if(!version_test(ver.comparison, req.version_, ver.version_)) {
            success = false;
            verbose_error("Requested '%s %s %s' but version of %s is %s\n", ver.name,
                    comparison_to_str(ver.comparison), ver.version_, req.name, req.version_);
            if(!req.url.empty())
                verbose_error("You may find new versions of %s at %s\n", req.name, req.url);
            continue;
        }

        packages ~= req;
    }

    return success;
}

immutable int OPTION_FLAG_NO_ARG=1;
immutable int OPTION_FLAG_REVERSE=2;

enum OptionArg {
    OPTION_ARG_NONE,
    OPTION_ARG_CALLBACK,
    OPTION_ARG_STRING,
};



void version_callback(string option, string value) {
    if(option == "atleast-version") {
        required_atleast_version = value;
        want_exists = true;
        vercmp_opt_set = true;
    } else if(option == "exact-version") {
        required_exact_version = value;
        want_exists = true;
        vercmp_opt_set = true;
    } else if(option == "max-version") {
        required_max_version = value;
        want_exists = true;
        vercmp_opt_set = true;
    } else {
        assert(false);
    }
}

void type_callback(string opt) {
    if(opt == "libs")
        pkg_flags |= FlagType.LIBS_ANY;
    else if(opt == "libs-only-l")
        pkg_flags |= FlagType.LIBS_l;
    else if(opt == "libs-only-other")
        pkg_flags |= FlagType.LIBS_OTHER;
    else if(opt == "libs-only-L")
        pkg_flags |= FlagType.LIBS_L;
    else if(opt == "cflags")
        pkg_flags |= FlagType.CFLAGS_ANY;
    else if(opt == "cflags-only-I")
        pkg_flags |= FlagType.CFLAGS_I;
    else if(opt == "cflags-only-other")
        pkg_flags |= FlagType.CFLAGS_OTHER;
    else
        assert(false);
}

void define_variable_cb(string varname, string varval) {
}

void define_prefix_cb(string name) {
    if(name == "define-prefix") {
        define_prefix = true;
    } else if(name == "dont-define-prefix") {
        define_prefix = false;
    } else {
        assert(false);
    }
}

string[] parse_cmd_args(string[] args) {
    import std.getopt;
    auto helpInformation = getopt(
        args,
        "version", "output version of pkg-config", &want_my_version,
        "modversion", "output version for package", &want_version,
        "atleast-pkgconfig-version", "require given version of pkg-config", &required_pkgconfig_version,
        "libs", "output all linker flags", &type_callback,
        "static", "output linker flags for static linking", &want_static_lib_list,
        "short-errors", "print short errors", &want_short_errors,
        "libs-only-l", "output -l flags", &type_callback,
        "libs-only-other", "output other libs (e.g. -pthread)", &type_callback,
        "libs-only-L", "output -L flags", &type_callback,
        "cflags", "output all pre-processor and compiler flags", &type_callback,
        "cflags-only-I", "output -I flags", &type_callback,
        "cflags-only-other", "output cflags not covered by the cflags-only-I option", &type_callback,
        "variable", "get the value of variable named NAME", &variable_name,
        "define-variable", "set variable NAME to VALUE", &define_variable_cb,
        "exists", "return 0 if the module(s) exist", &want_exists,
        "print-variables", "output list of variables defined by the module", &want_variable_list,
        "uninstalled", "return 0 if the uninstalled version of one or more module(s) or their dependencies will be used", &want_uninstalled,
        "atleast-version", "return 0 if the module is at least version VERSION", &version_callback,
        "exact-version", "return 0 if the module is at exactly version VERSION", &version_callback,
        "max-version", "return 0 if the module is at no newer than version VERSION", &version_callback,
        "list-all", "list all known packages", &want_list,
        "debug", "show verbose debug information", &want_debug_spew,
        "print-errors", "show verbose information about missing or conflicting packages (default unless --exists or --atleast/exact/max-version given on the command line)", &want_verbose_errors,
        "silence-errors", "be silent about errors (default when --exists or --atleast/exact/max-version given on the command line)", &want_silence_errors,
        "errors-to-stdout", "print errors from --print-errors to stdout not stderr", &want_stdout_errors,
        "print-provides", "print which packages the package provides", &want_provides,
        "print-requires", "print which packages the package requires", &want_requires,
        "print-requires-private", "print which packages the package requires for static linking", &want_requires_private,
        "validate", "validate a package's .pc file", &want_validate,
        "define-prefix", "try to override the value of prefix for each .pc file found with a guesstimated value based on the location of the .pc file", &define_prefix_cb,
        "dont-define-prefix", "don't try to override the value of prefix for each .pc file found with a guesstimated value based on the location of the .pc file", &define_prefix_cb,
        "prefix-variable", "set the name of the variable that pkg-config automatically sets",   &prefix_variable,
    );
    if(helpInformation.helpWanted) {
        defaultGetoptPrinter("Usage:
  pkg-config [OPTION?]

Help Options:
  -h, --help                              Show help options

Application Options:", helpInformation.options);
        exit(0);
    }
    return args[1..$]; // Remove command name.
}



int main(string[] argv) {
    import core.stdc.stdlib: getenv;
    string str;
    Package[] package_list;
    string search_path;
    string pcbuilddir;
    bool need_newline;
    File log;

    /* This is here so that we get debug spew from the start,
     * during arg parsing
     */
    if(getenv("PKG_CONFIG_DEBUG_SPEW")) {
        want_debug_spew = true;
        want_verbose_errors = true;
        want_silence_errors = false;
        debug_spew("PKG_CONFIG_DEBUG_SPEW variable enabling debug spew\n");
    }

    /* Get the built-in search path */
    init_pc_path();
    if(pkg_config_pc_path == "") {
        /* Even when we override the built-in search path, we still use it later
         * to add pc_path to the virtual pkg-config package.
         */
        verbose_error("Failed to get default search path\n");
        exit(1);
    }

    search_path = to!string(getenv("PKG_CONFIG_PATH"));
    if(search_path.length != 0) {
        add_search_dirs(to!string(search_path), SEARCHPATH_SEPARATOR);
    }
    if(getenv("PKG_CONFIG_LIBDIR") != null) {
        add_search_dirs(to!string(getenv("PKG_CONFIG_LIBDIR")), SEARCHPATH_SEPARATOR);
    } else {
        add_search_dirs(pkg_config_pc_path, SEARCHPATH_SEPARATOR);
    }

    auto val = getenv("PKG_CONFIG_SYSROOT_DIR");
    if(val) {
        pcsysrootdir = to!string(val);
        define_global_variable("pc_sysrootdir", pcsysrootdir);
    } else {
        define_global_variable("pc_sysrootdir", "/");
    }

    auto fff = getenv("PKG_CONFIG_TOP_BUILD_DIR");
    if(fff) {
        pcbuilddir = to!string(pcbuilddir);
        define_global_variable("pc_top_builddir", pcbuilddir);
    } else {
        /* Default appropriate for automake */
        define_global_variable("pc_top_builddir", "$(top_builddir)");
    }

    if(getenv("PKG_CONFIG_DISABLE_UNINSTALLED")) {
        debug_spew("disabling auto-preference for uninstalled packages\n");
        disable_uninstalled = true;
    }

    /* Parse options */
    string[] remaining = parse_cmd_args(argv);
    /* If no output option was set, then --exists is the default. */
    if(!output_opt_set) {
        debug_spew("no output option set, defaulting to --exists\n");
        want_exists = true;
    }

    /* Error printing is determined as follows:
     *     - for --exists, --*-version, --list-all and no options at all,
     *       it's off by default and --print-errors will turn it on
     *     - for all other output options, it's on by default and
     *       --silence-errors can turn it off
     */
    if(want_exists || want_list) {
        debug_spew("Error printing disabled by default due to use of output " ~
                "options --exists, --atleast/exact/max-version, " ~
                "--list-all or no output option at all. Value of " ~
                "--print-errors: %d\n", want_verbose_errors);

        /* Leave want_verbose_errors unchanged, reflecting --print-errors */
    } else {
        debug_spew("Error printing enabled by default due to use of output " ~
                "options besides --exists, --atleast/exact/max-version or " ~
                "--list-all. Value of --silence-errors: %d\n", want_silence_errors);

        if(want_silence_errors && getenv("PKG_CONFIG_DEBUG_SPEW") == null)
            want_verbose_errors = false;
        else
            want_verbose_errors = true;
    }

    if(want_verbose_errors)
        debug_spew("Error printing enabled\n");
    else
        debug_spew("Error printing disabled\n");

    if(want_static_lib_list)
        enable_private_libs();
    else
        disable_private_libs();

    /* honor Requires.private if any Cflags are requested or any static
     * libs are requested */

    if((pkg_flags & FlagType.CFLAGS_ANY) || want_requires_private || want_exists
            || (want_static_lib_list && (pkg_flags & FlagType.LIBS_ANY)))
        enable_requires_private();

    /* ignore Requires if no Cflags or Libs are requested */

    if(pkg_flags == 0 && !want_requires && !want_exists)
        disable_requires();

    /* Allow errors in .pc files when listing all. */
    if(want_list)
        parse_strict = false;

    if(want_my_version) {
        writeln(VERSION);
        return 0;
    }

    if(!required_pkgconfig_version.empty()) {
        if(compare_versions(VERSION, required_pkgconfig_version) >= 0)
            return 0;
        else
            return 1;
    }

    package_init(want_list);

    if(want_list) {
        print_package_list();
        return 0;
    }

    /* Collect packages from remaining args */
    foreach(s; remaining) {
        str ~= s;
        str ~= " ";
    }

    str = chomp(str);

    if(getenv("PKG_CONFIG_LOG") != null) {
        auto lfname = to!string(getenv("PKG_CONFIG_LOG"));
        log = File(lfname, "a");
    }

    /* find and parse each of the packages specified */
    if(!process_package_args(str, package_list, log))
        return 1;

    if(!log.error())
        log.close();

    // HACK, not correct.
    if(pkg_flags != FlagType.NO_FLAGS) {
        want_exists = false;
    }
    /* If the user just wants to check package existence or validate its .pc
     * file, we're all done. */
    if(want_exists || want_validate)
        return 0;

    if(want_variable_list) {
        foreach(pkg; package_list) {
            if(pkg.vars.length != 0) {
                string[] keys;
                foreach(k ,v; pkg.vars) {
                    keys ~= k;
                }
                /* Sort variables for consistent output */
                keys.sort();
                foreach(i; keys) {
                    print_list_data(i, null);
                }
            }
            if(pkg.key.length == 0)
                writeln("");
        }
        need_newline = false;
    }

    if(want_uninstalled) {
        /* See if > 0 pkgs (including dependencies recursively) were uninstalled */
        foreach(pkg; package_list) {

            if(pkg_uninstalled(pkg))
                return 0;
        }

        return 1;
    }

    if(want_version) {
        foreach(pkg; package_list) {
            writeln(pkg.version_);
        }
    }

    if(want_provides) {
        foreach(pkg; package_list) {
            auto key = pkg.key;
            while(key.length > 0 && key[0] == '/') {
                key = key[1 .. key.length];
            }
            if(key.length == 0)
                writeln("%s = %s", key, pkg.version_);
        }
    }

    if(want_requires) {
        foreach(pkg; package_list) {
            /* process Requires: */
            foreach(req_name; pkg.requires) {
                if(!(req_name in pkg.required_versions) || (pkg.required_versions[req_name].comparison == ComparisonType.ALWAYS_MATCH)) {
                    writeln(req_name);
                } else {
                    writeln("%s %s %s", req_name,
                            comparison_to_str(pkg.required_versions[req_name].comparison),
                            pkg.required_versions[req_name].version_);
                }
            }
        }
    }
    if(want_requires_private) {
        foreach(pkg; package_list) {
            /* process Requires.private: */
            foreach(req_name; pkg.requires_private) {
                bool do_break = false;
                foreach(i; pkg.requires) {
                    if(i == req_name) {
                        do_break = true;
                        break;
                    }
                }
                if(do_break) {
                    continue;
                }
                if((!(req_name in pkg.required_versions) || (pkg.required_versions[req_name].comparison == ComparisonType.ALWAYS_MATCH)))
                    writeln(req_name);
                else
                    writeln("%s %s %s", req_name,
                            comparison_to_str(pkg.required_versions[req_name].comparison),
                            pkg.required_versions[req_name].version_);
            }
        }
    }

    /* Print all flags; then print a newline at the end. */
    need_newline = false;

    if(variable_name.length > 0) {
        auto varname = packages_get_var(package_list, variable_name);
        write(varname);
        need_newline = true;
    }

    if(pkg_flags != 0) {
        string flags = packages_get_flags(package_list, pkg_flags);
        write(flags);
        need_newline = true;
    }

    if(need_newline)
        writeln("");

    return 0;
}
