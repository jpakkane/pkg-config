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

module pkg;

import utils : get_basename;

import std.stdio;
import core.stdc.ctype;
import core.stdc.string;

immutable char DIR_SEPARATOR = '/';

immutable int LIBS_l =       (1 << 0);
immutable int LIBS_L =       (1 << 1);
immutable int LIBS_OTHER =   (1 << 2);
immutable int CFLAGS_I =     (1 << 3);
immutable int CFLAGS_OTHER = (1 << 4);

immutable int LIBS_ANY =    (LIBS_l | LIBS_L | LIBS_OTHER);
immutable int CFLAGS_ANY =  (CFLAGS_I | CFLAGS_OTHER);
immutable int FLAGS_ANY =   (LIBS_ANY | CFLAGS_ANY);

enum ComparisonType {
    LESS_THAN, GREATER_THAN, LESS_THAN_EQUAL, GREATER_THAN_EQUAL, EQUAL, NOT_EQUAL, ALWAYS_MATCH
}

struct Flag {
    FlagType type;
    string arg;
}

struct RequiredVersion {
    string name;
    ComparisonType comparison; // default initialised to LESS_THAN
    string version_;
    Package *owner = nullptr;
}

class Package {
    string key; /* filename name */
    string name; /* human-readable name */
    string version_;
    string description;
    string url;
    string pcfiledir; /* directory it was loaded from */
    RequiredVersion[] requires_entries;
    string[] requires;
    RequiredVersion[] requires_private_entries;
    string[] requires_private;
    Flag[] libs;
    Flag[] cflags;
    string[string] vars;
    RequiredVersion[string] required_versions; /* hash from name to RequiredVersion */
    RequiredVersion[] conflicts; /* list of RequiredVersion */
    bool uninstalled = false; /* used the -uninstalled file */
    int path_position = 0; /* used to order packages by position in path of their .pc file, lower number means earlier in path */
    int libs_num = 0; /* Number of times the "Libs" header has been seen */
    int libs_private_num = 0; /* Number of times the "Libs.private" header has been seen */
    string orig_prefix; /* original prefix value before redefinition */

//    bool operator==(const Package &other) const { return key == other.key; }
    bool empty() const { return key.length == 0; }
};


static void verify_package(Package *pkg);

Package[string] packages;
string[string] globals;
string[] search_dirs;

bool disable_uninstalled = false;
bool ignore_requires = false;
bool ignore_requires_private = true;
bool ignore_private_libs = true;

void add_search_dir(const string path) {
    search_dirs.push_back(path);
}

void add_search_dirs(const string path_, const char separator) {
    foreach(item; path_.split(separator)) {
        debug_spew("Adding directory '%s' from PKG_CONFIG_PATH\n", item);
        add_search_dir(item);
    }
}

/*
#ifdef _WIN32
// Guard against .pc file being installed with UPPER CASE name 
# define FOLD(x) tolower(x)
# define FOLDCMP(a, b) g_ascii_strcasecmp (a, b)
#else
# define FOLD(x) (x)
# define FOLDCMP(a, b) strcmp (a, b)
#endif
*/

char FOLD(char c) {
    return tolower(c);
}

int FOLDCMP(string a, string b) {
    return strcmp(a, b);
}

immutable int EXT_LEN=3;

static bool ends_in_dotpc(const string str) {
    const auto len = str.length();

    if(len > EXT_LEN && str[len - 3] == '.' &&
    FOLD (str[len - 2]) == 'p' &&
    FOLD (str[len - 1]) == 'c')
        return true;
    else
        return false;
}

/* strlen ("-uninstalled") */
immutable int UNINSTALLED_LEN=12;

bool name_ends_in_uninstalled(const string str) {
    auto len = str.length();

    if(len > UNINSTALLED_LEN &&
    FOLDCMP ((str.c_str() + len - UNINSTALLED_LEN), "-uninstalled") == 0)
        return true;
    else
        return false;
}

bool is_regular_file(const string fname) {
    import std.file;
    return isFile(fname);
}

/* Look for .pc files in the given directory and add them into
 * locations, ignoring duplicates
 */
