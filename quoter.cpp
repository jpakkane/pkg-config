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
/*
 * The contents of this file are taken from Glib internals to
 * avoid an external dependency.
 */
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
tokenize_command_line(const gchar *command_line, GError **error) {
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
    g_assert(error == NULL || *error != NULL);

    g_slist_free_full(retval, g_free);

    return NULL;
}

gboolean g_shell_parse_argv2(const gchar *command_line, gint *argcp, gchar ***argvp, GError **error) {
    /* Code based on poptParseArgvString() from libpopt */
    gint argc = 0;
    gchar **argv = NULL;
    GSList *tokens = NULL;
    gint i;
    GSList *tmp_list;

    g_return_val_if_fail(command_line != NULL, FALSE);

    tokens = tokenize_command_line(command_line, error);
    if(tokens == NULL)
        return FALSE;

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

    argc = g_slist_length(tokens);
    argv = g_new0(gchar*, argc + 1);
    i = 0;
    tmp_list = tokens;
    while(tmp_list) {
        argv[i] = g_shell_unquote(static_cast<const char*>(tmp_list->data), error);

        /* Since we already checked that quotes matched up in the
         * tokenizer, this shouldn't be possible to reach I guess.
         */
        if(argv[i] == NULL)
            goto failed;

        tmp_list = g_slist_next(tmp_list);
        ++i;
    }

    g_slist_free_full(tokens, g_free);

    if(argcp)
        *argcp = argc;

    if(argvp)
        *argvp = argv;
    else
        g_strfreev(argv);

    return TRUE;

    failed:

    g_assert(error == NULL || *error != NULL);
    g_strfreev(argv);
    g_slist_free_full(tokens, g_free);

    return FALSE;
}
