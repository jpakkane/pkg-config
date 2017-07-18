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

#include "pkg.h"
#include "parse.h"
#include "rpmvercmp.h"

#include <sys/types.h>
#include <string.h>
#include <errno.h>
#include <stdio.h>
#ifdef HAVE_UNISTD_H
#include <unistd.h>
#endif
#include <stdlib.h>
#include <ctype.h>

#include<algorithm>
#include <sstream>
#include<unordered_set>

static void verify_package(Package *pkg);

static std::unordered_map<std::string, Package*> packages;
static std::unordered_map<std::string, std::string> globals;
static std::vector<std::string> search_dirs;

bool disable_uninstalled = false;
bool ignore_requires = false;
bool ignore_requires_private = true;
bool ignore_private_libs = true;

void add_search_dir(const char *path) {
    search_dirs.push_back(path);
}

void add_search_dirs(const char *path_, const char separator) {
    std::string path(path_);
    std::stringstream ss;
    ss.str(path);
    std::string item;

    while(std::getline(ss, item, separator)) {
        debug_spew("Adding directory '%s' from PKG_CONFIG_PATH\n", item.c_str());
        add_search_dir(item.c_str());
    }
}

#ifdef G_OS_WIN32
/* Guard against .pc file being installed with UPPER CASE name */
# define FOLD(x) tolower(x)
# define FOLDCMP(a, b) g_ascii_strcasecmp (a, b)
#else
# define FOLD(x) (x)
# define FOLDCMP(a, b) strcmp (a, b)
#endif

#define EXT_LEN 3

static bool ends_in_dotpc(const char *str) {
    int len = strlen(str);

    if(len > EXT_LEN && str[len - 3] == '.' &&
    FOLD (str[len - 2]) == 'p' &&
    FOLD (str[len - 1]) == 'c')
        return true;
    else
        return false;
}

/* strlen ("-uninstalled") */
#define UNINSTALLED_LEN 12

bool name_ends_in_uninstalled(const char *str) {
    int len = strlen(str);

    if(len > UNINSTALLED_LEN &&
    FOLDCMP ((str + len - UNINSTALLED_LEN), "-uninstalled") == 0)
        return true;
    else
        return false;
}

static Package *
internal_get_package(const char *name, bool warn);

/* Look for .pc files in the given directory and add them into
 * locations, ignoring duplicates
 */
static void scan_dir(const char *dirname) {
    GDir *dir;
    const gchar *filename;

    int dirnamelen = strlen(dirname);
    /* Use a copy of dirname cause Win32 opendir doesn't like
     * superfluous trailing (back)slashes in the directory name.
     */
    char *dirname_copy = g_strdup(dirname);

    if(dirnamelen > 1 && dirname[dirnamelen - 1] == G_DIR_SEPARATOR) {
        dirnamelen--;
        dirname_copy[dirnamelen] = '\0';
    }
#ifdef G_OS_WIN32
    {
        gchar *p;
        /* Turn backslashes into slashes or
         * g_shell_parse_argv() will eat them when ${prefix}
         * has been expanded in parse_libs().
         */
        p = dirname;
        while (*p)
        {
            if (*p == '\\')
            *p = '/';
            p++;
        }
    }
#endif
    dir = g_dir_open(dirname_copy, 0, NULL);
    g_free(dirname_copy);

    if(!dir) {
        debug_spew("Cannot open directory '%s' in package search path: %s\n", dirname, g_strerror(errno));
        return;
    }

    debug_spew("Scanning directory '%s'\n", dirname);

    while((filename = g_dir_read_name(dir))) {
        char *path = g_build_filename(dirname, filename, NULL);
        internal_get_package(path, false);
        g_free(path);
    }
    g_dir_close(dir);
}

static Package *
add_virtual_pkgconfig_package(void) {
    Package *pkg = NULL;

    pkg = new Package();

    pkg->key = "pkg-config";
    pkg->version = VERSION;
    pkg->name = "pkg-config";
    pkg->description = "pkg-config is a system for managing compile/link flags for libraries";
    pkg->url = "http://pkg-config.freedesktop.org/";

    pkg->vars["pc_path"] = pkg_config_pc_path;

    debug_spew("Adding virtual 'pkg-config' package to list of known packages\n");
    packages[pkg->key] = pkg;

    return pkg;
}

