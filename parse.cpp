/* 
 * Copyright (C) 2006-2011 Tollef Fog Heen <tfheen@err.no>
 * Copyright (C) 2001, 2002, 2005-2006 Red Hat Inc.
 * Copyright (C) 2010 Dan Nicholson <dbn.lists@gmail.com>
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

#include "parse.h"
#include <stdio.h>
#include <errno.h>
#include <string.h>
#include <stdlib.h>
#include <ctype.h>
#ifdef HAVE_SYS_WAIT_H
#include <sys/wait.h>
#endif
#include <sys/types.h>

#include<glib.h>

bool parse_strict = true;
bool define_prefix = ENABLE_DEFINE_PREFIX;
const char *prefix_variable = "prefix";

#ifdef _WIN32
bool msvc_syntax = false;
#endif

/**
 * Read an entire line from a file into a buffer. Lines may
 * be delimited with '\n', '\r', '\n\r', or '\r\n'. The delimiter
 * is not written into the buffer. Text after a '#' character is treated as
 * a comment and skipped. '\' can be used to escape a # character.
 * '\' proceding a line delimiter combines adjacent lines. A '\' proceding
 * any other character is ignored and written into the output buffer
 * unmodified.
 * 
 * Return value: %false if the stream was already at an EOF character.
 **/
static bool read_one_line(FILE *stream, std::string &str) {
    bool quoted = false;
    bool comment = false;
    int n_read = 0;

    str.clear();

    while(true) {
        int c;

        c = getc(stream);

        if(c == EOF) {
            if(quoted)
                str += '\\';

            goto done;
        } else
            n_read++;

        if(quoted) {
            quoted = false;

            switch (c){
            case '#':
                str += '#';
                break;
            case '\r':
            case '\n': {
                int next_c = getc(stream);

                if(!(c == EOF || (c == '\r' && next_c == '\n') || (c == '\n' && next_c == '\r')))
                    ungetc(next_c, stream);

                break;
            }
            default:
                str +=  '\\';
                str += c;
            }
        } else {
            switch (c){
            case '#':
                comment = true;
                break;
            case '\\':
                if(!comment)
                    quoted = true;
                break;
            case '\n': {
                int next_c = getc(stream);

                if(!(c == EOF || (c == '\r' && next_c == '\n') || (c == '\n' && next_c == '\r')))
                    ungetc(next_c, stream);

                goto done;
            }
            default:
                if(!comment)
                    str += c;
            }
        }
    }

    done:

    return n_read > 0;
}

static std::string
trim_string(const std::string &str) {
    std::string res(str);

    while(!res.empty() && isspace(res.front())) {
        res.erase(0, 1);
    }
    while(!res.empty() && isspace(res.back())) {
        res.erase(str.size()-1, 1);
    }
    return res;
}

static std::string
trim_and_sub(Package *pkg, const std::string &str, const char *path) {
    GString *subst;
    std::string::size_type p = 0;

    auto trimmed = trim_string(str);

    subst = g_string_new("");

    while(p<trimmed.size()) {
        if(str[p] == '$' && str[p+1] == '$') {
            /* escaped $ */
            g_string_append_c(subst, '$');
            p += 2;
        } else if(str[p] == '$' && str[p+1] == '{') {
            /* variable */
            std::string varval;

            auto var_start = p+2;

            /* Get up to close brace. */
            while(p<str.size() && str[p] != '}')
                ++p;

            auto varname = str.substr(var_start, p-var_start);

            ++p; /* past brace */

            varval = package_get_var(pkg, varname);

            if(varval.empty()) {
                verbose_error("Variable '%s' not defined in '%s'\n", varname, path);
                if(parse_strict)
                    exit(1);
            }

            g_string_append(subst, varval.c_str());
        } else {
            g_string_append_c(subst, str[p]);

            ++p;
        }
    }

    std::string res(subst->str);
    g_string_free(subst, true);

    return res;
}

static void parse_name(Package *pkg, std::string &str, const char *path) {
    if(!pkg->name.empty()) {
        verbose_error("Name field occurs twice in '%s'\n", path);
        if(parse_strict)
            exit(1);
        else
            return;
    }

    pkg->name = trim_and_sub(pkg, str, path);
}

