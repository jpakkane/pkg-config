/*  Copyright 2000 Red Hat, Inc.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this library; if not, see <http://www.gnu.org/licenses/>.
 */


module quoter;
import std.stdio;

/*
 * The remaining contents of this file are taken from Glib internals to
 * avoid an external dependency.
 */

static string unquote_string(const string str, ref int s) {
    string dest;
    dest.reserve(str.length - s);
    char quote_char;

    quote_char = str[s];

    if(!(str[s] == '"' || str[s] == '\'')) {
        throw new Exception("Quoted text doesn’t begin with a quotation mark");
    }

    /* Skip the initial quote mark */
    ++s;

    if(quote_char == '"') {
        while(s<str.length) {
            assert(s > dest.length); /* loop invariant */

            switch (str[s]){
            case '"':
                /* End of the string, return now */
                ++s;
                return dest;

            case '\\':
                /* Possible escaped quote or \ */
                ++s;
                switch (str[s]){
                case '"':
                case '\\':
                case '`':
                case '$':
                case '\n':
                    dest ~= str[s];
                    ++s;
                    break;

                default:
                    /* not an escaped char */
                    dest ~= '\\';
                    /* ++s already done. */
                    break;
                }
                break;

            default:
                dest ~= str[s];
                ++s;
                break;
            }

            assert(s > dest.length); /* loop invariant */
        }
    } else {
        while(s<str.length) {
            assert(s > dest.length); /* loop invariant */

            if(str[s] == '\'') {
                /* End of the string, return now */
                ++s;
                return dest;
            } else {
                dest ~= str[s];
                ++s;
            }

            assert(s > dest.length); /* loop invariant */
        }
    }

    /* If we reach here this means the close quote was never encountered */

    throw new Exception("Unmatched quotation mark in command line or other shell-quoted text");
}

static string shell_unquote(const string quoted_string) {
    int start;
    string retval;

    auto unquoted = quoted_string;

    start = 0;

    /* The loop allows cases such as
     * "foo"blah blah'bar'woo foo"baz"la la la\'\''foo'
     */
    while(start<quoted_string.length) {
        /* Append all non-quoted chars, honoring backslash escape
         */

        while(start<quoted_string.length && !(quoted_string[start] == '"' || quoted_string[start] == '\'')) {
            if(quoted_string[start]== '\\') {
                /* all characters can get escaped by backslash,
                 * except newline, which is removed if it follows
                 * a backslash outside of quotes
                 */

                ++start;
                if(start<quoted_string.length) {
                    if(quoted_string[start] != '\n')
                        retval ~= quoted_string[start];
                    ++start;
                }
            } else {
                retval ~= quoted_string[start];
                ++start;
            }
        }

        if(start<quoted_string.length) {
            auto uq = unquote_string(quoted_string, start);
            retval ~= uq;
        }
    }

    return retval;

}

static void delimit_token(string token, ref string[] retval) {
    if(token.length == 0)
        return;

    retval ~= token;
}

static string[]
tokenize_command_line(const ref string command_line) {
    char current_quote;
    int p = 0;
    string current_token;
    string[] retval;
    bool quoted;

    current_quote = '\0';
    quoted = false;

    while(p < command_line.length) {
        if(current_quote == '\\') {
            if(command_line[p] == '\n') {
                /* we append nothing; backslash-newline become nothing */
            } else {
                /* we append the backslash and the current char,
                 * to be interpreted later after tokenization
                 */
                current_token ~= '\\';
                current_token ~= command_line[p];
            }

            current_quote = '\0';
        } else if(current_quote == '#') {
            /* Discard up to and including next newline */
            while(p < command_line.length && command_line[p] != '\n')
                ++p;

            current_quote = '\0';

            if(p == command_line.length)
                break;
        } else if(current_quote) {
            if(command_line[p] == current_quote &&
            /* check that it isn't an escaped double quote */
            !(current_quote == '"' && quoted)) {
                /* close the quote */
                current_quote = '\0';
            }

            /* Everything inside quotes, and the close quote,
             * gets appended literally.
             */

            current_token ~= command_line[p];
        } else {
            switch (command_line[p]){
            case '\n':
                delimit_token(current_token, retval);
                break;

            case ' ':
            case '\t':
                /* If the current token contains the previous char, delimit
                 * the current token. A nonzero length
                 * token should always contain the previous char.
                 */
                if(current_token.length > 0) {
                    delimit_token(current_token, retval);
                }

                /* discard all unquoted blanks (don't add them to a token) */
                break;

                /* single/double quotes are appended to the token,
                 * escapes are maybe appended next time through the loop,
                 * comment chars are never appended.
                 */

            case '\'':
            case '"':
                current_token ~= command_line[p];

                /* FALL THRU */
            case '\\':
                current_quote = command_line[p];
                break;

            case '#':
                if(p == 0) { /* '#' was the first char */
                    current_quote = command_line[p];
                    break;
                }
                switch (command_line[p - 1]){
                case ' ':
                case '\n':
                case '\0':
                    current_quote = command_line[p];
                    break;
                default:
                    current_token ~= command_line[p];
                    break;
                }
                break;

            default:
                /* Combines rules 4) and 6) - if we have a token, append to it,
                 * otherwise create a new token.
                 */
                current_token ~= command_line[p];
                break;
            }
        }

        /* We need to count consecutive backslashes mod 2,
         * to detect escaped doublequotes.
         */
        if(command_line[p] != '\\')
            quoted = false;
        else
            quoted = !quoted;

        ++p;
    }

    delimit_token(current_token, retval);

    if(current_quote) {
        if(current_quote == '\\')
            throw new Exception("Text ended just after a “\\” character. (The text was “%s”)");
//                     command_line);
        else
            throw new Exception("Text ended before matching quote was found for %c."
                    " (The text was “%s”)");
//                     current_quote, command_line);

    }

    if(retval.length == 0 && command_line.length > 0) {
        throw new Exception("Text was empty (or contained only whitespace)");
    }

    return retval;

}

string[] parse_shell_commandline(const ref string command_line) {
    /* Code based on poptParseArgvString() from libpopt */
    string[] args;

    if(command_line.length == 0) {
        return args;
    }

    auto tokens = tokenize_command_line(command_line);
    if(tokens.length == 0) {
        string[] empty;
        return empty;
    }
    /* Because we can't have introduced any new blank space into the
     * tokens (we didn't do any new expansions), we don't need to
     * perform field splitting. If we were going to honor IFS or do any
     * expansions, we would have to do field splitting on each word
     * here. Also, if we were going to do any expansion we would need to
     * remove any zero-length words that didn't contain quotes
     * originally; but since there's no expansion we know all words have
     * nonzero length, unless they contain quotes.
     *
     * So, we simply remove quotes, and don't do any field splitting or
     * empty word removal, since we know there was no way to introduce
     * such things.
     */

    foreach(t; tokens) {
        args ~= shell_unquote(t);

        /* Since we already checked that quotes matched up in the
         * tokenizer, this shouldn't be possible to reach I guess.
         */
        if(args[args.length - 1].length == 0)
            throw new Exception("Should not be reached");

    }

    return args;

}