void package_init(bool want_list) {

    if(want_list)
        std::for_each(search_dirs.begin(), search_dirs.end(), [] (const std::string &dir) {
            scan_dir(dir.c_str());
        });
    else
        /* Should not add virtual pkgconfig package when listing to be
         * compatible with old code that only listed packages from real
         * files */
        add_virtual_pkgconfig_package();
}

static Package *
internal_get_package(const char *name, bool warn) {
    Package *pkg = NULL;
    char *key = NULL;
    char *location = NULL;
    unsigned int path_position = 0;

    auto res = packages.find(name);

    if(res != packages.end())
        return res->second;

    debug_spew("Looking for package '%s'\n", name);

    /* treat "name" as a filename if it ends in .pc and exists */
    if(ends_in_dotpc(name)) {
        debug_spew("Considering '%s' to be a filename rather than a package name\n", name);
        location = g_strdup(name);
        key = g_strdup(name);
    } else {
        /* See if we should auto-prefer the uninstalled version */
        if(!disable_uninstalled && !name_ends_in_uninstalled(name)) {
            char *un;

            un = g_strconcat(name, "-uninstalled", NULL);

            pkg = internal_get_package(un, false);

            g_free(un);

            if(pkg) {
                debug_spew("Preferring uninstalled version of package '%s'\n", name);
                return pkg;
            }
        }

        for(const auto &dir : search_dirs) {
            path_position++;
            location = g_strdup_printf("%s%c%s.pc", dir.c_str(),
            G_DIR_SEPARATOR, name);
            if(g_file_test(location, G_FILE_TEST_IS_REGULAR))
                break;
            g_free(location);
            location = NULL;
        }

    }

    if(location == NULL) {
        if(warn)
            verbose_error("Package %s was not found in the pkg-config search path.\n"
                    "Perhaps you should add the directory containing `%s.pc'\n"
                    "to the PKG_CONFIG_PATH environment variable\n", name, name);

        return NULL;
    }

    if(key == NULL)
        key = g_strdup(name);
    else {
        /* need to strip package name out of the filename */
        key = g_path_get_basename(name);
        key[strlen(key) - EXT_LEN] = '\0';
    }

    debug_spew("Reading '%s' from file '%s'\n", name, location);
    pkg = parse_package_file(key, location, ignore_requires, ignore_private_libs, ignore_requires_private);
    g_free(key);

    if(pkg != NULL && strstr(location, "uninstalled.pc"))
        pkg->uninstalled = true;

    g_free(location);

    if(pkg == NULL) {
        debug_spew("Failed to parse '%s'\n", location);
        return NULL;
    }

    pkg->path_position = path_position;

    debug_spew("Path position of '%s' is %d\n", pkg->key.c_str(), pkg->path_position);

    debug_spew("Adding '%s' to list of known packages\n", pkg->key.c_str());
    packages[pkg->key] = pkg;

    /* pull in Requires packages */
    for(const auto &ver : pkg->requires_entries) {
        Package *req;

        debug_spew("Searching for '%s' requirement '%s'\n", pkg->key.c_str(), ver.name.c_str());
        req = internal_get_package(ver.name.c_str(), warn);
        if(req == NULL) {
            verbose_error("Package '%s', required by '%s', not found\n", ver.name.c_str(), pkg->key.c_str());
            exit(1);
        }

        pkg->required_versions[ver.name] = ver;
        pkg->requires.push_back(req);
    }

    /* pull in Requires.private packages */
    for(const auto &ver : pkg->requires_private_entries) {
        Package *req;

        debug_spew("Searching for '%s' private requirement '%s'\n", pkg->key.c_str(), ver.name.c_str());
        req = internal_get_package(ver.name.c_str(), warn);
        if(req == NULL) {
            verbose_error("Package '%s', required by '%s', not found\n", ver.name.c_str(), pkg->key.c_str());
            exit(1);
        }

        pkg->required_versions[ver.name] = ver;
        pkg->requires_private.push_back(req);
    }

    std::reverse(pkg->requires_private.begin(), pkg->requires_private.end());
    /* make requires_private include a copy of the public requires too */
    pkg->requires_private.insert(pkg->requires_private.begin(),
            pkg->requires.rbegin(),
            pkg->requires.rend());

//    pkg->requires = g_list_reverse(pkg->requires);
//    pkg->requires_private_ = g_list_reverse(pkg->requires_private_);

    verify_package(pkg);

    return pkg;
}