static void parse_version(Package *pkg, const std::string &str, const char *path) {
    if(!pkg->version.empty()) {
        verbose_error("Version field occurs twice in '%s'\n", path);
        if(parse_strict)
            exit(1);
        else
            return;
    }

    pkg->version = trim_and_sub(pkg, str, path);
}

static void parse_description(Package *pkg, const std::string &str, const char *path) {
    if(!pkg->description.empty()) {
        verbose_error("Description field occurs twice in '%s'\n", path);
        if(parse_strict)
            exit(1);
        else
            return;
    }

    pkg->description = trim_and_sub(pkg, str, path);
}

#define MODULE_SEPARATOR(c) ((c) == ',' || isspace ((guchar)(c)))
#define OPERATOR_CHAR(c) ((c) == '<' || (c) == '>' || (c) == '!' || (c) == '=')

/* A module list is a list of modules with optional version specification,
 * separated by commas and/or spaces. Commas are treated just like whitespace,
 * in order to allow stuff like: Requires: @FRIBIDI_PC@, glib, gmodule
 * where @FRIBIDI_PC@ gets substituted to nothing or to 'fribidi'
 */

typedef enum {
    /* put numbers to help interpret lame debug spew ;-) */
    OUTSIDE_MODULE = 0,
    IN_MODULE_NAME = 1,
    BEFORE_OPERATOR = 2,
    IN_OPERATOR = 3,
    AFTER_OPERATOR = 4,
    IN_MODULE_VERSION = 5
} ModuleSplitState;

#define PARSE_SPEW 0

static std::vector<std::string>
split_module_list(const std::string &str, const char *path) {
    std::vector<std::string> retval;
    std::string::size_type p = 0;
    std::string::size_type start = 0;
    ModuleSplitState state = OUTSIDE_MODULE;
    ModuleSplitState last_state = OUTSIDE_MODULE;

    /*   fprintf (stderr, "Parsing: '%s'\n", str); */

    while(p < str.size()) {
#if PARSE_SPEW
        fprintf (stderr, "p: %c state: %d last_state: %d\n", str.c_str() + (int)p, state, last_state);
#endif

        switch (state){
        case OUTSIDE_MODULE:
            if(!MODULE_SEPARATOR(str[p]))
                state = IN_MODULE_NAME;
            break;

        case IN_MODULE_NAME:
            if(isspace((guchar) str[p])) {
                /* Need to look ahead to determine next state */
                auto s = p;
                while(s < str.size() && isspace((guchar) str[s]))
                    ++s;

                if(s == str.size())
                    state = OUTSIDE_MODULE;
                else if(MODULE_SEPARATOR(str[s]))
                    state = OUTSIDE_MODULE;
                else if(OPERATOR_CHAR(str[s]))
                    state = BEFORE_OPERATOR;
                else
                    state = OUTSIDE_MODULE;
            } else if(MODULE_SEPARATOR(str[p]))
                state = OUTSIDE_MODULE; /* comma precludes any operators */
            break;

        case BEFORE_OPERATOR:
            /* We know an operator is coming up here due to lookahead from
             * IN_MODULE_NAME
             */
            if(isspace((guchar) str[p]))
                ; /* no change */
            else if(OPERATOR_CHAR(str[p]))
                state = IN_OPERATOR;
            else
                throw "Unreachable code";
            break;

        case IN_OPERATOR:
            if(!OPERATOR_CHAR(str[p]))
                state = AFTER_OPERATOR;
            break;

        case AFTER_OPERATOR:
            if(!isspace((guchar) str[p]))
                state = IN_MODULE_VERSION;
            break;

        case IN_MODULE_VERSION:
            if(MODULE_SEPARATOR(str[p]))
                state = OUTSIDE_MODULE;
            break;

        default:
            throw "Unreachable code.";
        }

        if(state == OUTSIDE_MODULE && last_state != OUTSIDE_MODULE) {
            /* We left a module */
            std::string module = str.substr(start, p - start);
            retval.push_back(module);

#if PARSE_SPEW
            fprintf (stderr, "found module: '%s'\n", module);
#endif

            /* reset start */
            start = p;
        }

        last_state = state;
        ++p;
    }

    if(p != start) {
        /* get the last module */
        std::string module = str.substr(start, p - start);
        retval.push_back(module);

#if PARSE_SPEW
        fprintf (stderr, "found module: '%s'\n", module);
#endif

    }

    return retval;
}

