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

module parse;
import utils;
import main: verbose_error, debug_spew;
import quoter;
import pkg: Package, RequiredVersion, package_get_var, ComparisonType;
import std.file;
import std.stdio;
import std.string;
import core.stdc.stdio;
import core.stdc.ctype: isspace;
import core.stdc.stdlib;

const bool ENABLE_DEFINE_PREFIX = true;

bool parse_strict = true;
bool define_prefix = ENABLE_DEFINE_PREFIX;
string prefix_variable = "prefix";

/*
#ifdef _WIN32
bool msvc_syntax = false;
#endif
*/

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
static bool read_one_line(ref File stream, ref string str) {
    bool quoted = false;
    bool comment = false;
    int n_read = 0;

    str = "";

    while(true) {
        int c;


        if(stream.eof()) {
            if(quoted)
                str ~= '\\';

            goto done;
        } else {
            c = stream.rawRead(new char[1])[0];
            n_read++;
        }
        
        if(quoted) {
            quoted = false;

            switch (c){
            case '#':
                str ~= '#';
                break;
            case '\r':
            case '\n': {
                if(!stream.eof()) {
                    auto next_c = stream.rawRead(new char[1])[0];

                    if(!(c == '\r' && next_c == '\n') || (c == '\n' && next_c == '\r'))
                        stream.seek(-1);
                }
                break;
            }
            default:
                str ~=  '\\';
                str ~= c;
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
                if(!stream.eof()) {
                    auto next_c = stream.rawRead(new char[1])[0];

                    if(!((c == '\r' && next_c == '\n') || (c == '\n' && next_c == '\r')))
                        stream.seek(-1);
                }
                goto done;
            }
            default:
                if(!comment)
                    str ~= c;
            }
        }
    }

    done:

    return n_read > 0;
}

static string
trim_string(const ref string str) {
    return strip(str);
}

static string
trim_and_sub(const Package pkg, const string str, const string path) {
    string subst;
    int p = 0;

    auto trimmed = trim_string(str);

    while(p<trimmed.length) {
        if(str[p] == '$' && str[p+1] == '$') {
            /* escaped $ */
            subst ~= '$';
            p += 2;
        } else if(str[p] == '$' && str[p+1] == '{') {
            /* variable */
            string varval;

            auto var_start = p+2;

            /* Get up to close brace. */
            while(p<str.length && str[p] != '}')
                ++p;

            auto varname = str[var_start .. p-var_start];

            ++p; /* past brace */

            varval = package_get_var(pkg, varname);

            if(varval.length == 0) {
                verbose_error("Variable '%s' not defined in '%s'\n", varname, path);
                if(parse_strict)
                    exit(1);
            }

            subst ~= varval;
        } else {
            subst ~= str[p];

            ++p;
        }
    }

    return subst;
}

static void parse_name(Package pkg, string str, const string path) {
    if(pkg.name.length > 0) {
        verbose_error("Name field occurs twice in '%s'\n", path);
        if(parse_strict)
            exit(1);
        else
            return;
    }

    pkg.name = trim_and_sub(pkg, str, path);
}

static void parse_version(Package pkg, const string str, const string path) {
    if(pkg.version_ != "") {
        verbose_error("Version field occurs twice in '%s'\n", path);
        if(parse_strict)
            exit(1);
        else
            return;
    }

    pkg.version_ = trim_and_sub(pkg, str, path);
}

static void parse_description(Package pkg, const string str, const string path) {
    if(pkg.description != "") {
        verbose_error("Description field occurs twice in '%s'\n", path);
        if(parse_strict)
            exit(1);
        else
            return;
    }

    pkg.description = trim_and_sub(pkg, str, path);
}

bool MODULE_SEPARATOR(const int c) {
    return ((c) == ',' || isspace ((c)));
}

bool OPERATOR_CHAR(const int c) {
    return ((c) == '<' || (c) == '>' || (c) == '!' || (c) == '=');
}

/* A module list is a list of modules with optional version specification,
 * separated by commas and/or spaces. Commas are treated just like whitespace,
 * in order to allow stuff like: Requires: @FRIBIDI_PC@, glib, gmodule
 * where @FRIBIDI_PC@ gets substituted to nothing or to 'fribidi'
 */

