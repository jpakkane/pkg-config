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

#include "config.h"

#include "utils.h"
#include "pkg.h"
#include "parse.h"

#include<cassert>

#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <stdio.h>

#include<algorithm>

#ifdef _WIN32
#define STRICT
#include <windows.h>
#undef STRICT
#endif

#include<glib.h>

char *pcsysrootdir = NULL;
const char *pkg_config_pc_path = NULL;

static bool want_my_version = false;
static bool want_version = false;
static FlagType pkg_flags = 0;
static bool want_list = false;
static bool want_static_lib_list = ENABLE_INDIRECT_DEPS;
static bool want_short_errors = false;
static bool want_uninstalled = false;
static std::string variable_name;
static bool want_exists = false;
static bool want_provides = false;
static bool want_requires = false;
static bool want_requires_private = false;
static bool want_validate = false;
static std::string required_atleast_version;
static std::string required_exact_version;
static std::string required_max_version;
static char *required_pkgconfig_version = nullptr;
static bool want_silence_errors = false;
static bool want_variable_list = false;
static bool want_debug_spew = false;
static bool want_verbose_errors = false;
static bool want_stdout_errors = false;
static bool output_opt_set = false;

// FIXME, should be somewhere saner.
extern std::unordered_map<std::string, Package> packages;