Package *
get_package(const char *name) {
    return internal_get_package(name, true);
}

Package *
get_package_quiet(const char *name) {
    return internal_get_package(name, false);
}

/* Strip consecutive duplicate arguments in the flag list. */
static std::vector<Flag>
flag_list_strip_duplicates(const std::vector<Flag> &list) {
    std::vector<Flag> result;

    if(list.empty()) {
        return result;
    }
    result.push_back(list.front());
    /* Start at the 2nd element of the list so we don't have to check for an
     * existing previous element. */
    for(size_t i=1; i<list.size(); ++i) {
        const Flag &cur = list[i];
        const Flag &prev = list[i-1];

        if(cur.type == prev.type && cur.arg == prev.arg) {
            /* Remove the duplicate flag from the list and move to the last
             * element to prepare for the next iteration. */
        } else {
            result.push_back(cur);
        }
    }

    return result;
}

static std::string
flag_list_to_string(const std::vector<Flag> &flags) {
    std::string str;

    for(const auto &flag : flags) {
        const std::string &tmpstr = flag.arg;

        if(pcsysrootdir != NULL && (flag.type & (CFLAGS_I | LIBS_L))) {
            /* Handle non-I Cflags like -isystem */
            if((flag.type & CFLAGS_I) && strncmp(tmpstr.c_str(), "-I", 2) != 0) {
                auto space_loc = tmpstr.find(' ');

                /* Ensure this has a separate arg */
                g_assert(space_loc != std::string::npos && space_loc < tmpstr.length()-1);
                str += tmpstr.substr(0, space_loc + 1);
                str += pcsysrootdir;
                str += tmpstr.substr(space_loc + 1);
            } else {
                str += '-';
                str += tmpstr[1];
                str += pcsysrootdir;
                str += tmpstr.substr(2);
            }
        } else {
            str += tmpstr;
        }
        str += ' ';
    }

    return str;
}

static int pathposcmp(gconstpointer a, gconstpointer b) {
    const Package *pa = static_cast<const Package*>(a);
    const Package *pb = static_cast<const Package*>(b);

    if(pa->path_position < pb->path_position)
        return -1;
    else if(pa->path_position > pb->path_position)
        return 1;
    else
        return 0;
}

static void spew_package_list(const char *name, const std::vector<Package*> &list) {
    debug_spew(" %s:", name);

    for(const auto &i : list) {
        debug_spew(" %s", i->key.c_str());
    }
    debug_spew("\n");
}

static GList *
packages_sort_by_path_position(GList *list) {
    return g_list_sort(list, pathposcmp);
}

/* Construct a topological sort of all required packages.
 *
 * This is a depth first search starting from the right.  The output 'listp' is
 * in reverse order, with the first node reached in the depth first search at
 * the end of the list.  Previously visited nodes are skipped.  The result is
 * a list of packages such that each packages is listed once and comes before
 * any package that it depends on.
 */
static void recursive_fill_list(Package *pkg, bool include_private, std::unordered_set<std::string> &visited, std::vector<Package*> &listp) {

    /*
     * If the package has already been visited, then it is already in 'listp' and
     * we can skip it. Additionally, this allows circular requires loops to be
     * broken.
     */
    auto found = visited.find(pkg->key);
    if(found != visited.end()) {
        debug_spew("Package %s already in requires chain, skipping\n", pkg->key.c_str());
        return;
    }
    /* record this package in the dependency chain */
    visited.insert(pkg->key);

    /* Start from the end of the required package list to maintain order since
     * the recursive list is built by prepending. */
    auto &tmp = include_private ? pkg->requires_private : pkg->requires;
    for(Package *p : tmp) {
        recursive_fill_list(p, include_private, visited, listp);
    }
    listp.insert(listp.begin(), pkg);
}