enum ModuleSplitState {
    /* put numbers to help interpret lame debug spew ;-) */
    OUTSIDE_MODULE = 0,
    IN_MODULE_NAME = 1,
    BEFORE_OPERATOR = 2,
    IN_OPERATOR = 3,
    AFTER_OPERATOR = 4,
    IN_MODULE_VERSION = 5
};

immutable int PARSE_SPEW=0;

static string[]
split_module_list(const string str, const string path) {
    string[] retval;
    int p = 0;
    int start = 0;
    ModuleSplitState state = ModuleSplitState.OUTSIDE_MODULE;
    ModuleSplitState last_state = ModuleSplitState.OUTSIDE_MODULE;

    /*   fprintf (stderr, "Parsing: '%s'\n", str); */

    while(p < str.length) {
        /*
#if PARSE_SPEW
        fprintf (stderr, "p: %c state: %d last_state: %d\n", str + (int)p, state, last_state);
#endif
*/
        switch (state){
        case ModuleSplitState.OUTSIDE_MODULE:
            if(!MODULE_SEPARATOR(str[p]))
                state = ModuleSplitState.IN_MODULE_NAME;
            break;

        case ModuleSplitState.IN_MODULE_NAME:
            if(isspace(str[p])) {
                /* Need to look ahead to determine next state */
                auto s = p;
                while(s < str.length && isspace( str[s]))
                    ++s;

                if(s == str.length)
                    state = ModuleSplitState.OUTSIDE_MODULE;
                else if(MODULE_SEPARATOR(str[s]))
                    state = ModuleSplitState.OUTSIDE_MODULE;
                else if(OPERATOR_CHAR(str[s]))
                    state = ModuleSplitState.BEFORE_OPERATOR;
                else
                    state = ModuleSplitState.OUTSIDE_MODULE;
            } else if(MODULE_SEPARATOR(str[p]))
                state = ModuleSplitState.OUTSIDE_MODULE; /* comma precludes any operators */
            break;

        case ModuleSplitState.BEFORE_OPERATOR:
            /* We know an operator is coming up here due to lookahead from
             * IN_MODULE_NAME
             */
            if(isspace( str[p])) {
                /* no change */
            } else if(OPERATOR_CHAR(str[p])) {
                state = ModuleSplitState.IN_OPERATOR;
            } else {
                throw "Unreachable code";
            }
            break;

        case ModuleSplitState.IN_OPERATOR:
            if(!OPERATOR_CHAR(str[p]))
                state = ModuleSplitState.AFTER_OPERATOR;
            break;

        case ModuleSplitState.AFTER_OPERATOR:
            if(!isspace( str[p]))
                state = ModuleSplitState.IN_MODULE_VERSION;
            break;

        case ModuleSplitState.IN_MODULE_VERSION:
            if(MODULE_SEPARATOR(str[p]))
                state = ModuleSplitState.OUTSIDE_MODULE;
            break;

        default:
            throw new Exception("Unreachable code.");
        }

        if(state == ModuleSplitState.OUTSIDE_MODULE && last_state != ModuleSplitState.OUTSIDE_MODULE) {
            /* We left a module */
            string module_ = str[start .. p - start];
            retval ~= module_;
/*
#if PARSE_SPEW
            fprintf (stderr, "found module: '%s'\n", module);
#endif
*/
            /* reset start */
            start = p;
        }

        last_state = state;
        ++p;
    }

    if(p != start) {
        /* get the last module */
        string module_ = str[start .. p - start];
        retval ~= module_;
/*
#if PARSE_SPEW
        fprintf (stderr, "found module: '%s'\n", module);
#endif
*/
    }

    return retval;
}