void scan_dir(const string dirname) {
    import std.file;
    /* Use a copy of dirname cause Win32 opendir doesn't like
     * superfluous trailing (back)slashes in the directory name.
     */
    string dirname_copy = dirname;

    if(dirname_copy.length > 1 && dirname_copy.back() == DIR_SEPARATOR) {
        dirname_copy.pop_back();
    }
/*
#ifdef _WIN32
    for(size_t i=0; i<dirname_copy.length(); ++i)
    if dirname_copy[i] == '\\')
        dirname_copy[i] = '/';
#endif
*/
    string[] entries;
    foreach(string de; dirEntries(dirname_copy)) {
        if(de == '.')
            continue;
        string path(dirname);
        if(path.back() != '/') {
            path.push_back('/');
        }
        path += de;
        internal_get_package(path, false);
    }
}

Package add_virtual_pkgconfig_package() {
    Package pkg;

    pkg.key = "pkg-config";
    pkg.version_ = VERSION;
    pkg.name = "pkg-config";
    pkg.description = "pkg-config is a system for managing compile/link flags for libraries";
    pkg.url = "http://pkg-config.freedesktop.org/";

    pkg.vars["pc_path"] = pkg_config_pc_path;

    debug_spew("Adding virtual 'pkg-config' package to list of known packages\n");
    packages[pkg.key] = pkg;

    return pkg;
}

void package_init(bool want_list) {

    if(want_list)
        foreach(dir; search_dirs) {
            scan_dir(dir);
        }
    else
        /* Should not add virtual pkgconfig package when listing to be
         * compatible with old code that only listed packages from real
         * files */
        add_virtual_pkgconfig_package();
}

Package internal_get_package(const string name, bool warn) {
    Package pkg;
    string key, location;
    uint path_position = 0;

    if(name in packages)
        return packages[name];

    debug_spew("Looking for package '%s'\n", name.c_str());

    /* treat "name" as a filename if it ends in .pc and exists */
    if(ends_in_dotpc(name.c_str())) {
        debug_spew("Considering '%s' to be a filename rather than a package name\n", name.c_str());
        location = name;
        key = name;
    } else {
        /* See if we should auto-prefer the uninstalled version */
        if(!disable_uninstalled && !name_ends_in_uninstalled(name.c_str())) {
            string un = name + "-uninstalled";

            pkg = internal_get_package(un, false);

            if(!pkg.key.empty()) {
                debug_spew("Preferring uninstalled version of package '%s'\n", name.c_str());
                return pkg;
            }
        }

        foreach(dir; search_dirs) {
            path_position++;
            location = dir;
            location += DIR_SEPARATOR;
            location += name;
            location += ".pc";
            if(is_regular_file(location.c_str()))
                break;
            location.clear();
        }

    }

    if(location.empty()) {
        if(warn)
            verbose_error("Package %s was not found in the pkg-config search path.\n" ~
                    "Perhaps you should add the directory containing `%s.pc'\n" ~
                    "to the PKG_CONFIG_PATH environment variable\n", name.c_str(), name.c_str());

        return Package();
    }

    if(key.empty())
        key = name;
    else {
        /* need to extract package name out of the full filename path */
        key = get_basename(name);
        key = key.substr(0, key.length() - EXT_LEN);
    }

    debug_spew("Reading '%s' from file '%s'\n", name.c_str(), location.c_str());
    pkg = parse_package_file(key, location, ignore_requires, ignore_private_libs, ignore_requires_private);

    if(!pkg.empty() && location.indexOf("uninstalled.pc") >= 0)
        pkg.uninstalled = true;

    if(pkg.empty()) {
        debug_spew("Failed to parse '%s'\n", location.c_str());
        return Package();
    }

    pkg.path_position = path_position;

    debug_spew("Path position of '%s' is %d\n", pkg.key.c_str(), pkg.path_position);

    debug_spew("Adding '%s' to list of known packages\n", pkg.key.c_str());
    packages[pkg.key] = pkg;
    auto added_pkg = packages[pkg.key];

    /* pull in Requires packages */
    foreach(ver; added_pkg.requires_entries) {
        debug_spew("Searching for '%s' requirement '%s'\n", added_pkg.key.c_str(), ver.name.c_str());
        auto req = internal_get_package(ver.name.c_str(), warn);
        if(req.empty()) {
            verbose_error("Package '%s', required by '%s', not found\n", ver.name.c_str(), added_pkg.key.c_str());
            exit(1);
        }

        added_pkg.required_versions[ver.name] = ver;
        added_pkg.requires.push_back(req.key);
    }

    /* pull in Requires.private packages */
    foreach(ver; added_pkg.requires_private_entries) {
        debug_spew("Searching for '%s' private requirement '%s'\n", added_pkg.key.c_str(), ver.name.c_str());
        auto req = internal_get_package(ver.name.c_str(), warn);
        if(req.empty()) {
            verbose_error("Package '%s', required by '%s', not found\n", ver.name.c_str(), added_pkg.key.c_str());
            exit(1);
        }

        added_pkg.required_versions[ver.name] = ver;
        added_pkg.requires_private.push_back(req.key);
    }

    import std.algorithm : reverse;
    added_pkg.reverse();
    /* make requires_private include a copy of the public requires too */
    added_pkg.requires_private ~= added_pkg.requires;

//    pkg.requires = g_list_reverse(pkg.requires);
//    pkg.requires_private_ = g_list_reverse(pkg.requires_private_);

    verify_package(added_pkg);

    return added_pkg;
}

