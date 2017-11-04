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
import pkg: FlagType, Package;

string pcsysrootdir;
string pkg_config_pc_path;

static const bool ENABLE_INDIRECT_DEPS = true;

string VERSION;
static bool want_my_version = false;
static bool want_version = false;
static FlagType pkg_flags = cast(FlagType)0;
static bool want_list = false;
static bool want_static_lib_list = ENABLE_INDIRECT_DEPS;
static bool want_short_errors = false;
static bool want_uninstalled = false;
static string variable_name;
static bool want_exists = false;
static bool want_provides = false;
static bool want_requires = false;
static bool want_requires_private = false;
static bool want_validate = false;
static string required_atleast_version;
static string required_exact_version;
static string required_max_version;
static string required_pkgconfig_version;
static bool want_silence_errors = false;
static bool want_variable_list = false;
static bool want_debug_spew = false;
static bool want_verbose_errors = false;
static bool want_stdout_errors = false;
static bool output_opt_set = false;

// FIXME, should be somewhere saner.
//extern std::unordered_map<string, Package> packages;

void debug_spew(const char *format, ...) {
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

}

void verbose_error(const char *format, ...) {
    va_list args;
    FILE* stream = want_stdout_errors ? stdout : stderr;

    assert(format);

    if(!want_verbose_errors)
        return;

    va_start(args, format);
    vfprintf(stream, format, args);
    va_end(args);
    fflush(stream);

}

static bool define_variable_cb(string opt, string arg, void* data) {
    string input(arg);
    int p=0;
    while(p<input.size() && isspace(input[p]))
        ++p;

    const int name_start = p;
    while(p<input.size() && input[p] != '=' && input[p] != ' ')
        ++p;

    auto varname = input.substr(name_start, p-name_start);
    while(p<input.size() && (input[p] == '=' || input[p] == ' ')) {
        ++p;
    }

    if(p == input.size()) {
        fprintf(stderr, "--define-variable argument does not have a value " ~
                "for the variable\n");
        exit(1);
    }

    auto varval = input[p .. input.length];
    define_global_variable(varname, varval);

    return true;
}

static bool output_opt_cb(const char *opt, const char *arg, void */*data*/) {
    static bool vercmp_opt_set = false;

    /* only allow one output mode, with a few exceptions */
    if(output_opt_set) {
        bool bad_opt = true;

        /* multiple flag options (--cflags --libs-only-l) allowed */
        if(pkg_flags != 0
                && opt == "--libs" || opt == "--libs-only-l"
                        || opt == "--libs-only-other" || opt == "--libs-only-L"
                        || opt == "--cflags" || opt == "--cflags-only-I"
                        || opt == "--cflags-only-other")
            bad_opt = false;

        /* --print-requires and --print-requires-private allowed */
        if((want_requires && opt == "--print-requires-private")
                || (want_requires_private && opt == "--print-requires"))
            bad_opt = false;

        /* --exists allowed with --atleast/exact/max-version */
        if(want_exists && !vercmp_opt_set
                && (opt == "--atleast-version" || opt == "--exact-version"
                        || opt == "--max-version"))
            bad_opt = false;

        if(bad_opt) {
            fprintf(stderr, "Ignoring incompatible output option \"%s\"\n", opt);
            fflush(stderr);
            return true;
        }
    }

    if(opt == "--version")
        want_my_version = true;
    else if(opt == "--modversion")
        want_version = true;
    else if(opt == "--libs")
        pkg_flags |= LIBS_ANY;
    else if(opt == "--libs-only-l")
        pkg_flags |= LIBS_l;
    else if(opt == "--libs-only-other")
        pkg_flags |= LIBS_OTHER;
    else if(opt == "--libs-only-L")
        pkg_flags |= LIBS_L;
    else if(opt == "--cflags")
        pkg_flags |= CFLAGS_ANY;
    else if(opt == "--cflags-only-I")
        pkg_flags |= CFLAGS_I;
    else if(opt == "--cflags-only-other")
        pkg_flags |= CFLAGS_OTHER;
    else if(opt == "--variable")
        variable_name = arg;
    else if(opt == "--exists")
        want_exists = true;
    else if(opt == "--print-variables")
        want_variable_list = true;
    else if(opt = "--uninstalled")
        want_uninstalled = true;
    else if(opt == "--atleast-version") {
        required_atleast_version = arg;
        want_exists = true;
        vercmp_opt_set = true;
    } else if(opt == "--exact-version") {
        required_exact_version = arg;
        want_exists = true;
        vercmp_opt_set = true;
    } else if(opt == "--max-version") {
        required_max_version = arg;
        want_exists = true;
        vercmp_opt_set = true;
    } else if(opt == "--list-all")
        want_list = true;
    else if(opt == "--print-provides")
        want_provides = true;
    else if(opt == "--print-requires")
        want_requires = true;
    else if(opt == "--print-requires-private")
        want_requires_private = true;
    else if(opt == "--validate")
        want_validate = true;
    else
        return false;

    output_opt_set = true;
    return true;
}