RequiredVersion[]
parse_module_list(Package pkg, const string str_, const string path) {
    RequiredVersion[] retval;

    auto split = split_module_list(str_, path);

    foreach(str; split) {
        int p = 0;
        int start = 0;

        RequiredVersion ver;
        ver.comparison = ALWAYS_MATCH;
        ver.owner = pkg;

        while(p<str.length && MODULE_SEPARATOR(str[p]))
            ++p;

        start = p;

        while(p<str.length && !isspace( str[p]))
            ++p;

        string package_name = str.substr(start, p-start);
        while(p<str.length && MODULE_SEPARATOR(str[p])) {
            ++p;
        }

        if(package_name == "") {
            verbose_error("Empty package name in Requires or Conflicts in file '%s'\n", path);
            if(parse_strict)
                exit(1);
            else
                continue;
        }

        ver.name = package_name;

        start = p;

        while(p<str.length && !isspace(str[p])) {
            ++p;
        }

        string comparison = str[start .. p-start];
        while(p<str.length && isspace(str[p])) {
            ++p;
        }

        if(comparison != "") {
            if(comparison == "=")
                ver.comparison = ComparisonType.EQUAL;
            else if(comparison == ">=")
                ver.comparison = ComparisonType.GREATER_THAN_EQUAL;
            else if(comparison == "<=")
                ver.comparison = ComparisonType.LESS_THAN_EQUAL;
            else if(comparison == ">")
                ver.comparison = ComparisonType.GREATER_THAN;
            else if(comparison == "<")
                ver.comparison = ComparisonType.LESS_THAN;
            else if(comparison == "!=")
                ver.comparison = ComparisonType.NOT_EQUAL;
            else {
                verbose_error("Unknown version comparison operator '%s' after " ~
                        "package name '%s' in file '%s'\n", comparison, ver.name, path);
                if(parse_strict)
                    exit(1);
                else
                    continue;
            }
        }

        start = p;

        while(p<str.length && !MODULE_SEPARATOR(str[p]))
            ++p;

        string version_ = str[start .. p-start];
        while(p<str.length && MODULE_SEPARATOR(str[p])) {
            ++p;
        }

        if(ver.comparison != ComparisonType.ALWAYS_MATCH && version_ == "") {
            verbose_error("Comparison operator but no version after package " ~
                    "name '%s' in file '%s'\n", ver.name, path);
            if(parse_strict)
                exit(1);
            else {
                ver.version_ = "0";
                continue;
            }
        }

        if(version_ != "") {
            ver.version_ = version_;
        }

        assert(ver.name != "");
        retval ~= ver;
    }

    return retval;
}

static string[]
split_module_list2(const string str, const string path) {
    string[] retval;
    int p = 0, start = 0;
    ModuleSplitState state = ModuleSplitState.OUTSIDE_MODULE;
    ModuleSplitState last_state = ModuleSplitState.OUTSIDE_MODULE;

    /*   fprintf (stderr, "Parsing: '%s'\n", str); */

    while(p<str.length) {
/*
#if PARSE_SPEW
        fprintf (stderr, "p: %c state: %d last_state: %d\n", *p, state, last_state);
#endif
*/
        switch (state){
        case ModuleSplitState.OUTSIDE_MODULE:
            if(!MODULE_SEPARATOR(str[p]))
                state = ModuleSplitState.IN_MODULE_NAME;
            break;

        case ModuleSplitState.IN_MODULE_NAME:
            if(isspace(str[p])) {
                /* Need to look ahead to determine next state */
                auto s = p;
                while(s<str.length && isspace(str[s]))
                    ++s;

                if(s>=str.length)
                    state = ModuleSplitState.OUTSIDE_MODULE;
                else if(MODULE_SEPARATOR(str[s]))
                    state = ModuleSplitState.OUTSIDE_MODULE;
                else if(OPERATOR_CHAR(str[s]))
                    state = ModuleSplitState.BEFORE_OPERATOR;
                else
                    state = ModuleSplitState.OUTSIDE_MODULE;
            } else if(MODULE_SEPARATOR(str[p]))
                state = ModuleSplitState.OUTSIDE_MODULE; /* comma precludes any operators */
            break;

        case ModuleSplitState.BEFORE_OPERATOR:
            /* We know an operator is coming up here due to lookahead from
             * IN_MODULE_NAME
             */
            if(isspace(str[p])) {
                /* no change */
            } else if(OPERATOR_CHAR(str[p])) {
                state = ModuleSplitState.IN_OPERATOR;
            } else {
                throw new Exception("Unreachable code.");
            }
            break;

        case ModuleSplitState.IN_OPERATOR:
            if(!OPERATOR_CHAR(str[p]))
                state = ModuleSplitState.AFTER_OPERATOR;
            break;

        case ModuleSplitState.AFTER_OPERATOR:
            if(!isspace(str[p]))
                state = ModuleSplitState.IN_MODULE_VERSION;
            break;

        case ModuleSplitState.IN_MODULE_VERSION:
            if(MODULE_SEPARATOR(str[p]))
                state = ModuleSplitState.OUTSIDE_MODULE;
            break;

        default:
            throw new Exception("Unreachable code");
        }

        if(state == ModuleSplitState.OUTSIDE_MODULE && last_state != ModuleSplitState.OUTSIDE_MODULE) {
            /* We left a module */
            auto module_ = str[start .. p - start];
            retval ~= module_;
/*
#if PARSE_SPEW
            fprintf (stderr, "found module: '%s'\n", module);
#endif
*/
            /* reset start */
            start = p;
        }

        last_state = state;
        ++p;
    }

    if(p != start) {
        /* get the last module */
        auto module_ = str[start .. p - start];
        retval ~= module_;
/*
#if PARSE_SPEW
        fprintf (stderr, "found module: '%s'\n", module);
#endif
*/
    }

    return retval;
}