/* merge the flags from the individual packages */
static std::vector<Flag>
merge_flag_lists(const std::vector<Package*> &packages, FlagType type) {
    std::vector<Flag> merged;
    /* keep track of the last element to avoid traversing the whole list */
    for(const auto &i : packages) {
        std::vector<Flag> &flags = (type & LIBS_ANY) ? i->libs : i->cflags;
        for(const auto &f : flags) {
            if(f.type & type) {
                merged.push_back(f);
            }
        }
    }

    return merged;
}

static std::vector<Flag>
fill_list(GList *packages, FlagType type, bool in_path_order, bool include_private) {
    GList *tmp;
    std::vector<Package*> expanded;
    std::vector<Flag> flags;
    std::unordered_set<std::string> visited;

    /* Start from the end of the requested package list to maintain order since
     * the recursive list is built by prepending. */
    for(tmp = g_list_last(packages); tmp != NULL; tmp = g_list_previous(tmp))
        recursive_fill_list(static_cast<Package*>(tmp->data), include_private, visited, expanded);
    spew_package_list("post-recurse", expanded);

    if(in_path_order) {
        spew_package_list("original", expanded);
        std::stable_sort(expanded.begin(), expanded.end(), [] (const Package *pa, const Package *pb) {
            return pa->path_position < pb->path_position;
        });
        spew_package_list("  sorted", expanded);
    }

    flags = merge_flag_lists(expanded, type);

    return flags;
}

static GList *
add_env_variable_to_list(GList *list, const gchar *env) {
    gchar **values;
    gint i;

    values = g_strsplit(env, G_SEARCHPATH_SEPARATOR_S, 0);
    for(i = 0; values[i] != NULL; i++) {
        list = g_list_append(list, g_strdup(values[i]));
    }
    g_strfreev(values);

    return list;
}

/* Well known compiler include path environment variables. These are
 * used to find additional system include paths to remove. See
 * https://gcc.gnu.org/onlinedocs/gcc/Environment-Variables.html. */
static const gchar *gcc_include_envvars[] = { "CPATH", "C_INCLUDE_PATH", "CPP_INCLUDE_PATH",
NULL };

#ifdef G_OS_WIN32
/* MSVC include path environment variables. See
 * https://msdn.microsoft.com/en-us/library/73f9s62w.aspx. */
static const gchar *msvc_include_envvars[] = {
    "INCLUDE",
    NULL
};
#endif

