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

module utils;

import std.path;
import std.array;
import std.algorithm;
import std.string;

const char SEARCHPATH_SEPARATOR = ':';
const string PKG_CONFIG_SYSTEM_INCLUDE_PATH = "/usr/lib/pkgconfig";


bool IS_DIR_SEPARATOR(char c) {
    return c == SEARCHPATH_SEPARATOR;
}
string get_basename(const string s) {
    return s.baseName;
}

string get_dirname(const string s) {
    return s.dirName;
}

bool string_starts_with(const string s, const string prefix) {
    return s.startsWith(prefix);
}

string[] split_whitespace(const string s) {
    return s.split();

}

string[] split_string(const string s, const char separator) {
    return s.split(separator);
}

string strip_whitespace(const string s) {
    return chomp(s);
}