std::vector<RequiredVersion>
parse_module_list(Package *pkg, const std::string &str_, const char *path) {
    std::vector<RequiredVersion> retval;

    auto split = split_module_list(str_, path);

    for(auto &str : split) {
        std::string::size_type p = 0;
        std::string::size_type start = 0;

        RequiredVersion ver;
        ver.comparison = ALWAYS_MATCH;
        ver.owner = pkg;

        while(p<str.size() && MODULE_SEPARATOR(str[p]))
            ++p;

        start = p;

        while(p<str.size() && !isspace((guchar) str[p]))
            ++p;

        std::string package_name = str.substr(start, p-start);
        while(p<str.size() && MODULE_SEPARATOR(str[p])) {
            ++p;
        }

        if(package_name.empty()) {
            verbose_error("Empty package name in Requires or Conflicts in file '%s'\n", path);
            if(parse_strict)
                exit(1);
            else
                continue;
        }

        ver.name = package_name;

        start = p;

        while(p<str.size() && !isspace((guchar) str[p])) {
            ++p;
        }

        std::string comparison = str.substr(start, p-start);
        while(p<str.size() && isspace((guchar) str[p])) {
            ++p;
        }

        if(!comparison.empty()) {
            if(comparison == "=")
                ver.comparison = EQUAL;
            else if(comparison == ">=")
                ver.comparison = GREATER_THAN_EQUAL;
            else if(comparison == "<=")
                ver.comparison = LESS_THAN_EQUAL;
            else if(comparison == ">")
                ver.comparison = GREATER_THAN;
            else if(comparison == "<")
                ver.comparison = LESS_THAN;
            else if(comparison == "!=")
                ver.comparison = NOT_EQUAL;
            else {
                verbose_error("Unknown version comparison operator '%s' after "
                        "package name '%s' in file '%s'\n", comparison.c_str(), ver.name.c_str(), path);
                if(parse_strict)
                    exit(1);
                else
                    continue;
            }
        }

        start = p;

        while(p<str.size() && !MODULE_SEPARATOR(str[p]))
            ++p;

        std::string version = str.substr(start, p-start);
        while(p<str.size() && MODULE_SEPARATOR(str[p])) {
            ++p;
        }

        if(ver.comparison != ALWAYS_MATCH && version.empty()) {
            verbose_error("Comparison operator but no version after package "
                    "name '%s' in file '%s'\n", ver.name.c_str(), path);
            if(parse_strict)
                exit(1);
            else {
                ver.version = "0";
                continue;
            }
        }

        if(!version.empty()) {
            ver.version = version;
        }

        g_assert(!ver.name.empty());
        retval.push_back(ver);
    }

    return retval;
}