static void verify_package(Package *pkg) {
    std::vector<Package*> requires;
    std::vector<RequiredVersion> conflicts;
    GList *system_directories = NULL;
    GList *iter;
    GList *system_dir_iter = NULL;
    std::unordered_set<std::string> visited;
    const gchar *search_path;
    const gchar **include_envvars;
    const gchar **var;

    /* Be sure we have the required fields */

    if(pkg->key.empty()) {
        fprintf(stderr, "Internal pkg-config error, package with no key, please file a bug report\n");
        exit(1);
    }

    if(pkg->name.empty()) {
        verbose_error("Package '%s' has no Name: field\n", pkg->key.c_str());
        exit(1);
    }

    if(pkg->version.empty()) {
        verbose_error("Package '%s' has no Version: field\n", pkg->key.c_str());
        exit(1);
    }

    if(pkg->description.empty()) {
        verbose_error("Package '%s' has no Description: field\n", pkg->key.c_str());
        exit(1);
    }

    /* Make sure we have the right version for all requirements */

    for(const Package *req : pkg->requires_private) {
        auto v_find = pkg->required_versions.find(req->key);

        if(v_find != pkg->required_versions.end()) {
            auto &ver = v_find->second;
            if(!version_test(ver.comparison, req->version.c_str(), ver.version.c_str())) {
                verbose_error("Package '%s' requires '%s %s %s' but version of %s is %s\n", pkg->key.c_str(), req->key.c_str(),
                        comparison_to_str(ver.comparison), ver.version.c_str(), req->key.c_str(), req->version.c_str());
                if(!req->url.empty())
                    verbose_error("You may find new versions of %s at %s\n", req->name.c_str(), req->url.c_str());

                exit(1);
            }
        }

    }

    /* Make sure we didn't drag in any conflicts via Requires
     * (inefficient algorithm, who cares)
     */
    recursive_fill_list(pkg, true, visited, requires);
    conflicts = pkg->conflicts;

    for(const auto &i : requires) {
        Package *req = i;

        for(const auto & ver : req->conflicts) {

            if(strcmp(ver.name.c_str(), req->key.c_str()) == 0 && version_test(ver.comparison, req->version.c_str(), ver.version.c_str())) {
                verbose_error("Version %s of %s creates a conflict.\n"
                        "(%s %s %s conflicts with %s %s)\n", req->version.c_str(), req->key.c_str(), ver.name.c_str(),
                        comparison_to_str(ver.comparison), ver.version.empty() ? ver.version.c_str() : "(any)", ver.owner->key.c_str(),
                        ver.owner->version.c_str());

                exit(1);
            }
        }
    }

    /* We make a list of system directories that compilers expect so we
     * can remove them.
     */

    search_path = g_getenv("PKG_CONFIG_SYSTEM_INCLUDE_PATH");

    if(search_path == NULL) {
        search_path = PKG_CONFIG_SYSTEM_INCLUDE_PATH;
    }

    system_directories = add_env_variable_to_list(system_directories, search_path);

#ifdef G_OS_WIN32
    include_envvars = msvc_syntax ? msvc_include_envvars : gcc_include_envvars;
#else
    include_envvars = gcc_include_envvars;
#endif
    for(var = include_envvars; *var != NULL; var++) {
        search_path = g_getenv(*var);
        if(search_path != NULL)
            system_directories = add_env_variable_to_list(system_directories, search_path);
    }

    std::vector<Flag> filtered;
    for(const auto &flag : pkg->cflags) {
        gint offset = 0;

        if(!(flag.type & CFLAGS_I)) {
            filtered.push_back(flag);
            continue;
        }
        /* Handle the system cflags. We put things in canonical
         * -I/usr/include (vs. -I /usr/include) format, but if someone
         * changes it later we may as well be robust.
         *
         * Note that the -i* flags are left out of this handling since
         * they're intended to adjust the system cflags behavior.
         */
        bool discard_this = false;
        if(((strncmp(flag.arg.c_str(), "-I", 2) == 0) && (offset = 2))
                || ((strncmp(flag.arg.c_str(), "-I ", 3) == 0) && (offset = 3))) {
            if(offset == 0) {
                iter = iter->next;
                continue;
            }

            system_dir_iter = system_directories;
            while(system_dir_iter != NULL) {
                if(strcmp(static_cast<char*>(system_dir_iter->data), &flag.arg[offset]) == 0) {
                    debug_spew("Package %s has %s in Cflags\n", pkg->key.c_str(), (gchar *) flag.arg.c_str());
                    if(g_getenv("PKG_CONFIG_ALLOW_SYSTEM_CFLAGS") == NULL) {
                        debug_spew("Removing %s from cflags for %s\n", flag.arg.c_str(), pkg->key.c_str());
                        discard_this = true;
                        break;
                    }
                }
                system_dir_iter = system_dir_iter->next;
            }
        }
        if(!discard_this) {
            filtered.push_back(flag);
        }
    }
    pkg->cflags.swap(filtered);


    g_list_foreach(system_directories, (GFunc) g_free, NULL);
    g_list_free(system_directories);

    system_directories = NULL;

    search_path = g_getenv("PKG_CONFIG_SYSTEM_LIBRARY_PATH");

    if(search_path == NULL) {
        search_path = PKG_CONFIG_SYSTEM_LIBRARY_PATH;
    }

    system_directories = add_env_variable_to_list(system_directories, search_path);

    filtered.clear();
    for(const auto &flag : pkg->libs) {
        GList *system_dir_iter = system_directories;

        if(!(flag.type & LIBS_L)) {
            filtered.push_back(flag);
            continue;
        }

        bool discard_this = false;
        while(system_dir_iter != NULL) {
            bool is_system = false;
            const char *linker_arg = flag.arg.c_str();
            const char *system_libpath = static_cast<char*>(system_dir_iter->data);

            if(strncmp(linker_arg, "-L ", 3) == 0 && strcmp(linker_arg + 3, system_libpath) == 0)
                is_system = true;
            else if(strncmp(linker_arg, "-L", 2) == 0 && strcmp(linker_arg + 2, system_libpath) == 0)
                is_system = true;
            if(is_system) {
                debug_spew("Package %s has -L %s in Libs\n", pkg->key.c_str(), system_libpath);
                if(g_getenv("PKG_CONFIG_ALLOW_SYSTEM_LIBS") == NULL) {
                    discard_this = true;
                    debug_spew("Removing -L %s from libs for %s\n", system_libpath, pkg->key.c_str());
                    break;
                }
            }
            system_dir_iter = system_dir_iter->next;
        }
        if(!discard_this) {
            filtered.push_back(flag);
        }
    }
    g_list_free(system_directories);

    pkg->libs.swap(filtered);
}