RequiredVersion[]
parse_module_list2(Package pkg, const string str, const string path) {
    string[] split;
    RequiredVersion[] retval;

    split = split_module_list2(str, path);

    foreach(iter; split) {
        RequiredVersion ver;
        int p=0, start=0;
        string tmpstr = iter;

        ver.comparison = ComparisonType.ALWAYS_MATCH;
        ver.owner = pkg;

        while(p<iter.length && MODULE_SEPARATOR(iter[p]))
            ++p;

        start = p;

        while(p<iter.length && !isspace(iter[p]))
            ++p;

        auto name = iter[start .. p-start];
        while(p<iter.length && MODULE_SEPARATOR(iter[p])) {
            ++p;
        }

        if(name.empty()) {
            verbose_error("Empty package name in Requires or Conflicts in file '%s'\n", path);
            if(parse_strict)
                exit(1);
            else
                continue;
        }

        ver.name = name;

        start = p;

        while(p<str.length && !isspace(str[p]))
            ++p;

        auto comparer = iter[start .. p-start];
        while(p<iter.length && isspace(iter[p])) {
            ++p;
        }

        if(!comparer.empty()) {
            if(comparer == "=")
                ver.comparison = ComparisonType.EQUAL;
            else if(comparer == ">=")
                ver.comparison = ComparisonType.GREATER_THAN_EQUAL;
            else if(comparer == "<=")
                ver.comparison = ComparisonType.LESS_THAN_EQUAL;
            else if(comparer == ">")
                ver.comparison = ComparisonType.GREATER_THAN;
            else if(comparer == "<")
                ver.comparison = ComparisonType.LESS_THAN;
            else if(comparer == "!=")
                ver.comparison = ComparisonType.NOT_EQUAL;
            else {
                verbose_error("Unknown version comparison operator '%s' after " ~
                        "package name '%s' in file '%s'\n", comparer, ver.name, path);
                if(parse_strict)
                    exit(1);
                else
                    continue;
            }
        }

        start = p;

        while(p<iter.length && !MODULE_SEPARATOR(iter[p]))
            ++p;

        auto number = iter[start .. p-start];
        while(p<iter.length && MODULE_SEPARATOR(iter[p])) {
            ++p;
        }

        if(ver.comparison != ComparisonType.ALWAYS_MATCH && number.empty()) {
            verbose_error("Comparison operator but no version after package " ~
                    "name '%s' in file '%s'\n", ver.name, path);
            if(parse_strict)
                exit(1);
            else {
                ver.version_ = "0";
                continue;
            }
        }

        if(number != "") {
            ver.version_ = number;
        }

        assert(ver.name != "");
        retval ~= ver;
    }

    return retval;
}

static void parse_requires(Package pkg, const string str, const string path) {
    if(pkg.requires != "") {
        verbose_error("Requires field occurs twice in '%s'\n", path);
        if(parse_strict)
            exit(1);
        else
            return;
    }

    auto trimmed = trim_and_sub(pkg, str, path);
    pkg.requires_entries = parse_module_list(pkg, trimmed, path);
}