static std::vector<std::string>
split_module_list2(const char *str, const char *path) {
    std::vector<std::string> retval;
    const char *p;
    const char *start;
    ModuleSplitState state = OUTSIDE_MODULE;
    ModuleSplitState last_state = OUTSIDE_MODULE;

    /*   fprintf (stderr, "Parsing: '%s'\n", str); */

    start = str;
    p = str;

    while(*p) {
#if PARSE_SPEW
        fprintf (stderr, "p: %c state: %d last_state: %d\n", *p, state, last_state);
#endif

        switch (state){
        case OUTSIDE_MODULE:
            if(!MODULE_SEPARATOR(*p))
                state = IN_MODULE_NAME;
            break;

        case IN_MODULE_NAME:
            if(isspace((guchar) *p)) {
                /* Need to look ahead to determine next state */
                const char *s = p;
                while(*s && isspace((guchar) *s))
                    ++s;

                if(*s == '\0')
                    state = OUTSIDE_MODULE;
                else if(MODULE_SEPARATOR(*s))
                    state = OUTSIDE_MODULE;
                else if(OPERATOR_CHAR(*s))
                    state = BEFORE_OPERATOR;
                else
                    state = OUTSIDE_MODULE;
            } else if(MODULE_SEPARATOR(*p))
                state = OUTSIDE_MODULE; /* comma precludes any operators */
            break;

        case BEFORE_OPERATOR:
            /* We know an operator is coming up here due to lookahead from
             * IN_MODULE_NAME
             */
            if(isspace((guchar) *p))
                ; /* no change */
            else if(OPERATOR_CHAR(*p))
                state = IN_OPERATOR;
            else
                g_assert_not_reached ()
                ;
            break;

        case IN_OPERATOR:
            if(!OPERATOR_CHAR(*p))
                state = AFTER_OPERATOR;
            break;

        case AFTER_OPERATOR:
            if(!isspace((guchar) *p))
                state = IN_MODULE_VERSION;
            break;

        case IN_MODULE_VERSION:
            if(MODULE_SEPARATOR(*p))
                state = OUTSIDE_MODULE;
            break;

        default:
            g_assert_not_reached ()
            ;
        }

        if(state == OUTSIDE_MODULE && last_state != OUTSIDE_MODULE) {
            /* We left a module */
            char *module = g_strndup(start, p - start);
            retval.push_back(module);
            g_free(module);

#if PARSE_SPEW
            fprintf (stderr, "found module: '%s'\n", module);
#endif

            /* reset start */
            start = p;
        }

        last_state = state;
        ++p;
    }

    if(p != start) {
        /* get the last module */
        char *module = g_strndup(start, p - start);
        retval.push_back(module);
        g_free(module);

#if PARSE_SPEW
        fprintf (stderr, "found module: '%s'\n", module);
#endif

    }

    return retval;
}

std::vector<RequiredVersion>
parse_module_list2(Package *pkg, const std::string &str, const char *path) {
    std::vector<std::string> split;
    std::vector<RequiredVersion> retval;

    split = split_module_list2(str.c_str(), path);

    for(const auto &iter : split) {
        RequiredVersion ver;
        char *p;
        char *start;
        std::string tmpstr{iter};

        p = &tmpstr[0];

        ver.comparison = ALWAYS_MATCH;
        ver.owner = pkg;

        while(*p && MODULE_SEPARATOR(*p))
            ++p;

        start = p;

        while(*p && !isspace((guchar) *p))
            ++p;

        while(*p && MODULE_SEPARATOR(*p)) {
            *p = '\0';
            ++p;
        }

        if(*start == '\0') {
            verbose_error("Empty package name in Requires or Conflicts in file '%s'\n", path);
            if(parse_strict)
                exit(1);
            else
                continue;
        }

        ver.name = start;

        start = p;

        while(*p && !isspace((guchar) *p))
            ++p;

        while(*p && isspace((guchar) *p)) {
            *p = '\0';
            ++p;
        }

        if(*start != '\0') {
            if(strcmp(start, "=") == 0)
                ver.comparison = EQUAL;
            else if(strcmp(start, ">=") == 0)
                ver.comparison = GREATER_THAN_EQUAL;
            else if(strcmp(start, "<=") == 0)
                ver.comparison = LESS_THAN_EQUAL;
            else if(strcmp(start, ">") == 0)
                ver.comparison = GREATER_THAN;
            else if(strcmp(start, "<") == 0)
                ver.comparison = LESS_THAN;
            else if(strcmp(start, "!=") == 0)
                ver.comparison = NOT_EQUAL;
            else {
                verbose_error("Unknown version comparison operator '%s' after "
                        "package name '%s' in file '%s'\n", start, ver.name.c_str(), path);
                if(parse_strict)
                    exit(1);
                else
                    continue;
            }
        }

        start = p;

        while(*p && !MODULE_SEPARATOR(*p))
            ++p;

        while(*p && MODULE_SEPARATOR(*p)) {
            *p = '\0';
            ++p;
        }

        if(ver.comparison != ALWAYS_MATCH && *start == '\0') {
            verbose_error("Comparison operator but no version after package "
                    "name '%s' in file '%s'\n", ver.name.c_str(), path);
            if(parse_strict)
                exit(1);
            else {
                ver.version = "0";
                continue;
            }
        }

        if(*start != '\0') {
            ver.version = start;
        }

        g_assert(!ver.name.empty());
        retval.push_back(ver);
    }

    return retval;
}

