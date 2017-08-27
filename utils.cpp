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

#include<utils.h>
#include<sstream>
#include<istream>
#include<iterator>

std::string get_basename(const std::string &s) {
    const char separator = '/';
    auto loc = s.rfind(separator);
    if(loc == std::string::npos) {
        return ".";
    }
    return s.substr(loc+1, std::string::npos);
}

std::string get_dirname(const std::string &s) {
    const char separator = '/';
    auto loc = s.rfind(separator);
    if(loc == std::string::npos) {
        return ".";
    }
    return s.substr(0, loc);
}

bool string_starts_with(const std::string &s, const std::string prefix) {
    if(prefix.length() > s.length()) {
        return false;
    }
    for(std::string::size_type i=0; i<prefix.size(); i++) {
        if(s[i] != prefix[i]) {
            return false;
        }
    }
    return true;
}

std::vector<std::string> split_whitespace(const std::string &s) {
    std::istringstream buffer(s);
    std::vector<std::string> ret{std::istream_iterator<std::string>(buffer),
                                     std::istream_iterator<std::string>()};
    return ret;

}

std::vector<std::string> split_string(const std::string &s, const char separator) {
    std::stringstream istream(s);
    std::string line;
    std::vector<std::string> result;

    if(std::getline(istream, line, separator)) {
        result.emplace_back(std::move(line));
    }
    return result;
}

static bool is_whitespace(const char c) {
    return c == ' ' || c == '\n' || c == '\t' || c == '\r';
}

std::string strip_whitespace(const std::string &s) {
    std::string::size_type i=0;
    while(i<s.length() && is_whitespace(s[i])) {
        i++;
    }
    std::string result = s.substr(i, std::string::npos);
    while(!s.empty() && is_whitespace(result.back())) {
        result.pop_back();
    }
    return result;
}