static void parse_requires_private(Package pkg, const string str, const string path) {
    string trimmed;

    if(pkg.requires_private != "") {
        verbose_error("Requires.private field occurs twice in '%s'\n", path);
        if(parse_strict)
            exit(1);
        else
            return;
    }

    trimmed = trim_and_sub(pkg, str, path);
    pkg.requires_private_entries = parse_module_list(pkg, trimmed, path);
}

static void parse_conflicts(Package pkg, const string str, const string path) {

    if(pkg.conflicts != "") {
        verbose_error("Conflicts field occurs twice in '%s'\n", path);
        if(parse_strict)
            exit(1);
        else
            return;
    }

    auto trimmed = trim_and_sub(pkg, str, path);
    pkg.conflicts = parse_module_list2(pkg, trimmed, path);
}

static string strdup_escape_shell(const string s) {
    string r;
    r.reserve(s.length + 10);
    foreach(c; s) {
        if((c < '$') || (c > '$' && s[0] < '(') || (c > ')' && c < '+') || (c > ':' && c < '=')
                || (c > '=' && c < '@') || (c > 'Z' && c < '^') || (c == '`')
                || (c > 'z' && c < '~') || (c > '~')) {
            r ~= '\\';
        }
        r ~= c;
    }
    return r;
}

static void _do_parse_libs(Package pkg, const string[] args) {
    int i = 0;
/*
#ifdef _WIN32
    const char *L_flag = (msvc_syntax ? "/libpath:" : "-L");
    const string l_flag = (msvc_syntax ? "" : "-l");
    const char *lib_suffix = (msvc_syntax ? ".lib" : "");
#else
*/
    const string L_flag = "-L";
    const string l_flag = "-l";
    const string lib_suffix = "";
//#endif

    while(i < args.length) {
        Flag flag;
        auto tmp = trim_string(args[i]);
        string arg = strdup_escape_shell(tmp);
        int p = 0;

        if(arg[p] == '-' && arg[p+1] == 'l' &&
        /* -lib: is used by the C# compiler for libs; it's not an -l
         flag. */
        !string_starts_with(arg[p .. arg.length], "-lib:")) {
            p += 2;
            while(p<arg.length && isspace(arg[p]))
                ++p;

            flag.type = Flagtype.LIBS_l;
            flag.arg = l_flag + arg[p .. arg.length] + lib_suffix;
            pkg.libs ~= flag;
        } else if(arg[p] == '-' && arg[p+1] == 'L') {
            p += 2;
            while(p<arg.length && isspace(arg[p]))
                ++p;

            flag.type = FlagType.LIBS_L;
            flag.arg = L_flag + arg[p .. arg.length];
            pkg.libs ~= flag;
        } else if((arg[p .. arg.length] == "-framework" || arg[p .. arg.length] == "-Wl,-framework") && (i + 1 < args.length)) {
            /* Mac OS X has a -framework Foo which is really one option,
             * so we join those to avoid having -framework Foo
             * -framework Bar being changed into -framework Foo Bar
             * later
             */
            auto tmp = trim_string(args[i + 1]);

            auto framework = strdup_escape_shell(tmp);
            flag.type = ComparisonType.LIBS_OTHER;
            flag.arg = arg;
            flag.arg += " ";
            flag.arg += framework;
            pkg.libs ~= flag;
            i++;
        } else if(!arg.empty()) {
            flag.type = ComparisonType.LIBS_OTHER;
            flag.arg = arg;
            pkg.libs ~= flag;
        } else {
            /* flag wasn't used */
        }

        ++i;
    }

}


static void parse_libs(Package pkg, const string str, const string path) {
    /* Strip out -l and -L flags, put them in a separate list. */

    if(pkg.libs_num > 0) {
        verbose_error("Libs field occurs twice in '%s'\n", path);
        if(parse_strict)
            exit(1);
        else
            return;
    }

    auto trimmed = trim_and_sub(pkg, str, path);
    string[] args;
    if(!trimmed.empty()) {
        args = parse_shell_commandline(trimmed);
        if(args.empty()) {
            verbose_error("Couldn't parse Libs field into an argument vector: %s\n", "unknown");
            if(parse_strict) {
                exit(1);
            } else {
                return;
            }
        }
    }

    _do_parse_libs(pkg, args);

    pkg.libs_num++;
}