static void parse_requires(Package *pkg, const std::string &str, const char *path) {
    if(!pkg->requires.empty()) {
        verbose_error("Requires field occurs twice in '%s'\n", path);
        if(parse_strict)
            exit(1);
        else
            return;
    }

    auto trimmed = trim_and_sub(pkg, str, path);
    pkg->requires_entries = parse_module_list(pkg, trimmed, path);
}

static void parse_requires_private(Package *pkg, const std::string &str, const char *path) {
    std::string trimmed;

    if(!pkg->requires_private.empty()) {
        verbose_error("Requires.private field occurs twice in '%s'\n", path);
        if(parse_strict)
            exit(1);
        else
            return;
    }

    trimmed = trim_and_sub(pkg, str, path);
    pkg->requires_private_entries = parse_module_list(pkg, trimmed, path);
}

static void parse_conflicts(Package *pkg, const std::string &str, const char *path) {

    if(!pkg->conflicts.empty()) {
        verbose_error("Conflicts field occurs twice in '%s'\n", path);
        if(parse_strict)
            exit(1);
        else
            return;
    }

    auto trimmed = trim_and_sub(pkg, str, path);
    pkg->conflicts = parse_module_list2(pkg, trimmed, path);
}

static std::string strdup_escape_shell(const std::string &s) {
    std::string r;
    r.reserve(s.size() + 10);
    for(char c : s) {
        if((c < '$') || (c > '$' && s[0] < '(') || (c > ')' && c < '+') || (c > ':' && c < '=')
                || (c > '=' && c < '@') || (c > 'Z' && c < '^') || (c == '`')
                || (c > 'z' && c < '~') || (c > '~')) {
            r.push_back('\\');
        }
        r.push_back(c);
    }
    return r;
}

static void _do_parse_libs(Package *pkg, int argc, char **argv) {
    int i;
#ifdef G_OS_WIN32
    const char *L_flag = (msvc_syntax ? "/libpath:" : "-L");
    const char *l_flag = (msvc_syntax ? "" : "-l");
    const char *lib_suffix = (msvc_syntax ? ".lib" : "");
#else
    const char *L_flag = "-L";
    const char *l_flag = "-l";
    const char *lib_suffix = "";
#endif

    i = 0;
    while(i < argc) {
        Flag flag;
        auto tmp = trim_string(argv[i]);
        std::string arg = strdup_escape_shell(tmp);
        const char *p;
        p = arg.data();

        if(p[0] == '-' && p[1] == 'l' &&
        /* -lib: is used by the C# compiler for libs; it's not an -l
         flag. */
        (strncmp(p, "-lib:", 5) != 0)) {
            p += 2;
            while(*p && isspace((guchar) *p))
                ++p;

            flag.type = LIBS_l;
            flag.arg = g_strconcat(l_flag, p, lib_suffix, NULL);
            pkg->libs.push_back(flag);
        } else if(p[0] == '-' && p[1] == 'L') {
            p += 2;
            while(*p && isspace((guchar) *p))
                ++p;

            flag.type = LIBS_L;
            flag.arg = g_strconcat(L_flag, p, NULL);
            pkg->libs.push_back(flag);
        } else if((strcmp("-framework", p) == 0 || strcmp("-Wl,-framework", p) == 0) && i + 1 < argc) {
            /* Mac OS X has a -framework Foo which is really one option,
             * so we join those to avoid having -framework Foo
             * -framework Bar being changed into -framework Foo Bar
             * later
             */
            auto tmp = trim_string(argv[i + 1]);

            auto framework = strdup_escape_shell(tmp);
            flag.type = LIBS_OTHER;
            flag.arg = arg;
            flag.arg += " ";
            flag.arg += framework;
            pkg->libs.push_back(flag);
            i++;
        } else if(!arg.empty()) {
            flag.type = LIBS_OTHER;
            flag.arg = arg;
            pkg->libs.push_back(flag);
        } else {
            /* flag wasn't used */
        }

        ++i;
    }

}