void debug_spew(const char *format, ...) {
    va_list args;
    char *str;
    FILE* stream;

    g_return_if_fail(format != NULL);

    if(!want_debug_spew)
        return;

    va_start(args, format);
    str = g_strdup_vprintf(format, args);
    va_end(args);

    if(want_stdout_errors)
        stream = stdout;
    else
        stream = stderr;

    fputs(str, stream);
    fflush(stream);

    g_free(str);
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

static bool define_variable_cb(const char *opt, const char *arg, gpointer data, GError **error) {
    std::string input(arg);
    std::string::size_type p=0;
    while(p<input.size() && isspace(input[p]))
        ++p;

    const std::string::size_type name_start = p;
    while(p<input.size() && input[p] != '=' && input[p] != ' ')
        ++p;

    auto varname = input.substr(name_start, p-name_start);
    while(p<input.size() && (input[p] == '=' || input[p] == ' ')) {
        ++p;
    }

    if(p == input.size()) {
        fprintf(stderr, "--define-variable argument does not have a value "
                "for the variable\n");
        exit(1);
    }

    auto varval = input.substr(p, std::string::npos);
    define_global_variable(varname, varval);

    return true;
}

static bool output_opt_cb(const char *opt, const char *arg, gpointer data, GError **error) {
    static bool vercmp_opt_set = false;

    /* only allow one output mode, with a few exceptions */
    if(output_opt_set) {
        bool bad_opt = true;

        /* multiple flag options (--cflags --libs-only-l) allowed */
        if(pkg_flags != 0
                && (strcmp(opt, "--libs") == 0 || strcmp(opt, "--libs-only-l") == 0
                        || strcmp(opt, "--libs-only-other") == 0 || strcmp(opt, "--libs-only-L") == 0
                        || strcmp(opt, "--cflags") == 0 || strcmp(opt, "--cflags-only-I") == 0
                        || strcmp(opt, "--cflags-only-other") == 0))
            bad_opt = false;

        /* --print-requires and --print-requires-private allowed */
        if((want_requires && strcmp(opt, "--print-requires-private") == 0)
                || (want_requires_private && strcmp(opt, "--print-requires") == 0))
            bad_opt = false;

        /* --exists allowed with --atleast/exact/max-version */
        if(want_exists && !vercmp_opt_set
                && (strcmp(opt, "--atleast-version") == 0 || strcmp(opt, "--exact-version") == 0
                        || strcmp(opt, "--max-version") == 0))
            bad_opt = false;

        if(bad_opt) {
            fprintf(stderr, "Ignoring incompatible output option \"%s\"\n", opt);
            fflush(stderr);
            return true;
        }
    }

    if(strcmp(opt, "--version") == 0)
        want_my_version = true;
    else if(strcmp(opt, "--modversion") == 0)
        want_version = true;
    else if(strcmp(opt, "--libs") == 0)
        pkg_flags |= LIBS_ANY;
    else if(strcmp(opt, "--libs-only-l") == 0)
        pkg_flags |= LIBS_l;
    else if(strcmp(opt, "--libs-only-other") == 0)
        pkg_flags |= LIBS_OTHER;
    else if(strcmp(opt, "--libs-only-L") == 0)
        pkg_flags |= LIBS_L;
    else if(strcmp(opt, "--cflags") == 0)
        pkg_flags |= CFLAGS_ANY;
    else if(strcmp(opt, "--cflags-only-I") == 0)
        pkg_flags |= CFLAGS_I;
    else if(strcmp(opt, "--cflags-only-other") == 0)
        pkg_flags |= CFLAGS_OTHER;
    else if(strcmp(opt, "--variable") == 0)
        variable_name = arg;
    else if(strcmp(opt, "--exists") == 0)
        want_exists = true;
    else if(strcmp(opt, "--print-variables") == 0)
        want_variable_list = true;
    else if(strcmp(opt, "--uninstalled") == 0)
        want_uninstalled = true;
    else if(strcmp(opt, "--atleast-version") == 0) {
        required_atleast_version = arg;
        want_exists = true;
        vercmp_opt_set = true;
    } else if(strcmp(opt, "--exact-version") == 0) {
        required_exact_version = arg;
        want_exists = true;
        vercmp_opt_set = true;
    } else if(strcmp(opt, "--max-version") == 0) {
        required_max_version = arg;
        want_exists = true;
        vercmp_opt_set = true;
    } else if(strcmp(opt, "--list-all") == 0)
        want_list = true;
    else if(strcmp(opt, "--print-provides") == 0)
        want_provides = true;
    else if(strcmp(opt, "--print-requires") == 0)
        want_requires = true;
    else if(strcmp(opt, "--print-requires-private") == 0)
        want_requires_private = true;
    else if(strcmp(opt, "--validate") == 0)
        want_validate = true;
    else
        return false;

    output_opt_set = true;
    return true;
}

static bool pkg_uninstalled(const Package &pkg) {
    /* See if > 0 pkgs were uninstalled */

    if(pkg.uninstalled)
        return true;

    for(const std::string &pkg_name : pkg.requires) {
        auto pkg = packages[pkg_name];
        if(pkg_uninstalled(pkg))
            return true;
    }

    return false;
}

void print_list_data(const char *data, gpointer user_data) {
    g_print("%s\n", data);
}

static void init_pc_path(void) {
#ifdef G_OS_WIN32
    char *instdir, *lpath, *shpath;

    instdir = g_win32_get_package_installation_directory_of_module (NULL);
    if (instdir == NULL)
    {
        /* This only happens when GetModuleFilename() fails. If it does, that
         * failure should be investigated and fixed.
         */
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
    pkg_config_pc_path = PKG_CONFIG_PC_PATH;
#endif
}

static bool process_package_args(const std::string &cmdline, std::vector<Package> *packages, FILE *log) {
    bool success = true;

    auto reqs = parse_module_list(NULL, cmdline, "(command line arguments)");
    if(reqs.empty()) {
        fprintf(stderr, "Must specify package names on the command line\n");
        fflush(stderr);
        return false;
    }

    for(auto &ver : reqs) {
        Package req;

        /* override requested versions with cmdline options */
        if(!required_exact_version.empty()) {
            ver.comparison = EQUAL;
            ver.version = required_exact_version;
        } else if(!required_atleast_version.empty()) {
            ver.comparison = GREATER_THAN_EQUAL;
            ver.version = required_atleast_version;
        } else if(!required_max_version.empty()) {
            ver.comparison = LESS_THAN_EQUAL;
            ver.version = required_max_version;
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
                        (ver.version.empty()) ? "(null)" : ver.version.c_str());
        }

        if(req.empty()) {
            success = false;
            verbose_error("No package '%s' found\n", ver.name.c_str());
            continue;
        }

        if(!version_test(ver.comparison, req.version.c_str(), ver.version.c_str())) {
            success = false;
            verbose_error("Requested '%s %s %s' but version of %s is %s\n", ver.name.c_str(),
                    comparison_to_str(ver.comparison).c_str(), ver.version.c_str(), req.name.c_str(), req.version.c_str());
            if(!req.url.empty())
                verbose_error("You may find new versions of %s at %s\n", req.name.c_str(), req.url.c_str());
            continue;
        }

        packages->push_back(req);
    }

    return success;
}

static const GOptionEntry options_table[] = { { "version", 0, G_OPTION_FLAG_NO_ARG, G_OPTION_ARG_CALLBACK,
        reinterpret_cast<void*>(&output_opt_cb), "output version of pkg-config", NULL }, { "modversion", 0,
        G_OPTION_FLAG_NO_ARG, G_OPTION_ARG_CALLBACK, reinterpret_cast<void*>(&output_opt_cb),
        "output version for package", NULL }, { "atleast-pkgconfig-version", 0, 0, G_OPTION_ARG_STRING,
        &required_pkgconfig_version, "require given version of pkg-config", "VERSION" }, { "libs", 0,
        G_OPTION_FLAG_NO_ARG, G_OPTION_ARG_CALLBACK, reinterpret_cast<void*>(&output_opt_cb), "output all linker flags",
        NULL }, { "static", 0, 0, G_OPTION_ARG_NONE, &want_static_lib_list, "output linker flags for static linking",
        NULL }, { "short-errors", 0, 0, G_OPTION_ARG_NONE, &want_short_errors, "print short errors", NULL }, {
        "libs-only-l", 0, G_OPTION_FLAG_NO_ARG, G_OPTION_ARG_CALLBACK, reinterpret_cast<void*>(&output_opt_cb),
        "output -l flags", NULL }, { "libs-only-other", 0, G_OPTION_FLAG_NO_ARG, G_OPTION_ARG_CALLBACK,
        reinterpret_cast<void*>(&output_opt_cb), "output other libs (e.g. -pthread)", NULL }, { "libs-only-L", 0,
        G_OPTION_FLAG_NO_ARG, G_OPTION_ARG_CALLBACK, reinterpret_cast<void*>(&output_opt_cb), "output -L flags", NULL },
        { "cflags", 0, G_OPTION_FLAG_NO_ARG, G_OPTION_ARG_CALLBACK, reinterpret_cast<void*>(&output_opt_cb),
                "output all pre-processor and compiler flags", NULL }, { "cflags-only-I", 0, G_OPTION_FLAG_NO_ARG,
                G_OPTION_ARG_CALLBACK, reinterpret_cast<void*>(&output_opt_cb), "output -I flags", NULL }, {
                "cflags-only-other", 0, G_OPTION_FLAG_NO_ARG, G_OPTION_ARG_CALLBACK,
                reinterpret_cast<void*>(&output_opt_cb), "output cflags not covered by the cflags-only-I option",
                NULL }, { "variable", 0, 0, G_OPTION_ARG_CALLBACK, reinterpret_cast<void*>(&output_opt_cb),
                "get the value of variable named NAME", "NAME" }, { "define-variable", 0, 0, G_OPTION_ARG_CALLBACK,
                reinterpret_cast<void*>(&define_variable_cb), "set variable NAME to VALUE", "NAME=VALUE" }, { "exists",
                0, G_OPTION_FLAG_NO_ARG, G_OPTION_ARG_CALLBACK, reinterpret_cast<void*>(&output_opt_cb),
                "return 0 if the module(s) exist", NULL }, { "print-variables", 0, G_OPTION_FLAG_NO_ARG,
                G_OPTION_ARG_CALLBACK, reinterpret_cast<void*>(&output_opt_cb),
                "output list of variables defined by the module", NULL }, { "uninstalled", 0, G_OPTION_FLAG_NO_ARG,
                G_OPTION_ARG_CALLBACK, reinterpret_cast<void*>(&output_opt_cb),
                "return 0 if the uninstalled version of one or more "
                        "module(s) or their dependencies will be used", NULL }, { "atleast-version", 0, 0,
                G_OPTION_ARG_CALLBACK, reinterpret_cast<void*>(&output_opt_cb),
                "return 0 if the module is at least version VERSION", "VERSION" }, { "exact-version", 0, 0,
                G_OPTION_ARG_CALLBACK, reinterpret_cast<void*>(&output_opt_cb),
                "return 0 if the module is at exactly version VERSION", "VERSION" }, { "max-version", 0, 0,
                G_OPTION_ARG_CALLBACK, reinterpret_cast<void*>(&output_opt_cb),
                "return 0 if the module is at no newer than version VERSION", "VERSION" }, { "list-all", 0,
                G_OPTION_FLAG_NO_ARG, G_OPTION_ARG_CALLBACK, reinterpret_cast<void*>(&output_opt_cb),
                "list all known packages", NULL }, { "debug", 0, 0, G_OPTION_ARG_NONE, &want_debug_spew,
                "show verbose debug information", NULL }, { "print-errors", 0, 0, G_OPTION_ARG_NONE,
                &want_verbose_errors, "show verbose information about missing or conflicting packages "
                        "(default unless --exists or --atleast/exact/max-version given on the "
                        "command line)", NULL }, { "silence-errors", 0, 0, G_OPTION_ARG_NONE, &want_silence_errors,
                "be silent about errors (default when --exists or "
                        "--atleast/exact/max-version given on the command line)", NULL }, { "errors-to-stdout", 0, 0,
                G_OPTION_ARG_NONE, &want_stdout_errors, "print errors from --print-errors to stdout not stderr", NULL },
        { "print-provides", 0, G_OPTION_FLAG_NO_ARG, G_OPTION_ARG_CALLBACK, reinterpret_cast<void*>(&output_opt_cb),
                "print which packages the package provides", NULL }, { "print-requires", 0, G_OPTION_FLAG_NO_ARG,
                G_OPTION_ARG_CALLBACK, reinterpret_cast<void*>(&output_opt_cb),
                "print which packages the package requires", NULL }, { "print-requires-private", 0,
                G_OPTION_FLAG_NO_ARG, G_OPTION_ARG_CALLBACK, reinterpret_cast<void*>(&output_opt_cb),
                "print which packages the package requires for static "
                        "linking", NULL }, { "validate", 0, G_OPTION_FLAG_NO_ARG, G_OPTION_ARG_CALLBACK,
                reinterpret_cast<void*>(&output_opt_cb), "validate a package's .pc file", NULL }, { "define-prefix", 0,
                0, G_OPTION_ARG_NONE, &define_prefix,
                "try to override the value of prefix for each .pc file found with a "
                        "guesstimated value based on the location of the .pc file", NULL }, { "dont-define-prefix", 0,
                G_OPTION_FLAG_REVERSE, G_OPTION_ARG_NONE, &define_prefix,
                "don't try to override the value of prefix for each .pc "
                        "file found with a guesstimated value based on the location of the .pc "
                        "file", NULL }, { "prefix-variable", 0, 0, G_OPTION_ARG_STRING, &prefix_variable,
                "set the name of the variable that pkg-config automatically sets", "PREFIX" },
#ifdef G_OS_WIN32
        {   "msvc-syntax", 0, 0, G_OPTION_ARG_NONE, &msvc_syntax,
            "output -l and -L flags for the Microsoft compiler (cl)", NULL},
#endif
        { NULL, 0, 0, G_OPTION_ARG_NONE, NULL, NULL, NULL } };

int main(int argc, char **argv) {
    std::string str;
    std::vector<Package > package_list;
    char *search_path;
    char *pcbuilddir;
    bool need_newline;
    FILE *log = NULL;
    GError *error = NULL;
    GOptionContext *opt_context;

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
    if(pkg_config_pc_path == NULL) {
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

    pcsysrootdir = getenv("PKG_CONFIG_SYSROOT_DIR");
    if(pcsysrootdir) {
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
    opt_context = g_option_context_new(NULL);
    g_option_context_add_main_entries(opt_context, options_table, NULL);
    if(!g_option_context_parse(opt_context, &argc, &argv, &error)) {
        fprintf(stderr, "%s\n", error->message);
        return 1;
    }

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
        debug_spew("Error printing disabled by default due to use of output "
                "options --exists, --atleast/exact/max-version, "
                "--list-all or no output option at all. Value of "
                "--print-errors: %d\n", want_verbose_errors);

        /* Leave want_verbose_errors unchanged, reflecting --print-errors */
    } else {
        debug_spew("Error printing enabled by default due to use of output "
                "options besides --exists, --atleast/exact/max-version or "
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

    if(pkg_flags & CFLAGS_ANY || want_requires_private || want_exists
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

    if(required_pkgconfig_version) {
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
    while(argc > 1) {
        argc--;
        argv++;

        str += *argv;
        str += " ";
    }

    g_option_context_free(opt_context);

    while(!str.empty() && isspace(str.front())) {
        str.erase(0, 1);
    }
    while(!str.empty() && isspace(str.back())) {
        str.erase(str.size()-1, 1);
    }

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
        for(const auto &pkg : package_list) {
            if(!pkg.vars.empty()) {
                std::vector<std::string> keys;
                for(const auto &i : pkg.vars) {
                    keys.push_back(i.first);
                }
                /* Sort variables for consistent output */
                std::sort(keys.begin(), keys.end());
                for(const auto &i : keys) {
                    print_list_data(i.c_str(), NULL);
                }
            }
            if(!pkg.empty())
                printf("\n");
        }
        need_newline = false;
    }

    if(want_uninstalled) {
        /* See if > 0 pkgs (including dependencies recursively) were uninstalled */
        for(const auto &pkg : package_list) {

            if(pkg_uninstalled(pkg))
                return 0;
        }

        return 1;
    }

    if(want_version) {
        for(const auto &pkg : package_list) {
            printf("%s\n", pkg.version.c_str());
        }
    }

    if(want_provides) {
        for(const auto &pkg : package_list) {
            const char *key;
            key = pkg.key.c_str();
            while(*key == '/')
                key++;
            if(strlen(key) > 0)
                printf("%s = %s\n", key, pkg.version.c_str());
        }
    }

    if(want_requires) {
        for(const auto &pkg : package_list) {
            /* process Requires: */
            for(const std::string &req_name : pkg.requires) {
                auto lookup = pkg.required_versions.find(req_name);
                if(lookup == pkg.required_versions.end() || (lookup->second.comparison == ALWAYS_MATCH))
                    printf("%s\n", req_name.c_str());
                else
                    printf("%s %s %s\n", req_name.c_str(),
                            comparison_to_str(lookup->second.comparison).c_str(),
                            lookup->second.version.c_str());
            }
        }
    }
    if(want_requires_private) {
        for(const auto &pkg : package_list) {
            /* process Requires.private: */
            for(const std::string req_name : pkg.requires_private) {
                if(std::find(pkg.requires.begin(), pkg.requires.end(), req_name) != pkg.requires.end())
                    continue;

                auto lookup = pkg.required_versions.find(req_name);
                if((lookup == pkg.required_versions.end()) || (lookup->second.comparison == ALWAYS_MATCH))
                    printf("%s\n", req_name.c_str());
                else
                    printf("%s %s %s\n", req_name.c_str(),
                            comparison_to_str(lookup->second.comparison).c_str(),
                            lookup->second.version.c_str());
            }
        }
    }

    /* Print all flags; then print a newline at the end. */
    need_newline = false;

    if(!variable_name.empty()) {
        auto varname = packages_get_var(package_list, variable_name);
        printf("%s", varname.c_str());
        need_newline = true;
    }

    if(pkg_flags != 0) {
        std::string flags = packages_get_flags(package_list, pkg_flags);
        printf("%s", flags.c_str());
        need_newline = true;
    }

    if(need_newline)
        printf("\n");

    return 0;
}