static bool pkg_uninstalled(const Package pkg) {
    /* See if > 0 pkgs were uninstalled */

    if(pkg.uninstalled) {
        return true;
    }

    foreach(pkg_name; pkg.requires) {
        auto pkg = packages[pkg_name];
        if(pkg_uninstalled(pkg)) {
            return true;
        }
    }

    return false;
}

void print_list_data(const char *data, void * user_data) {
    writefln("%s\n", data);
}

static void init_pc_path() {
/*
#ifdef _WIN32
    char *instdir, *lpath, *shpath;

    instdir = g_win32_get_package_installation_directory_of_module (NULL);
    if (instdir == NULL)
    {
        // This only happens when GetModuleFilename() fails. If it does, that
        // failure should be investigated and fixed.
        debug_spew ("g_win32_get_package_installation_directory_of_module failed\n");
        return;
    }

    lpath = g_build_filename (instdir, "lib", "pkgconfig", NULL);
    shpath = g_build_filename (instdir, "share", "pkgconfig", NULL);
    pkg_config_pc_path = g_strconcat (lpath, SEARCHPATH_SEPARATOR_S, shpath,
            NULL);
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

static bool process_package_args(const string cmdline, Package[] packages, File *log) {
    bool success = true;

    auto reqs = parse_module_list(NULL, cmdline, "(command line arguments)");
    if(reqs.empty() && !cmdline.empty()) {
        fprintf(stderr, "Must specify package names on the command line\n");
        fflush(stderr);
        return false;
    }

    foreach(ver; reqs) {
        Package req;

        /* override requested versions with cmdline options */
        if(!required_exact_version.empty()) {
            ver.comparison = EQUAL;
            ver.version_ = required_exact_version;
        } else if(!required_atleast_version.empty()) {
            ver.comparison = GREATER_THAN_EQUAL;
            ver.version_ = required_atleast_version;
        } else if(!required_max_version.empty()) {
            ver.comparison = LESS_THAN_EQUAL;
            ver.version_ = required_max_version;
        }

        if(want_short_errors)
            req = get_package_quiet(ver.name);
        else
            req = get_package(ver.name);

        if(log != NULL) {
            if(req.empty())
                fprintf(log, "%s NOT-FOUND\n", ver.name.c_str());
            else
                fprintf(log, "%s %s %s\n", ver.name.c_str(), comparison_to_str(ver.comparison).c_str(),
                        (ver.version_.length==0) ? "(null)" : ver.version_.c_str());
        }

        if(req.empty()) {
            success = false;
            verbose_error("No package '%s' found\n", ver.name.c_str());
            continue;
        }

        if(!version_test(ver.comparison, req.version_, ver.version_)) {
            success = false;
            verbose_error("Requested '%s %s %s' but version of %s is %s\n", ver.name.c_str(),
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

struct OptionEntry {
  const string long_name;
  char        short_name;
  int         flags;

  OptionArg   arg;
  void*     arg_data;

  const char *description;
  const char *arg_description;
};

bool function (const char *, const char *, void *) opt_cb;

static OptionEntry[] options_table = [
        { "version",                   0, OPTION_FLAG_NO_ARG, OPTION_ARG_CALLBACK, cast(void*)(&output_opt_cb), "output version of pkg-config", NULL },
        { "modversion",                0, OPTION_FLAG_NO_ARG, OPTION_ARG_CALLBACK, cast(void*)(&output_opt_cb), "output version for package", NULL },
        { "atleast-pkgconfig-version", 0, 0,                  OPTION_ARG_STRING,   &required_pkgconfig_version,             "require given version of pkg-config", "VERSION" },
        { "libs",                      0, OPTION_FLAG_NO_ARG, OPTION_ARG_CALLBACK, cast(void*)(&output_opt_cb), "output all linker flags", NULL },
        { "static",                    0, 0,                  OPTION_ARG_NONE,     &want_static_lib_list,                   "output linker flags for static linking", NULL },
        { "short-errors",              0, 0,                  OPTION_ARG_NONE,     &want_short_errors,                      "print short errors", NULL },
        { "libs-only-l",               0, OPTION_FLAG_NO_ARG, OPTION_ARG_CALLBACK, cast(void*)(&output_opt_cb), "output -l flags", NULL },
        { "libs-only-other",           0, OPTION_FLAG_NO_ARG, OPTION_ARG_CALLBACK, cast(void*)(&output_opt_cb), "output other libs (e.g. -pthread)", NULL },
        { "libs-only-L",               0, OPTION_FLAG_NO_ARG, OPTION_ARG_CALLBACK, cast(void*)(&output_opt_cb), "output -L flags", NULL },
        { "cflags",                    0, OPTION_FLAG_NO_ARG, OPTION_ARG_CALLBACK, cast(void*)(&output_opt_cb), "output all pre-processor and compiler flags", NULL },
        { "cflags-only-I",             0, OPTION_FLAG_NO_ARG, OPTION_ARG_CALLBACK, cast(void*)(&output_opt_cb), "output -I flags", NULL },
        { "cflags-only-other",         0, OPTION_FLAG_NO_ARG, OPTION_ARG_CALLBACK, cast(void*)(&output_opt_cb), "output cflags not covered by the cflags-only-I option", NULL },
        { "variable",                  0, 0,                  OPTION_ARG_CALLBACK, cast(void*)(&output_opt_cb), "get the value of variable named NAME", "NAME" },
        { "define-variable",           0, 0,                  OPTION_ARG_CALLBACK, cast(void*)(&define_variable_cb), "set variable NAME to VALUE", "NAME=VALUE" },
        { "exists",                    0, OPTION_FLAG_NO_ARG, OPTION_ARG_CALLBACK, cast(void*)(&output_opt_cb), "return 0 if the module(s) exist", NULL },
        { "print-variables",           0, OPTION_FLAG_NO_ARG, OPTION_ARG_CALLBACK, cast(void*)(&output_opt_cb), "output list of variables defined by the module", NULL },
        { "uninstalled",               0, OPTION_FLAG_NO_ARG, OPTION_ARG_CALLBACK, cast(void*)(&output_opt_cb), "return 0 if the uninstalled version of one or more module(s) or their dependencies will be used", NULL },
        { "atleast-version",           0, 0,                  OPTION_ARG_CALLBACK, cast(void*)(&output_opt_cb), "return 0 if the module is at least version VERSION", "VERSION" },
        { "exact-version",             0, 0,                  OPTION_ARG_CALLBACK, cast(void*)(&output_opt_cb), "return 0 if the module is at exactly version VERSION", "VERSION" },
        { "max-version",               0, 0,                  OPTION_ARG_CALLBACK, cast(void*)(&output_opt_cb), "return 0 if the module is at no newer than version VERSION", "VERSION" },
        { "list-all",                  0, OPTION_FLAG_NO_ARG, OPTION_ARG_CALLBACK, cast(void*)(&output_opt_cb), "list all known packages", NULL },
        { "debug",                     0, 0,                  OPTION_ARG_NONE,     &want_debug_spew,                        "show verbose debug information", NULL },
        { "print-errors",              0, 0,                  OPTION_ARG_NONE,     &want_verbose_errors,                    "show verbose information about missing or conflicting packages (default unless --exists or --atleast/exact/max-version given on the command line)", NULL },
        { "silence-errors",            0, 0,                  OPTION_ARG_NONE,     &want_silence_errors,                    "be silent about errors (default when --exists or --atleast/exact/max-version given on the command line)", NULL },
        { "errors-to-stdout",          0, 0,                  OPTION_ARG_NONE,     &want_stdout_errors,                     "print errors from --print-errors to stdout not stderr", NULL },
        { "print-provides",            0, OPTION_FLAG_NO_ARG, OPTION_ARG_CALLBACK, cast(void*)(&output_opt_cb), "print which packages the package provides", NULL },
        { "print-requires",            0, OPTION_FLAG_NO_ARG, OPTION_ARG_CALLBACK, cast(void*)(&output_opt_cb), "print which packages the package requires", NULL },
        { "print-requires-private",    0, OPTION_FLAG_NO_ARG, OPTION_ARG_CALLBACK, cast(void*)(&output_opt_cb), "print which packages the package requires for static linking", NULL },
        { "validate",                  0, OPTION_FLAG_NO_ARG, OPTION_ARG_CALLBACK, cast(void*)(&output_opt_cb), "validate a package's .pc file", NULL },
        { "define-prefix",             0, 0,                  OPTION_ARG_NONE,     &define_prefix,                          "try to override the value of prefix for each .pc file found with a guesstimated value based on the location of the .pc file", NULL },
        { "dont-define-prefix",        0, OPTION_FLAG_REVERSE, OPTION_ARG_NONE,    &define_prefix,                          "don't try to override the value of prefix for each .pc file found with a guesstimated value based on the location of the .pc file", NULL },
        { "prefix-variable",           0, 0,                  OPTION_ARG_STRING,   &prefix_variable,                        "set the name of the variable that pkg-config automatically sets", "PREFIX" },
/*
#ifdef _WIN32
        {   "msvc-syntax",             0, 0,                  OPTION_ARG_NONE,     &msvc_syntax,                            "output -l and -L flags for the Microsoft compiler (cl)", NULL},
#endif
*/
];

void print_help() {
    printf("Printing help is not implemented yet.\n");
    exit(0);
}

string[] parse_cmd_args(string[] argv) {
    string[] remaining;
    string work;
    for(int i=1; i<argv.size; ++i) { // skip program name
        string current = argv[i];
        if(current == "-h" || current == "--help") {
            print_help();
        }
        if(current.size < 3) {
            remaining ~= current;
            continue;
        }
        work = current[2..current.size];
        auto equal_sign = work.indexOf('=');
        string command, argument;
        if(equal_sign < 0) {
            command = work.substr[0 .. equal_sign];
            argument = work[equal_sign+1 .. work.size];
        } else {
            command = work;
        }
        bool match_found = false;
        foreach(const opt; options_table) {
            if(command == opt.long_name) {
                match_found = true;
                if(opt.arg == OPTION_ARG_STRING) {
                    if(argument.size == 0) {
                        argument = argv[++i];
                    }
                    string *ptr = cast(string*)(opt.arg_data);
                    *ptr = argument;
                } else if(opt.arg == OPTION_ARG_NONE) {
                    *cast(bool*)(opt.arg_data) = !(opt.flags & OPTION_FLAG_REVERSE);
                } else if(opt.arg == OPTION_ARG_CALLBACK) {
                    string optionstr = "--" + command;
                    if(!(opt.flags & OPTION_FLAG_NO_ARG)) {
                        if(argument.empty()) {
                            argument = argv[++i];
                        }
                    }
                    opt_cb cb = cast(opt_cb) (opt.arg_data);
                    (*cb)(optionstr.c_str(), argument.c_str(), nullptr);
                } else {
                    throw "Unknown option type.";
                }
                break;
            }
        }
        if(!match_found) {
            if(current[0] == '-') {
                fprintf(stderr, "Unknown option %s\n", current);
                exit(1);
            } else {
                remaining.push_back(current);
            }
        }

    }
    return remaining;
}

int main(string[] argv) {
    import core.stdc.stdlib: getenv;
    string str;
    Package[] package_list;
    string search_path;
    string pcbuilddir;
    bool need_newline;
    FILE *log = NULL;

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

    search_path = getenv("PKG_CONFIG_PATH");
    if(search_path) {
        add_search_dirs(search_path, SEARCHPATH_SEPARATOR);
    }
    if(getenv("PKG_CONFIG_LIBDIR") != NULL) {
        add_search_dirs(getenv("PKG_CONFIG_LIBDIR"), SEARCHPATH_SEPARATOR);
    } else {
        add_search_dirs(pkg_config_pc_path, SEARCHPATH_SEPARATOR);
    }

    auto val = getenv("PKG_CONFIG_SYSROOT_DIR");
    if(val) {
        pcsysrootdir = val;
        define_global_variable("pc_sysrootdir", pcsysrootdir);
    } else {
        define_global_variable("pc_sysrootdir", "/");
    }

    pcbuilddir = getenv("PKG_CONFIG_TOP_BUILD_DIR");
    if(pcbuilddir) {
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

        if(want_silence_errors && getenv("PKG_CONFIG_DEBUG_SPEW") == NULL)
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

    if((pkg_flags & CFLAGS_ANY) || want_requires_private || want_exists
            || (want_static_lib_list && (pkg_flags & LIBS_ANY)))
        enable_requires_private();

    /* ignore Requires if no Cflags or Libs are requested */

    if(pkg_flags == 0 && !want_requires && !want_exists)
        disable_requires();

    /* Allow errors in .pc files when listing all. */
    if(want_list)
        parse_strict = false;

    if(want_my_version) {
        printf("%s\n", VERSION);
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
        str += s;
        str += " ";
    }

    str = chomp(str);

    if(getenv("PKG_CONFIG_LOG") != NULL) {
        log = fopen(getenv("PKG_CONFIG_LOG"), "a");
        if(log == NULL) {
            fprintf(stderr, "Cannot open log file: %s\n", getenv("PKG_CONFIG_LOG"));
            exit(1);
        }
    }

    /* find and parse each of the packages specified */
    if(!process_package_args(str, &package_list, log))
        return 1;

    if(log != NULL)
        fclose(log);

    /* If the user just wants to check package existence or validate its .pc
     * file, we're all done. */
    if(want_exists || want_validate)
        return 0;

    if(want_variable_list) {
        foreach(pkg; package_list) {
            if(pkg.vars.length != 0) {
                string[] keys;
                foreach(i; pkg.vars) {
                    keys ~= i.first;
                }
                /* Sort variables for consistent output */
                keys.sort();
                foreach(i; keys) {
                    print_list_data(i, NULL);
                }
            }
            if(pkg.length == 0)
                printf("\n");
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
                auto lookup = pkg.required_versions.find(req_name);
                if(lookup == pkg.required_versions.end() || (lookup.second.comparison == ALWAYS_MATCH)) {
                    writeln(req_name);
                } else {
                    writeln("%s %s %s", req_name,
                            comparison_to_str(lookup.second.comparison),
                            lookup.second.version_);
                }
            }
        }
    }
    if(want_requires_private) {
        foreach(pkg; package_list) {
            /* process Requires.private: */
            foreach(req_name; pkg.requires_private) {
                if(req_name in pkg.requires) {
                    continue;
                }
                auto lookup = pkg.required_versions.find(req_name);
                if((lookup == pkg.required_versions.end()) || (lookup.second.comparison == ALWAYS_MATCH))
                    writeln(req_name);
                else
                    writeln("%s %s %s", req_name,
                            comparison_to_str(lookup.second.comparison),
                            lookup.second.version_);
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