static void parse_libs(Package *pkg, const std::string &str, const char *path) {
    /* Strip out -l and -L flags, put them in a separate list. */

    char **argv = NULL;
    int argc = 0;
    GError *error = NULL;

    if(pkg->libs_num > 0) {
        verbose_error("Libs field occurs twice in '%s'\n", path);
        if(parse_strict)
            exit(1);
        else
            return;
    }

    auto trimmed = trim_and_sub(pkg, str, path);

    if(!trimmed.empty() && !g_shell_parse_argv(trimmed.c_str(), &argc, &argv, &error)) {
        verbose_error("Couldn't parse Libs field into an argument vector: %s\n", error ? error->message : "unknown");
        if(parse_strict)
            exit(1);
        else {
            return;
        }
    }

    _do_parse_libs(pkg, argc, argv);

    g_strfreev(argv);
    pkg->libs_num++;
}

static void parse_libs_private(Package *pkg, const std::string &str, const char *path) {
    /*
     List of private libraries.  Private libraries are libraries which
     are needed in the case of static linking or on platforms not
     supporting inter-library dependencies.  They are not supposed to
     be used for libraries which are exposed through the library in
     question.  An example of an exposed library is GTK+ exposing Glib.
     A common example of a private library is libm.

     Generally, if include another library's headers in your own, it's
     a public dependency and not a private one.
     */

    char **argv = NULL;
    int argc = 0;
    GError *error = NULL;

    if(pkg->libs_private_num > 0) {
        verbose_error("Libs.private field occurs twice in '%s'\n", path);
        if(parse_strict)
            exit(1);
        else
            return;
    }

    auto trimmed = trim_and_sub(pkg, str, path);

    if(!trimmed.empty() && !g_shell_parse_argv(trimmed.c_str(), &argc, &argv, &error)) {
        verbose_error("Couldn't parse Libs.private field into an argument vector: %s\n",
                error ? error->message : "unknown");
        if(parse_strict)
            exit(1);
        else {
            return;
        }
    }

    _do_parse_libs(pkg, argc, argv);

    g_strfreev(argv);

    pkg->libs_private_num++;
}

std::vector<std::string> parse_shell_string(std::string const& in)
{
    std::vector<std::string> out;
    std::string arg;

    char quoteChar = 0;

    for(auto ch : in) {

        if (quoteChar == '\\') {
            arg.push_back(ch);
            quoteChar = 0;
            continue;
        }

        if (quoteChar && ch != quoteChar) {
            arg.push_back(ch);
            continue;
        }

        switch (ch)
        {
        case '\'':
        case '\"':
        case '\\':
            quoteChar = quoteChar ? 0 : ch;
            break;

        case ' ':
        case '\t':
        case '\n':

            if (!arg.empty()) {
                out.push_back(arg);
                arg.clear();
            }
            break;

        default:
            arg.push_back(ch);
            break;
        }
    }

    if (!arg.empty()) {
        out.push_back(arg);
    }

    return out;
}

static void parse_cflags(Package *pkg, const std::string &str, const char *path) {
    /* Strip out -I flags, put them in a separate list. */

    if(!pkg->cflags.empty()) {
        verbose_error("Cflags field occurs twice in '%s'\n", path);
        if(parse_strict)
            exit(1);
        else
            return;
    }

    auto trimmed = trim_and_sub(pkg, str, path);

    auto argv = parse_shell_string(trimmed);
    if(!trimmed.empty() && FALSE) {
        verbose_error("Couldn't parse Cflags field into an argument vector: %s\n", "unknown");
        if(parse_strict)
            exit(1);
        else {
            return;
        }
    }

    for(int i=0; i<(int)argv.size(); ++i) {
        Flag flag;
        auto tmp = trim_string(argv[i].c_str());
        std::string arg = strdup_escape_shell(tmp);
        const char *p = arg.data();

        if(p[0] == '-' && p[1] == 'I') {
            p += 2;
            while(*p && isspace((guchar) *p))
                ++p;

            flag.type = CFLAGS_I;
            flag.arg = g_strconcat("-I", p, NULL);
            pkg->cflags.push_back(flag);
        } else if((("-idirafter" == arg) || ("-isystem" == arg)) && (i + 1 < (int)argv.size())) {
            auto tmp = trim_string(argv[i + 1].c_str());
            std::string option = strdup_escape_shell(tmp);

            /* These are -I flags since they control the search path */
            flag.type = CFLAGS_I;
            flag.arg = arg;
            flag.arg += " ";
            flag.arg += option;
            pkg->cflags.push_back(flag);
            i++;
        } else if(!arg.empty()) {
            flag.type = CFLAGS_OTHER;
            flag.arg = arg;
            pkg->cflags.push_back(flag);
        } else {
            /* flag wasn't used */
        }
    }

}

