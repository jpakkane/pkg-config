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

#pragma once

#include<string>
#include<vector>

#ifdef _WIN32

#define DIR_SEPARATOR '\\'
#define DIR_SEPARATOR_S "\\"
#define IS_DIR_SEPARATOR(c) ((c) == G_DIR_SEPARATOR || (c) == '/')
#define SEARCHPATH_SEPARATOR ';'
#define SEARCHPATH_SEPARATOR_S ";"

#else

#define DIR_SEPARATOR '/'
#define DIR_SEPARATOR_S "/"
#define IS_DIR_SEPARATOR(c) ((c) == G_DIR_SEPARATOR)
#define SEARCHPATH_SEPARATOR ':'
#define SEARCHPATH_SEPARATOR_S ":"

#endif

std::string get_basename(const std::string &s);

std::string get_dirname(const std::string &s);

bool string_starts_with(const std::string &s, const std::string prefix);

std::vector<std::string> split_whitespace(const std::string &s);

std::vector<std::string> split_string(const std::string &s, const char separator);