/* Create a merged list of required packages and retrieve the flags from them.
 * Strip the duplicates from the flags list. The sorting and stripping can be
 * done in one of two ways: packages sorted by position in the pkg-config path
 * and stripping done from the beginning of the list, or packages sorted from
 * most dependent to least dependent and stripping from the end of the list.
 * The former is done for -I/-L flags, and the latter for all others.
 */
static std::string
get_multi_merged(GList *pkgs, FlagType type, bool in_path_order, bool include_private) {
    std::vector<Flag> list;
    std::string retval;

    list = fill_list(pkgs, type, in_path_order, include_private);
    list = flag_list_strip_duplicates(list);
    retval = flag_list_to_string(list);

    return retval;
}

std::string
packages_get_flags(GList *pkgs, FlagType flags) {
    std::string str, cur;

    /* sort packages in path order for -L/-I, dependency order otherwise */
    if(flags & CFLAGS_OTHER) {
        cur = get_multi_merged(pkgs, CFLAGS_OTHER, false, true);
        debug_spew("adding CFLAGS_OTHER string \"%s\"\n", cur.c_str());
        str += cur;
    }
    if(flags & CFLAGS_I) {
        cur = get_multi_merged(pkgs, CFLAGS_I, true, true);
        debug_spew("adding CFLAGS_I string \"%s\"\n", cur.c_str());
        str += cur;
    }
    if(flags & LIBS_L) {
        cur = get_multi_merged(pkgs, LIBS_L, true, !ignore_private_libs);
        debug_spew("adding LIBS_L string \"%s\"\n", cur.c_str());
        str += cur;
    }
    if(flags & (LIBS_OTHER | LIBS_l)) {
        cur = get_multi_merged(pkgs, flags & (LIBS_OTHER | LIBS_l), false, !ignore_private_libs);
        debug_spew("adding LIBS_OTHER | LIBS_l string \"%s\"\n", cur.c_str());
        str += cur;
    }

    /* Strip trailing space. */
    if(!str.empty() && str.back() == ' ')
        str.pop_back();

    debug_spew("returning flags string \"%s\"\n", str.c_str());
    return str;
}

void define_global_variable(const char *varname, const char *varval) {

    if(globals.find(varname) != globals.end()) {
        verbose_error("Variable '%s' defined twice globally\n", varname);
        exit(1);
    }

    globals[varname] = varval;

    debug_spew("Global variable definition '%s' = '%s'\n", varname, varval);
}

