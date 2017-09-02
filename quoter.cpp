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


#include<quoter.h>

static std::vector<std::string> c_arr_to_cpp(int argc, char **argv) {
    std::vector<std::string> res;
    for(int i=0; i<argc; ++i) {
        res.push_back(argv[i]);
    }
    return res;
}


/*
 * The remaining contents of this file are taken from Glib internals to
 * avoid an external dependency.
 */

static gboolean unquote_string_inplace(gchar* str, gchar** end) {
    gchar* dest;
    gchar* s;
    gchar quote_char;

    g_return_val_if_fail(end != NULL, FALSE);
    g_return_val_if_fail(str != NULL, FALSE);

    dest = s = str;

    quote_char = *s;

    if(!(*s == '"' || *s == '\'')) {
        throw "Quoted text doesn’t begin with a quotation mark";
        *end = str;
        return FALSE;
    }

    /* Skip the initial quote mark */
    ++s;

    if(quote_char == '"') {
        while(*s) {
            g_assert(s > dest); /* loop invariant */

            switch (*s){
            case '"':
                /* End of the string, return now */
                *dest = '\0';
                ++s;
                *end = s;
                return TRUE;
                break;

            case '\\':
                /* Possible escaped quote or \ */
                ++s;
                switch (*s){
                case '"':
                case '\\':
                case '`':
                case '$':
                case '\n':
                    *dest = *s;
                    ++s;
                    ++dest;
                    break;

                default:
                    /* not an escaped char */
                    *dest = '\\';
                    ++dest;
                    /* ++s already done. */
                    break;
                }
                break;

            default:
                *dest = *s;
                ++dest;
                ++s;
                break;
            }

            g_assert(s > dest); /* loop invariant */
        }
    } else {
        while(*s) {
            g_assert(s > dest); /* loop invariant */

            if(*s == '\'') {
                /* End of the string, return now */
                *dest = '\0';
                ++s;
                *end = s;
                return TRUE;
            } else {
                *dest = *s;
                ++dest;
                ++s;
            }

            g_assert(s > dest); /* loop invariant */
        }
    }

    /* If we reach here this means the close quote was never encountered */

    *dest = '\0';

    throw "Unmatched quotation mark in command line or other shell-quoted text";
    *end = s;
    return FALSE;
}

gchar*
g_shell_unquote(const gchar *quoted_string) {
    gchar *unquoted;
    gchar *end;
    gchar *start;
    GString *retval;

    g_return_val_if_fail(quoted_string != NULL, NULL);

    unquoted = g_strdup(quoted_string);

    start = unquoted;
    end = unquoted;
    retval = g_string_new(NULL);

    /* The loop allows cases such as
     * "foo"blah blah'bar'woo foo"baz"la la la\'\''foo'
     */
    while(*start) {
        /* Append all non-quoted chars, honoring backslash escape
         */

        while(*start && !(*start == '"' || *start == '\'')) {
            if(*start == '\\') {
                /* all characters can get escaped by backslash,
                 * except newline, which is removed if it follows
                 * a backslash outside of quotes
                 */

                ++start;
                if(*start) {
                    if(*start != '\n')
                        g_string_append_c(retval, *start);
                    ++start;
                }
            } else {
                g_string_append_c(retval, *start);
                ++start;
            }
        }

        if(*start) {
            if(!unquote_string_inplace(start, &end)) {
                goto error;
            } else {
                g_string_append(retval, start);
                start = end;
            }
        }
    }

    g_free(unquoted);
    return g_string_free(retval, FALSE);

    error:

    g_free(unquoted);
    g_string_free(retval, TRUE);
    return NULL;
}

static void ensure_token(GString **token) {
    if(*token == NULL)
        *token = g_string_new(NULL);
}

static void delimit_token(GString **token, GSList **retval) {
    if(*token == NULL)
        return;

    *retval = g_slist_prepend(*retval, g_string_free(*token, FALSE));

    *token = NULL;
}