static void parse_url(Package *pkg, const std::string &str, const char *path) {
    if(!pkg->url.empty()) {
        verbose_error("URL field occurs twice in '%s'\n", path);
        if(parse_strict)
            exit(1);
        else
            return;
    }

    pkg->url = trim_and_sub(pkg, str, path);
}

static void parse_line(Package *pkg, const std::string &untrimmed, const char *path, bool ignore_requires,
        bool ignore_private_libs, bool ignore_requires_private) {
    std::string::size_type p;

    debug_spew("  line>%s\n", untrimmed);

    auto str = trim_string(untrimmed);

    if(str.empty()) /* empty line */
    {
        return;
    }

    p=0;

    /* Get first word */
    while((str[p] >= 'A' && str[p] <= 'Z') ||
            (str[p] >= 'a' && str[p] <= 'z') ||
            (str[p] >= '0' && str[p] <= '9') ||
            str[p] == '_' || str[p] == '.')
        p++;

    auto tag = str.substr(0, p);

    while(str.length() < p && isspace(str[p]))
        ++p;

    if(str[p] == ':') {
        /* keyword */
        ++p;
        while(p<str.length() && isspace(str[p]))
            ++p;

        auto remainder = str.substr(p, std::string::npos);
        if(tag == "Name")
            parse_name(pkg, remainder, path);
        else if(tag == "Description")
            parse_description(pkg, remainder, path);
        else if(tag == "Version")
            parse_version(pkg, remainder, path);
        else if(tag == "Requires.private") {
            if(!ignore_requires_private)
                parse_requires_private(pkg, remainder, path);
        } else if(tag == "Requires") {
            if(ignore_requires == false)
                parse_requires(pkg, remainder, path);
            else
                goto cleanup;
        } else if(tag == "Libs.private") {
            if(!ignore_private_libs)
                parse_libs_private(pkg, remainder, path);
        } else if(tag == "Libs")
            parse_libs(pkg, remainder, path);
        else if(tag == "Cflags" || tag == "CFlags")
            parse_cflags(pkg, remainder, path);
        else if(tag == "Conflicts")
            parse_conflicts(pkg, remainder, path);
        else if(tag == "URL")
            parse_url(pkg, remainder, path);
        else {
            /* we don't error out on unknown keywords because they may
             * represent additions to the .pc file format from future
             * versions of pkg-config.  We do make a note of them in the
             * debug spew though, in order to help catch mistakes in .pc
             * files. */
            debug_spew("Unknown keyword '%s' in '%s'\n", tag, path);
        }
    } else if(str[p] == '=') {
        /* variable */
        char *varname;

        ++p;
        while(p<str.length() && isspace(str[p]))
            ++p;

        if(define_prefix && tag == prefix_variable) {
            /* This is the prefix variable. Try to guesstimate a value for it
             * for this package from the location of the .pc file.
             */
            char *base;
            bool is_pkgconfigdir;

            base = g_path_get_basename(pkg->pcfiledir.c_str());
            is_pkgconfigdir = g_ascii_strcasecmp(base, "pkgconfig") == 0;
            g_free(base);
            if(is_pkgconfigdir) {
                /* It ends in pkgconfig. Good. */
                char *q;
                char *prefix;

                /* Keep track of the original prefix value. */
                pkg->orig_prefix = str.substr(p, std::string::npos);

                /* Get grandparent directory for new prefix. */
                q = g_path_get_dirname(pkg->pcfiledir.c_str());
                prefix = g_path_get_dirname(q);
                g_free(q);

                /* Turn backslashes into slashes or
                 * g_shell_parse_argv() will eat them when ${prefix}
                 * has been expanded in parse_libs().
                 */
                q = prefix;
                while(*q) {
                    if(*q == '\\')
                        *q = '/';
                    q++;
                }

                /* Now escape the special characters so that there's no danger
                 * of arguments that include the prefix getting split.
                 */
                q = prefix;
                std::string prefix_ = strdup_escape_shell(prefix);
                g_free(q);

                varname = g_strdup(tag.c_str());
                debug_spew(" Variable declaration, '%s' overridden with '%s'\n", tag, prefix_.c_str());
                pkg->vars[varname] = prefix_;
                goto cleanup;
            }
        } else if(define_prefix && !pkg->orig_prefix.empty() &&
                strncmp(str.data()+p, pkg->orig_prefix.c_str(), pkg->orig_prefix.length()) == 0 &&
                G_IS_DIR_SEPARATOR (str[p+pkg->orig_prefix.length()])) {
            std::string oldstr = str;

            auto lookup = pkg->vars.find(prefix_variable);
            std::string tmp;
            if(lookup != pkg->vars.end()) {
                tmp = lookup->second;
            }
            str = tmp + str.substr(p + pkg->orig_prefix.length(), std::string::npos);
            p = 0;
        }

        if(pkg->vars.find(tag) != pkg->vars.end()) {
            verbose_error("Duplicate definition of variable '%s' in '%s'\n", tag, path);
            if(parse_strict)
                exit(1);
            else
                goto cleanup;
        }

        varname = g_strdup(tag.c_str());
        auto remainder = str.substr(p, std::string::npos);
        auto varval = trim_and_sub(pkg, remainder, path);

        debug_spew(" Variable declaration, '%s' has value '%s'\n", varname, varval);
        pkg->vars[varname] = varval;

    }

    cleanup:;
}