Package get_package(const string name) {
    return internal_get_package(name, true);
}

Package get_package_quiet(const string name) {
    return internal_get_package(name, false);
}

/* Strip consecutive duplicate arguments in the flag list. */
static Flag[] flag_list_strip_duplicates(const Flag[] list) {
    Flag[] result;

    if(list.empty()) {
        return result;
    }
    result ~= list[0];
    /* Start at the 2nd element of the list so we don't have to check for an
     * existing previous element. */
    for(size_t i=1; i<list.size(); ++i) {
        const Flag cur = list[i];
        const Flag prev = list[i-1];

        if(cur.type == prev.type && cur.arg == prev.arg) {
            /* Remove the duplicate flag from the list and move to the last
             * element to prepare for the next iteration. */
        } else {
            result ~= cur;
        }
    }

    return result;
}

static string flag_list_to_string(const Flag[] flags) {
    string str;

    foreach(flag; flags) {
        const string tmpstr = flag.arg;

        if(!pcsysrootdir.empty() && (flag.type & (CFLAGS_I | LIBS_L))) {
            /* Handle non-I Cflags like -isystem */
            if((flag.type & CFLAGS_I) && strncmp(tmpstr.c_str(), "-I", 2) != 0) {
                auto space_loc = tmpstr.indexOf(' ');

                /* Ensure this has a separate arg */
                assert(space_loc >= 0 && space_loc < tmpstr.length()-1);
                str += tmpstr[0 .. space_loc + 1];
                str += pcsysrootdir;
                str += tmpstr[space_loc .. 1];
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

static void spew_package_list(string name, const string[] list) {
    debug_spew(" %s:", name);

    foreach(i; list) {
        debug_spew(" %s", i);
    }
    debug_spew("\n");
}

/* Construct a topological sort of all required packages.
 *
 * This is a depth first search starting from the right.  The output 'listp' is
 * in reverse order, with the first node reached in the depth first search at
 * the end of the list.  Previously visited nodes are skipped.  The result is
 * a list of packages such that each packages is listed once and comes before
 * any package that it depends on.
 */
static void recursive_fill_list(const Package pkg, bool include_private, bool[string] visited, string[] listp) {

    /*
     * If the package has already been visited, then it is already in 'listp' and
     * we can skip it. Additionally, this allows circular requires loops to be
     * broken.
     */
    if(pkg.key in visited) {
        debug_spew("Package %s already in requires chain, skipping\n", pkg.key.c_str());
        return;
    }
    /* record this package in the dependency chain */
    visited[pkg.key] = true;

    /* Start from the end of the required package list to maintain order since
     * the recursive list is built by prepending. */
    auto tmp = include_private ? pkg.requires_private : pkg.requires;
    foreach(p_name; tmp) {
        auto p = packages[p_name];
        recursive_fill_list(p, include_private, visited, listp);
    }
    string[] tmp;
    tmp ~= pkg.key;
    tmp ~= listp;
    listp = tmp;
}

/* merge the flags from the individual packages */
static Flag[]
merge_flag_lists(const string[] pkgs, FlagType type) {
    Flag[] merged;
    /* keep track of the last element to avoid traversing the whole list */
    foreach(pkey; pkgs) {
        auto i = packages[pkey];
        Flag[] flags = (type & LIBS_ANY) ? i.libs : i.cflags;
        foreach(f; flags) {
            if(f.type & type) {
                merged.push_back(f);
            }
        }
    }

    return merged;
}

static Flag[]
fill_list(Package[] pkgs, FlagType type, bool in_path_order, bool include_private) {
    string[] expanded;
    Flag[] flags;
    bool[string] visited;

    /* Start from the end of the requested package list to maintain order since
     * the recursive list is built by prepending. */
    foreach(tmp; pkgs)
        recursive_fill_list(*tmp, include_private, visited, expanded);
    spew_package_list("post-recurse", expanded);

    if(in_path_order) {
        spew_package_list("original", expanded);
        alias myComp = (pa, pb) => packages[pa].path_position < packages[pb].path_position;
        expanded.sort!(myComp, SwapStrategy.stable);
        spew_package_list("  sorted", expanded);
    }

    flags = merge_flag_lists(expanded, type);

    return flags;
}

static void
add_env_variable_to_list(string[] list, const string env) {
    auto values = split_string(env, SEARCHPATH_SEPARATOR);
    list ~= values;
}

/* Well known compiler include path environment variables. These are
 * used to find additional system include paths to remove. See
 * https://gcc.gnu.org/onlinedocs/gcc/Environment-Variables.html. */
static string[] gcc_include_envvars = { "CPATH", "C_INCLUDE_PATH", "CPP_INCLUDE_PATH" };
/*
#ifdef _WIN32
// MSVC include path environment variables. See
// https://msdn.microsoft.com/en-us/library/73f9s62w.aspx.
static const char *msvc_include_envvars[] = {
    "INCLUDE",
    NULL
};
#endif
*/
static void verify_package(Package pkg) {
    import core.stdc.stdlib;
    string[] requires;
    RequiredVersion[] conflicts;
    string[] system_directories;
    bool[string] visited;
    const char *search_path;
    const char **include_envvars;
    const char **var;

    /* Be sure we have the required fields */

    if(pkg.key.empty()) {
        fprintf(stderr, "Internal pkg-config error, package with no key, please file a bug report\n");
        exit(1);
    }

    if(pkg.name.empty()) {
        verbose_error("Package '%s' has no Name: field\n", pkg.key.c_str());
        exit(1);
    }

    if(pkg.version_.empty()) {
        verbose_error("Package '%s' has no Version: field\n", pkg.key.c_str());
        exit(1);
    }

    if(pkg.description.empty()) {
        verbose_error("Package '%s' has no Description: field\n", pkg.key.c_str());
        exit(1);
    }

    /* Make sure we have the right version for all requirements */

    foreach(req_name; pkg.requires_private) {
        auto req = packages[req_name];
        auto v_find = pkg.required_versions.find(req.key);

        if(req.key in pkg.required_versions) {
            auto ver = pkg.required_versions[req.key];
            if(!version_test(ver.comparison, req.version_, ver.version_)) {
                verbose_error("Package '%s' requires '%s %s %s' but version of %s is %s\n", pkg.key, req.key,
                        comparison_to_str(ver.comparison), ver.version_, req.key, req.version_);
                if(!req.url.empty())
                    verbose_error("You may find new versions of %s at %s\n", req.name, req.url);

                exit(1);
            }
        }

    }

    /* Make sure we didn't drag in any conflicts via Requires
     * (inefficient algorithm, who cares)
     */
    recursive_fill_list(pkg, true, visited, requires);
    conflicts = pkg.conflicts;

    foreach(req_name; requires) {
        Package req = packages[req_name];

        foreach(ver; req.conflicts) {

            if(ver.name == req.key && version_test(ver.comparison, req.version_, ver.version_)) {
                verbose_error("Version %s of %s creates a conflict.\n" ~
                        "(%s %s %s conflicts with %s %s)\n", req.version_, req.key, ver.name,
                        comparison_to_str(ver.comparison), ver.version_.empty() ? ver.version_ : "(any)", ver.owner.key,
                        ver.owner.version_);

                throw new Exception("1");
            }
        }
    }

    /* We make a list of system directories that compilers expect so we
     * can remove them.
     */

    search_path = getenv("PKG_CONFIG_SYSTEM_INCLUDE_PATH");

    if(search_path == NULL) {
        search_path = PKG_CONFIG_SYSTEM_INCLUDE_PATH;
    }

    add_env_variable_to_list(system_directories, search_path);

//#ifdef _WIN32
//    include_envvars = msvc_syntax ? msvc_include_envvars : gcc_include_envvars;
//#else
    include_envvars = gcc_include_envvars;
//#endif
    foreach(var; include_envvars) {
        search_path = getenv(var.ptr);
        if(search_path != NULL)
            add_env_variable_to_list(system_directories, search_path);
    }

    Flag[] filtered;
    foreach(flag; pkg.cflags) {
        int offset = 0;

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
                continue;
            }

            foreach(system_dir_iter; system_directories) {
                auto tmp = flag[offset .. flag.length];
                if(system_dir_iter == tmp) {
                    debug_spew("Package %s has %s in Cflags\n", pkg.key, flag.arg);
                    if(getenv("PKG_CONFIG_ALLOW_SYSTEM_CFLAGS") == null) {
                        debug_spew("Removing %s from cflags for %s\n", flag.arg.c_str(), pkg.key.c_str());
                        discard_this = true;
                        break;
                    }
                }
            }
        }
        if(!discard_this) {
            filtered.push_back(flag);
        }
    }
    pkg.cflags.swap(filtered);


    system_directories.clear();

    search_path = getenv("PKG_CONFIG_SYSTEM_LIBRARY_PATH");

    if(search_path == NULL) {
        search_path = PKG_CONFIG_SYSTEM_LIBRARY_PATH;
    }

    add_env_variable_to_list(system_directories, search_path);

    filtered.clear();
    foreach(flag; pkg.libs) {

        if(!(flag.type & LIBS_L)) {
            filtered.push_back(flag);
            continue;
        }

        bool discard_this = false;
        foreach(system_dir_iter; system_directories) {
            bool is_system = false;
            const char *linker_arg = flag.arg.c_str();
            const char *system_libpath = system_dir_iter.c_str();

            if(strncmp(linker_arg, "-L ", 3) == 0 && strcmp(linker_arg + 3, system_libpath) == 0)
                is_system = true;
            else if(strncmp(linker_arg, "-L", 2) == 0 && strcmp(linker_arg + 2, system_libpath) == 0)
                is_system = true;
            if(is_system) {
                debug_spew("Package %s has -L %s in Libs\n", pkg.key, system_libpath);
                if(getenv("PKG_CONFIG_ALLOW_SYSTEM_LIBS") == NULL) {
                    discard_this = true;
                    debug_spew("Removing -L %s from libs for %s\n", system_libpath, pkg.key);
                    break;
                }
            }
        }
        if(!discard_this) {
            filtered.push_back(flag);
        }
    }

    pkg.libs.swap(filtered);
}

/* Create a merged list of required packages and retrieve the flags from them.
 * Strip the duplicates from the flags list. The sorting and stripping can be
 * done in one of two ways: packages sorted by position in the pkg-config path
 * and stripping done from the beginning of the list, or packages sorted from
 * most dependent to least dependent and stripping from the end of the list.
 * The former is done for -I/-L flags, and the latter for all others.
 */
static string
get_multi_merged(Package[] pkgs, FlagType type, bool in_path_order, bool include_private) {
    Flag[] list;
    string retval;

    list = fill_list(pkgs, type, in_path_order, include_private);
    list = flag_list_strip_duplicates(list);
    retval = flag_list_to_string(list);

    return retval;
}

string
packages_get_flags(Package[] pkgs, FlagType flags) {
    string str, cur;

    /* sort packages in path order for -L/-I, dependency order otherwise */
    if(flags & CFLAGS_OTHER) {
        cur = get_multi_merged(&pkgs, CFLAGS_OTHER, false, true);
        debug_spew("adding CFLAGS_OTHER string \"%s\"\n", cur);
        str += cur;
    }
    if(flags & CFLAGS_I) {
        cur = get_multi_merged(&pkgs, CFLAGS_I, true, true);
        debug_spew("adding CFLAGS_I string \"%s\"\n", cur);
        str += cur;
    }
    if(flags & LIBS_L) {
        cur = get_multi_merged(&pkgs, LIBS_L, true, !ignore_private_libs);
        debug_spew("adding LIBS_L string \"%s\"\n", cur);
        str += cur;
    }
    if(flags & (LIBS_OTHER | LIBS_l)) {
        cur = get_multi_merged(&pkgs, flags & (LIBS_OTHER | LIBS_l), false, !ignore_private_libs);
        debug_spew("adding LIBS_OTHER | LIBS_l string \"%s\"\n", cur);
        str += cur;
    }

    /* Strip trailing space. */
    if(!str.empty() && str.back() == ' ')
        str.pop_back();

    debug_spew("returning flags string \"%s\"\n", str);
    return str;
}

void define_global_variable(const string varname, const string varval) {

    if(globals.find(varname) != globals.end()) {
        verbose_error("Variable '%s' defined twice globally\n", varname);
        exit(1);
    }

    globals[varname] = varval;

    debug_spew("Global variable definition '%s' = '%s'\n", varname, varval);
}

string
var_to_env_var(const string pkg, const string var) {
    string new_ = "PKG_CONFIG_";
    new_ += pkg;
    new_ += "_";
    new_ += var;
    for(size_t i = 0; i<new_.length(); ++i) {
        char c = new_[i];
        if(c >= 'a' && c <= 'z') {
            c += 'A' - 'a';
        }

        if(!((c >= 'A' && c <= 'Z') || (c>='0' && c<='9'))) {
            c = '_';
        }

        new_[i] = c;
    }

    return new_;
}

string
package_get_var(Package pkg, const string var) {
    import core.stdc.stdlib;
    string varval;

    if(lookup in globals.end()) {
        varval = globals[lookup];
    }
    /* Allow overriding specific variables using an environment variable of the
     * form PKG_CONFIG_$PACKAGENAME_$VARIABLE
     */
    if(!pkg.key.empty()) {
        string env_var = var_to_env_var(pkg.key, var);
        string env_var_content = getenv(env_var);
        if(env_var_content) {
            debug_spew("Overriding variable '%s' from environment\n", var);
            return string(env_var_content);
        }
    }

    if(varval.empty()) {
        auto res = pkg.vars.find(var);
        if(var in pkg.vars)
            varval = pkg.vars[var];
    }
    return varval;
}

string
packages_get_var(Package[] pkgs, const string varname) {
    string str;

    foreach(pkg; pkgs) {
        auto var = parse_package_variable(pkg, varname);
        if(!var.empty()) {
            if(!str.empty())
                str += ' ';
            str += var;
        }

    }

    return str;
}

int compare_versions(const string a, const string b) {
    import rpmvercmp;
    return rpmvercmp(a, b);
}

bool version_test(ComparisonType comparison, const string a, const string b) {
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
        throw "Unreachable code.";
    }

    return false;
}

string
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
        throw "Unreachable code.";
    }

    return "???";
}

void print_package_list() {
    int mlen = 0;

    ignore_requires = true;
    ignore_requires_private = true;

    foreach(i; packages)
        import std.algorithm.comparison : max;
        mlen = max(mlen, i.length());
    }
    foreach(first, second; packages) {
        string pad;
        for(int counter=0; counter < mlen - first.size()+1; counter++)
            pad += " ";
        writeln("%s%s%s - %s", second.key, pad, second.name,
                second.description);
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