static GSList*
tokenize_command_line(const gchar *command_line) {
    gchar current_quote;
    const gchar *p;
    GString *current_token = NULL;
    GSList *retval = NULL;
    gboolean quoted;

    current_quote = '\0';
    quoted = FALSE;
    p = command_line;

    while(*p) {
        if(current_quote == '\\') {
            if(*p == '\n') {
                /* we append nothing; backslash-newline become nothing */
            } else {
                /* we append the backslash and the current char,
                 * to be interpreted later after tokenization
                 */
                ensure_token(&current_token);
                g_string_append_c(current_token, '\\');
                g_string_append_c(current_token, *p);
            }

            current_quote = '\0';
        } else if(current_quote == '#') {
            /* Discard up to and including next newline */
            while(*p && *p != '\n')
                ++p;

            current_quote = '\0';

            if(*p == '\0')
                break;
        } else if(current_quote) {
            if(*p == current_quote &&
            /* check that it isn't an escaped double quote */
            !(current_quote == '"' && quoted)) {
                /* close the quote */
                current_quote = '\0';
            }

            /* Everything inside quotes, and the close quote,
             * gets appended literally.
             */

            ensure_token(&current_token);
            g_string_append_c(current_token, *p);
        } else {
            switch (*p){
            case '\n':
                delimit_token(&current_token, &retval);
                break;

            case ' ':
            case '\t':
                /* If the current token contains the previous char, delimit
                 * the current token. A nonzero length
                 * token should always contain the previous char.
                 */
                if(current_token && current_token->len > 0) {
                    delimit_token(&current_token, &retval);
                }

                /* discard all unquoted blanks (don't add them to a token) */
                break;

                /* single/double quotes are appended to the token,
                 * escapes are maybe appended next time through the loop,
                 * comment chars are never appended.
                 */

            case '\'':
            case '"':
                ensure_token(&current_token);
                g_string_append_c(current_token, *p);

                /* FALL THRU */
            case '\\':
                current_quote = *p;
                break;

            case '#':
                if(p == command_line) { /* '#' was the first char */
                    current_quote = *p;
                    break;
                }
                switch (*(p - 1)){
                case ' ':
                case '\n':
                case '\0':
                    current_quote = *p;
                    break;
                default:
                    ensure_token(&current_token);
                    g_string_append_c(current_token, *p);
                    break;
                }
                break;

            default:
                /* Combines rules 4) and 6) - if we have a token, append to it,
                 * otherwise create a new token.
                 */
                ensure_token(&current_token);
                g_string_append_c(current_token, *p);
                break;
            }
        }

        /* We need to count consecutive backslashes mod 2,
         * to detect escaped doublequotes.
         */
        if(*p != '\\')
            quoted = FALSE;
        else
            quoted = !quoted;

        ++p;
    }

    delimit_token(&current_token, &retval);

    if(current_quote) {
        if(current_quote == '\\')
            throw "Text ended just after a “\\” character. (The text was “%s”)";
//                     command_line);
        else
            throw "Text ended before matching quote was found for %c."
                    " (The text was “%s”)";
//                     current_quote, command_line);

        goto error;
    }

    if(retval == NULL) {
        throw "Text was empty (or contained only whitespace)";

        goto error;
    }

    /* we appended backward */
    retval = g_slist_reverse(retval);

    return retval;

    error:

    g_slist_free_full(retval, g_free);

    return NULL;
}

std::vector<std::string> g_shell_parse_argv2(const char *command_line, int *argcp, char ***argvp) {
    /* Code based on poptParseArgvString() from libpopt */
    GSList *tokens = NULL;
    GSList *tmp_list;
    std::vector<std::string> args;

    if(command_line == NULL) {
        throw "Null passed to argv";
    }

    tokens = tokenize_command_line(command_line);
    if(tokens == NULL)
        return std::vector<std::string>{};

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

    tmp_list = tokens;
    while(tmp_list) {
        args.push_back(g_shell_unquote(static_cast<const char*>(tmp_list->data)));

        /* Since we already checked that quotes matched up in the
         * tokenizer, this shouldn't be possible to reach I guess.
         */
        if(args.back().empty())
            throw "Should not be reached";

        tmp_list = g_slist_next(tmp_list);
    }


    return args;

}