Package
parse_package_file(const std::string &key, const std::string &path, bool ignore_requires, bool ignore_private_libs,
        bool ignore_requires_private) {
    FILE *f;
    Package pkg;
    std::string str;
    bool one_line = false;

    f = fopen(path.c_str(), "r");

    if(f == NULL) {
        verbose_error("Failed to open '%s': %s\n", path, strerror(errno));

        return Package();
    }

    debug_spew("Parsing package file '%s'\n", path);

    pkg.key = key;

    if(!path.empty()) {
        pkg.pcfiledir = g_dirname(path.c_str());
    } else {
        debug_spew("No pcfiledir determined for package\n");
        pkg.pcfiledir = "???????";
    }

    /* Variable storing directory of pc file */
    pkg.vars["pcfiledir"] = pkg.pcfiledir;

    while(read_one_line(f, str)) {
        one_line = true;

        parse_line(&pkg, str, path.c_str(), ignore_requires, ignore_private_libs, ignore_requires_private);

        str.clear();
    }

    if(!one_line)
        verbose_error("Package file '%s' appears to be empty\n", path);
    fclose(f);

    //pkg->libs = g_list_reverse(pkg->libs);

    return pkg;
}

/* Parse a package variable. When the value appears to be quoted,
 * unquote it so it can be more easily used in a shell. Otherwise,
 * return the raw value.
 */
std::string
parse_package_variable(Package *pkg, const char *variable) {
    std::string value;
    char *unquoted;
    GError *error = NULL;

    value = package_get_var(pkg, variable);
    if(value.empty())
        return value;

    if(value[0] != '"' && value[0] != '\'')
        /* Not quoted, return raw value */
        return value;

    /* Maybe too naive, but assume a fully quoted variable */
    unquoted = g_shell_unquote(value.c_str(), &error);
    if(unquoted) {
        std::string tmp(unquoted);
        g_free(unquoted);
        return tmp;
    } else {
        /* Note the issue, but just return the raw value */
        debug_spew("Couldn't unquote value of \"%s\": %s\n", variable, error ? error->message : "unknown");
        g_clear_error(&error);
        return value;
    }
}