static void parse_libs_private(Package pkg, const string str, const string path) {
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

    if(pkg.libs_private_num > 0) {
        verbose_error("Libs.private field occurs twice in '%s'\n", path);
        if(parse_strict)
            exit(1);
        else
            return;
    }

    auto trimmed = trim_and_sub(pkg, str, path);
    string[] args;
    if(!trimmed.empty()) {
        args = parse_shell_commandline(trimmed);
        if(args.length == 0) {
            verbose_error("Couldn't parse Libs.private field into an argument vector: %s\n",
                    "unknown");
            if(parse_strict)
                exit(1);
            else {
                return;
            }
        }
    }

    _do_parse_libs(pkg, args);

    pkg.libs_private_num++;
}

string[] parse_shell_string(const string in_)
{
    string[] out_;
    string arg;

    char quoteChar = 0;

    foreach(ch; in_) {

        if (quoteChar == '\\') {
            arg ~= ch;
            quoteChar = 0;
            continue;
        }

        if (quoteChar && ch != quoteChar) {
            arg ~= ch;
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
                out_ ~= arg;
                arg.length = 0;
            }
            break;

        default:
            arg ~= ch;
            break;
        }
    }

    if (arg != "") {
        out_ ~= arg;
    }

    return out_;
}

static void parse_cflags(Package pkg, const string str, const string path) {
    /* Strip out -I flags, put them in a separate list. */

    if(pkg.cflags == "") {
        verbose_error("Cflags field occurs twice in '%s'\n", path);
        if(parse_strict)
            exit(1);
        else
            return;
    }

    auto trimmed = trim_and_sub(pkg, str, path);

    auto argv = parse_shell_string(trimmed);
    if(!trimmed.empty() && false) {
        verbose_error("Couldn't parse Cflags field into an argument vector: %s\n", "unknown");
        if(parse_strict)
            exit(1);
        else {
            return;
        }
    }

    for(int i=0; i<argv.length; ++i) {
        Flag flag;
        auto tmp = trim_string(argv[i]);
        string arg = strdup_escape_shell(tmp);
        int p = 0;

        if(p < arg.length-2 && arg[p] == '-' && arg[p+1] == 'I') {
            p += 2;
            while(p<arg.length && isspace(arg[p]))
                ++p;

            flag.type = FlagType.CFLAGS_I;
            flag.arg = string("-I") + arg[p .. arg.length];
            pkg.cflags ~= flag;
        } else if((("-idirafter" == arg) || ("-isystem" == arg)) && (i + 1 < argv.length)) {
            auto tmp2 = trim_string(argv[i + 1]);
            string option = strdup_escape_shell(tmp2);

            /* These are -I flags since they control the search path */
            flag.type = FlagType.CFLAGS_I;
            flag.arg = arg;
            flag.arg += " ";
            flag.arg += option;
            pkg.cflags ~= flag;
            i++;
        } else if(!arg.empty()) {
            flag.type = FlagType.CFLAGS_OTHER;
            flag.arg = arg;
            pkg.cflags ~= flag;
        } else {
            /* flag wasn't used */
        }
    }

}

static void parse_url(Package pkg, const string str, const string path) {
    if(pkg.url != "") {
        verbose_error("URL field occurs twice in '%s'\n", path);
        if(parse_strict)
            exit(1);
        else
            return;
    }

    pkg.url = trim_and_sub(pkg, str, path);
}