char *
var_to_env_var(const char *pkg, const char *var) {
    char *new_ = g_strconcat("PKG_CONFIG_", pkg, "_", var, NULL);
    char *p;
    for(p = new_; *p != 0; p++) {
        char c = g_ascii_toupper(*p);

        if(!g_ascii_isalnum(c))
            c = '_';

        *p = c;
    }

    return new_;
}

std::string
package_get_var(Package *pkg, const char *var) {
    std::string varval;
    auto lookup = globals.find(var);
    if(lookup != globals.end())
        varval = lookup->second;

    /* Allow overriding specific variables using an environment variable of the
     * form PKG_CONFIG_$PACKAGENAME_$VARIABLE
     */
    if(pkg->key.c_str()) {
        char *env_var = var_to_env_var(pkg->key.c_str(), var);
        const char *env_var_content = g_getenv(env_var);
        g_free(env_var);
        if(env_var_content) {
            debug_spew("Overriding variable '%s' from environment\n", var);
            return g_strdup(env_var_content);
        }
    }

    if(varval.empty()) {
        auto res = pkg->vars.find(var);
        if(res != pkg->vars.end())
            varval = res->second;
    }
    return varval;
}

char *
packages_get_var(GList *pkgs, const char *varname) {
    GList *tmp;
    GString *str;

    str = g_string_new(NULL);

    tmp = pkgs;
    while(tmp != NULL) {
        Package *pkg = static_cast<Package*>(tmp->data);
        auto var = parse_package_variable(pkg, varname);
        if(!var.empty()) {
            if(str->len > 0)
                g_string_append_c(str, ' ');
            g_string_append(str, var.c_str());
        }

        tmp = g_list_next(tmp);
    }

    return g_string_free(str, false);
}

int compare_versions(const char * a, const char *b) {
    return rpmvercmp(a, b);
}

bool version_test(ComparisonType comparison, const char *a, const char *b) {
    switch (comparison){
    case LESS_THAN:
        return compare_versions(a, b) < 0;
        break;

    case GREATER_THAN:
        return compare_versions(a, b) > 0;
        break;

    case LESS_THAN_EQUAL:
        return compare_versions(a, b) <= 0;
        break;

    case GREATER_THAN_EQUAL:
        return compare_versions(a, b) >= 0;
        break;

    case EQUAL:
        return compare_versions(a, b) == 0;
        break;

    case NOT_EQUAL:
        return compare_versions(a, b) != 0;
        break;

    case ALWAYS_MATCH:
        return true;
        break;

    default:
        g_assert_not_reached ()
        ;
        break;
    }

    return false;
}

const char *
comparison_to_str(ComparisonType comparison) {
    switch (comparison){
    case LESS_THAN:
        return "<";
        break;

    case GREATER_THAN:
        return ">";
        break;

    case LESS_THAN_EQUAL:
        return "<=";
        break;

    case GREATER_THAN_EQUAL:
        return ">=";
        break;

    case EQUAL:
        return "=";
        break;

    case NOT_EQUAL:
        return "!=";
        break;

    case ALWAYS_MATCH:
        return "(any)";
        break;

    default:
        g_assert_not_reached ()
        ;
        break;
    }

    return "???";
}

void print_package_list(void) {
    size_t mlen = 0;

    ignore_requires = true;
    ignore_requires_private = true;

    for(auto i = packages.begin(); i != packages.end(); ++i) {
        mlen = std::max(mlen, i->first.length());
    }
    for(auto i = packages.begin(); i != packages.end(); ++i) {
        std::string pad;
        for(size_t counter=0; counter < mlen-i->first.size()+1; ++counter)
            pad += " ";
        printf("%s%s%s - %s\n", i->second->key.c_str(), pad.c_str(), i->second->name.c_str(),
                i->second->description.c_str());
    }
}

void enable_private_libs(void) {
    ignore_private_libs = false;
}

void disable_private_libs(void) {
    ignore_private_libs = true;
}

void enable_requires(void) {
    ignore_requires = false;
}

void disable_requires(void) {
    ignore_requires = true;
}

void enable_requires_private(void) {
    ignore_requires_private = false;
}

void disable_requires_private(void) {
    ignore_requires_private = true;
}
