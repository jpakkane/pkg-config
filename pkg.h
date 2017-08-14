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

#ifndef PKG_CONFIG_PKG_H
#define PKG_CONFIG_PKG_H

#include<string>
#include<vector>
#include<unordered_map>
#include <glib.h>

typedef guint8 FlagType; /* bit mask for flag types */

#define LIBS_l       (1 << 0)
#define LIBS_L       (1 << 1)
#define LIBS_OTHER   (1 << 2)
#define CFLAGS_I     (1 << 3)
#define CFLAGS_OTHER (1 << 4)

#define LIBS_ANY     (LIBS_l | LIBS_L | LIBS_OTHER)
#define CFLAGS_ANY   (CFLAGS_I | CFLAGS_OTHER)
#define FLAGS_ANY    (LIBS_ANY | CFLAGS_ANY)

typedef enum {
    LESS_THAN, GREATER_THAN, LESS_THAN_EQUAL, GREATER_THAN_EQUAL, EQUAL, NOT_EQUAL, ALWAYS_MATCH
} ComparisonType;

struct Package;

struct Flag {
    FlagType type;
    std::string arg;
};

struct RequiredVersion {
    std::string name;
    ComparisonType comparison = LESS_THAN;
    std::string version;
    Package *owner = nullptr;
};

struct Package {
    std::string key; /* filename name */
    std::string name; /* human-readable name */
    std::string version;
    std::string description;
    std::string url;
    std::string pcfiledir; /* directory it was loaded from */
    std::vector<RequiredVersion> requires_entries;
    std::vector<std::string> requires;
    std::vector<RequiredVersion> requires_private_entries;
    std::vector<std::string> requires_private;
    std::vector<Flag> libs;
    std::vector<Flag> cflags;
    std::unordered_map<std::string, std::string> vars;
    std::unordered_map<std::string, RequiredVersion> required_versions; /* hash from name to RequiredVersion */
    std::vector<RequiredVersion> conflicts; /* list of RequiredVersion */
    bool uninstalled = false; /* used the -uninstalled file */
    int path_position = 0; /* used to order packages by position in path of their .pc file, lower number means earlier in path */
    int libs_num = 0; /* Number of times the "Libs" header has been seen */
    int libs_private_num = 0; /* Number of times the "Libs.private" header has been seen */
    std::string orig_prefix; /* original prefix value before redefinition */

    bool operator==(const Package &other) const { return key == other.key; }
    bool empty() const { return key.empty(); }
};

Package get_package(const char *name);
Package get_package_quiet(const char *name);
std::string packages_get_flags(std::vector<Package> &pkgs, FlagType flags);
std::string package_get_var(Package *pkg, const char *var);
std::string packages_get_var(std::vector<Package> &pkgs, const char *var);

void add_search_dir(const char *path);
void add_search_dirs(const char *path, const char separator);
void package_init(bool want_list);
int compare_versions(const std::string &a, const std::string &b);
bool version_test(ComparisonType comparison, const std::string &a, const std::string &b);

const char *comparison_to_str(ComparisonType comparison);

void print_package_list(void);

void define_global_variable(const char *varname, const char *varval);

void debug_spew(const char *format, ...);
void verbose_error(const char *format, ...);

bool name_ends_in_uninstalled(const char *str);

void enable_private_libs(void);
void disable_private_libs(void);
void enable_requires(void);
void disable_requires(void);
void enable_requires_private(void);
void disable_requires_private(void);

/* If true, do not automatically prefer uninstalled versions */
extern bool disable_uninstalled;

extern char *pcsysrootdir;

/* pkg-config default search path. On Windows the current pkg-config install
 * directory is used. Otherwise, the build-time defined PKG_CONFIG_PC_PATH.
 */
extern const char *pkg_config_pc_path;

/* Exit on parse errors if true. */
extern bool parse_strict;

/* If true, define "prefix" in .pc files at runtime. */
extern bool define_prefix;

/* The name of the variable that acts as prefix, unless it is "prefix" */
extern const char *prefix_variable;

#ifdef G_OS_WIN32
/* If true, output flags in MSVC syntax. */
extern bool msvc_syntax;
#endif

#endif