static void parse_line(Package pkg, const string untrimmed, const string path, bool ignore_requires,
        bool ignore_private_libs, bool ignore_requires_private) {
    int p;

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

    auto tag = str[0 .. p];

    while(str.length < p && isspace(str[p]))
        ++p;

    if(str[p] == ':') {
        /* keyword */
        ++p;
        while(p<str.length && isspace(str[p]))
            ++p;

        auto remainder = str[p .. str.length];
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

        ++p;
        while(p<str.length && isspace(str[p]))
            ++p;

        if(define_prefix && tag == prefix_variable) {
            /* This is the prefix variable. Try to guesstimate a value for it
             * for this package from the location of the .pc file.
             */
            bool is_pkgconfigdir;

            string base;
            foreach(c; get_basename(pkg.pcfiledir)) {
                import std.ascii;
                base ~= toLower(c);
            }
            is_pkgconfigdir = (base == "pkgconfig");
            if(is_pkgconfigdir) {
                /* It ends in pkgconfig. Good. */

                /* Keep track of the original prefix value. */
                pkg.orig_prefix = str[p .. str.length];

                /* Get grandparent directory for new prefix. */
                auto prefix = get_dirname(get_dirname(pkg.pcfiledir));

                /* Turn backslashes into slashes or
                 * g_shell_parse_argv() will eat them when ${prefix}
                 * has been expanded in parse_libs().
                 */
                for(int i=0; i<prefix.length; i++) {
                    if(prefix[i] == '\\')
                        prefix[i] = '/';
                }

                /* Now escape the special characters so that there's no danger
                 * of arguments that include the prefix getting split.
                 */
                string prefix_ = strdup_escape_shell(prefix);

                debug_spew(" Variable declaration, '%s' overridden with '%s'\n", tag, prefix_);
                pkg.vars[tag] = prefix_;
                goto cleanup;
            }
        } else if(define_prefix && !pkg.orig_prefix.empty() &&
                str[p..str.length] == pkg.orig_prefix &&
                IS_DIR_SEPARATOR (str[p+pkg.orig_prefix.length])) {
            string oldstr = str;

            auto lookup = pkg.vars.find(prefix_variable);
            string tmp;
            if(lookup != pkg.vars.end()) {
                tmp = lookup.second;
            }
            str = tmp + str[p + pkg.orig_prefix.length .. str.length];
            p = 0;
        }

        if(!(tag in pkg.vars)) {
            verbose_error("Duplicate definition of variable '%s' in '%s'\n", tag, path);
            if(parse_strict)
                exit(1);
            else
                goto cleanup;
        }

        auto remainder = str[p .. str.length];
        auto varval = trim_and_sub(pkg, remainder, path);

        debug_spew(" Variable declaration, '%s' has value '%s'\n", tag, varval);
        pkg.vars[tag] = varval;

    }

    cleanup:;
}

Package
parse_package_file(const string key, const string path, bool ignore_requires, bool ignore_private_libs,
        bool ignore_requires_private) {
    File f;
    Package pkg;
    string str;
    bool one_line = false;

    f = File(path, "r");
/*
    if(f == null) {
        verbose_error("Failed to open '%s'\n", path);
        return pkg;
    }
*/
//    debug_spew("Parsing package file '%s'\n", path);

    pkg.key = key;

    if(path != "") {
        pkg.pcfiledir = get_dirname(path);
    } else {
        debug_spew("No pcfiledir determined for package\n");
        pkg.pcfiledir = "???????";
    }

    /* Variable storing directory of pc file */
    pkg.vars["pcfiledir"] = pkg.pcfiledir;

    while(read_one_line(f, str)) {
        one_line = true;

        parse_line(pkg, str, path, ignore_requires, ignore_private_libs, ignore_requires_private);

        str = "";
    }

    if(one_line)
        verbose_error("Package file '%s' appears to be empty\n", path);
    f.close();

    //pkg->libs = g_list_reverse(pkg->libs);

    return pkg;
}

/* Parse a package variable. When the value appears to be quoted,
 * unquote it so it can be more easily used in a shell. Otherwise,
 * return the raw value.
 */
string
parse_package_variable(Package pkg, const string variable) {
    string value;
    string result;

    value = package_get_var(pkg, variable);
    if(value.empty())
        return value;

    if(value[0] != '"' && value[0] != '\'')
        /* Not quoted, return raw value */
        return value;

    // FIXME, this is wrong but the test suite does not
    // have any quotes-within-quotes tests so it passes. :)
    for(int i=1; i<value.length-1; ++i) {
        result ~= value[i];
    }
    return result;
}
