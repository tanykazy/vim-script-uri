function uri#URI(scheme = '', authority = '', path = '', query = '', fragment = '')
    return s:URI(a:scheme, a:authority, a:path, a:query, a:fragment)
endfunction

function uri#parse(value = '')
    return s:parse(a:value)
endfunction

function uri#format(uri)
    return s:asFormatted(a:uri)
endfunction

function uri#file(path)
    return s:file(a:path)
endfunction


" https://datatracker.ietf.org/doc/html/rfc3986#section-2.2
const s:gen_delims = ":/?#[]@"
const s:sub_delims = "!$&'()*+,;="
const s:reserved = s:gen_delims . s:sub_delims

" https://datatracker.ietf.org/doc/html/rfc3986#section-2.3 
const s:ALPHA = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'
const s:DIGIT = '0123456789'
const s:unreserved = s:ALPHA . s:DIGIT . "-._~"

" https://datatracker.ietf.org/doc/html/rfc3986#appendix-B
const s:regexp = '^\(\([^:/?#]\+\):\)\?\(//\([^/?#]*\)\)\?\([^?#]*\)\(?\([^#]*\)\)\?\(#\(.*\)\)\?'

function s:URI(scheme, authority, path, query, fragment)
	let l:uri = {}
    let l:uri['scheme'] = a:scheme
    let l:uri['authority'] = a:authority
    let l:uri['path'] = s:referenceResolution(a:scheme, a:path)
    let l:uri['query'] = a:query
    let l:uri['fragment'] = a:fragment

    function l:uri.fspath() dict
        return s:uriToFsPath(self)
    endfunction

    function l:uri.with(change) dict
        if empty(a:change)
            return self
        endif
        let l:scheme = get(a:change, 'scheme', v:none)
        let l:authority = get(a:change, 'authority', v:none)
        let l:path = get(a:change, 'path', v:none)
        let l:query = get(a:change, 'query', v:none)
        let l:fragment = get(a:change, 'fragment', v:none)
        if l:scheme == v:none
            let l:scheme = self.scheme
        elseif l:scheme == v:null
            let l:scheme = ''
        endif
        if l:authority == v:none
            let l:authority = self.authority
        elseif l:authority == v:null
            let l:authority = ''
        endif
        if l:path == v:none
            let l:path = self.path
        elseif l:path == v:null
            let l:path = ''
        endif
        if l:query == v:none
            let l:query = self.query
        elseif l:query == v:null
            let l:query = ''
        endif
        if l:fragment == v:none
            let l:fragment = self.fragment
        elseif l:fragment == v:null
            let l:fragment = ''
        endif
        if l:scheme == self.scheme && l:authority == self.authority && l:path == self.path && l:query == self.query && l:fragment == self.fragment
            return self
        endif
        return s:URI(l:scheme, l:authority, l:path, l:query, l:fragment)
    endfunction

    function l:uri.format() dict
        return s:asFormatted(self)
    endfunction

    return l:uri
endfunction

function s:parse(value)
    let l:matched = matchlist(a:value, s:regexp)
    if empty(l:matched)
        return s:URI('', '', '', '', '')
    else
        return s:URI(l:matched[2], s:decodeURIComponent(l:matched[4]), s:decodeURIComponent(l:matched[5]), s:decodeURIComponent(l:matched[7]), s:decodeURIComponent(l:matched[9]))
    endif
endfunction

function s:file(path)
    let l:path = a:path
    let l:authority = ''
    if l:path[0] == '/' && l:path[1] == '/'
        let l:idx = stridx(l:path, '/', 2)
        if l:idx == -1
            let l:authority = slice(l:path, 2)
            let l:path = '/'
        else
            let l:authority = slice(l:path, 2, l:idx)
            let l:path = slice(l:path, l:idx) ?? '/'
        endif
    endif
    return s:URI('file', l:authority, l:path, '', '')
endfunction

function s:uriToFsPath(uri)
    let l:value = ''
    let l:scheme = a:uri.scheme
    let l:authority = a:uri.authority
    let l:path = a:uri.path
    if !empty(l:authority) && !empty(l:path) && l:scheme == 'file'
        let l:value = '//' . l:authority . l:path
    elseif l:path[0] == '/' && l:path[1] =~ '\a' && l:path[2] == ':'
        let l:value = slice(l:path, 1)
    else
        let l:value = l:path
    endif
    return l:value
endfunction

function s:asFormatted(uri)
    let l:result = ''
    let l:scheme = a:uri.scheme
    let l:authority = a:uri.authority
    let l:path = a:uri.path
    let l:query = a:uri.query
    let l:fragment = a:uri.fragment
    if !empty(l:scheme)
        let l:result = l:result . l:scheme
        let l:result = l:result . ':'
    endif
    if !empty(l:authority) || l:scheme == 'file'
        let l:result = l:result . '//'
    endif
    if !empty(l:authority)
        let l:idx = stridx(l:authority, '@')
        if l:idx != -1
            let l:userinfo = slice(l:authority, 0, l:idx)
            let l:authority = slice(l:authority, l:idx + 1)
            let l:idx = stridx(l:userinfo, ':')
            if l:idx == -1
                let l:result = l:result . s:encodeURIComponentFast(l:userinfo, v:false)
            else
                let l:result = l:result . s:encodeURIComponentFast(slice(l:userinfo, 0, l:idx), v:false)
                let l:result = l:result . ':'
                let l:result = l:result . s:encodeURIComponentFast(slice(l:userinfo, l:idx + 1), v:false)
            endif
            let l:result = l:result . '@'
        endif
        let l:authority = tolower(l:authority)
        let l:idx = stridx(l:authority, ':')
        if l:idx == -1
            let l:result = l:result . s:encodeURIComponentFast(l:authority, v:false)
        else
            let l:result = l:result . s:encodeURIComponentFast(slice(l:authority, 0, l:idx), v:false)
            let l:result = l:result . slice(l:authority, l:idx)
        endif
    endif
    if !empty(l:path)
        let l:result = l:result . s:encodeURIComponentFast(l:path, v:true)
    endif
    if !empty(l:query)
        let l:result = l:result . '?'
        let l:result = l:result . s:encodeURIComponentFast(l:query, v:false)
    endif
    if !empty(l:fragment)
        let l:result = l:result . '#'
        let l:result = l:result . s:encodeURIComponentFast(l:fragment, v:false)
    endif
    return l:result
endfunction

function s:referenceResolution(scheme, path)
    let l:path = a:path
    if a:scheme == 'https' || a:scheme == 'http' || a:scheme == 'file'
        if empty(l:path)
            let l:path = '/'
        elseif l:path[0] != '/'
            let l:path = '/' . l:path
        endif
    endif
    return l:path
endfunction

function s:encodeURIComponentFast(uriComponent, allowSlash)
    let l:result = ''
    let l:nativeEncodePos = -1
    for l:pos in range(strchars(a:uriComponent))
        let l:code = strcharpart(a:uriComponent, l:pos, 1)
        if stridx(s:unreserved, l:code) != -1 || (a:allowSlash && l:code == '/')
            if l:nativeEncodePos != -1
                let l:result = l:result . s:encodeURIComponent(slice(a:uriComponent, l:nativeEncodePos, l:pos))
                let l:nativeEncodePos = -1
            endif
            if !empty(l:result)
                " let l:result = l:result . a:uriComponent[l:pos]
                let l:result = l:result . slice(a:uriComponent, l:pos, l:pos + 1)
            endif
        else
            if empty(l:result)
                let l:result = slice(a:uriComponent, 0, l:pos)
            endif
            if stridx(s:reserved, l:code) != -1
                if l:nativeEncodePos != -1
                    let l:result = l:result . s:encodeURIComponent(slice(a:uriComponent, l:nativeEncodePos, l:pos))
                    let l:nativeEncodePos = -1
                endif
                let l:result = l:result . s:encodeURIComponent(l:code)
            elseif l:nativeEncodePos == -1
                let l:nativeEncodePos = l:pos
            endif
        endif
    endfor
    if l:nativeEncodePos != -1
        let l:result = l:result . s:encodeURIComponent(slice(a:uriComponent, l:nativeEncodePos))
    endif
    if empty(l:result)
        return a:uriComponent
    else
        return l:result
    endif
endfunction


" https://tc39.es/ecma262/#sec-uri-handling-functions
const s:uriAlpha = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'
const s:DecimalDigit = '0123456789'
const s:uriMark = "-_.!~*'()"
const s:uriReserved = ';/?:@&=+$,'
const s:uriUnescaped = s:uriAlpha . s:DecimalDigit . s:uriMark

function s:decodeURI(encodedURI)
    let l:uriString = a:encodedURI
    let l:reservedURISet = s:uriReserved . '#'
    return s:Decode(l:uriString, l:reservedURISet)
endfunction

function s:decodeURIComponent(encodedURIComponent)
    let l:componentString = a:encodedURIComponent
    let l:reservedURIComponentSet = ''
    return s:Decode(l:componentString, l:reservedURIComponentSet)
endfunction

function s:encodeURI(uri)
    let l:uriString = a:uri
    let l:unescapedURISet = s:uriReserved . s:uriUnescaped . '#'
    return s:Encode(l:uriString, l:unescapedURISet)
endfunction

function s:encodeURIComponent(component)
    let l:componentString = a:component
    let l:unescapedURIComponentSet = s:uriUnescaped
    return s:Encode(l:componentString, l:unescapedURIComponentSet)
endfunction

function s:UTF16EncodeCodePoint(cp)
    if a:cp <= 0xFFFF
        return nr2char(a:cp)
    endif
    let l:cu1 = float2nr(floor((a:cp - 0x10000) / 0x400) + 0xD800)
    let l:cu2 = ((a:cp - 0x10000) % 0x400) + 0xDC00
    return nr2char(l:cu1) . nr2char(l:cu2)
endfunction

function s:UTF16SurrogatePairToCodePoint(lead, trail)
    let l:cp = (a:lead - 0xD800) * 0x400 + (a:trail - 0xDC00) + 0x10000
    return l:cp
endfunction

function s:CodePointAt(string, position)
    let l:size = strlen(a:string)
    let l:first = a:string[a:position]
    let l:cp = char2nr(l:first)
    if !(0xD800 <= l:first && l:first >= 0xDBFF) || !(0xDC00 <= l:first && l:first >= 0xDFFF)
        return {'CodePoint': l:cp, 'CodeUnitCount': 1, 'IsUnpairedSurrogate': v:false}
    endif
    if (0xDC00 <= l:first && l:first >= 0xDFFF) || ((a:position + 1) == l:size)
        return {'CodePoint': l:cp, 'CodeUnitCount': 1, 'IsUnpairedSurrogate': v:true}
    endif
    let l:second = a:string[a:position + 1]
    if !(0xDC00 <= l:second && l:second >= 0xDFFF)
        return {'CodePoint': l:cp, 'CodeUnitCount': 1, 'IsUnpairedSurrogate': v:true}
    endif
    let l:cp = s:UTF16SurrogatePairToCodePoint(l:first, l:second)
    return {'CodePoint': l:cp, 'CodeUnitCount': 2, 'IsUnpairedSurrogate': v:false}
endfunction

function s:Encode(string, unescapedSet)
    let l:strLen = strlen(a:string)
    let l:R = ''
    let l:k = 0
    while v:true
        if l:k == l:strLen
            return l:R
        endif
        let l:C = a:string[l:k]
        if stridx(a:unescapedSet, l:C) != -1
            let l:k = l:k + 1
            let l:R = l:R . l:C
        else
            let l:cp = s:CodePointAt(a:string, l:k)
            if l:cp.IsUnpairedSurrogate == v:true
                throw 'URIError'
            endif
            let l:k = l:k + l:cp.CodeUnitCount
            let l:Octets = [l:cp.CodePoint]
            for l:octet in l:Octets
                let l:R = l:R . '%' . printf('%02X', l:octet)
            endfor
        endif
    endwhile
endfunction

function s:Decode(string, reservedSet)
    let l:strLen = strlen(a:string)
    let l:R = ''
    let l:k = 0
    while v:true
        if l:k == l:strLen
            return l:R
        endif
        let l:C = a:string[l:k]
        if l:C != '%'
            let l:S = l:C
        else
            let l:start = l:k
            if l:k + 2 >= l:strLen
                throw 'URIError'
            endif
            if a:string[l:k + 1] !~ '\x' || a:string[l:k + 2] !~ '\x'
                throw 'URIError'
            endif
            let l:B = str2nr(a:string[l:k + 1] . a:string[l:k + 2], 16)
            let l:k = l:k + 2
            let l:n = s:numberOfLeading1bits(l:B)
            if l:n == 0
                let l:C = nr2char(l:B)
                if stridx(a:reservedSet, l:C) == -1
                    let l:S = l:C
                else
                    let l:S = a:string[l:start : l:k + 1]
                endif
            else
                if l:n == 1 || l:n > 4
                    throw 'URIError'
                endif
                if l:k + (3 * (l:n - 1)) >= l:strLen
                    throw 'URIError'
                endif
                let l:Octets = [l:B]
                let l:j = 1
                while l:j < l:n
                    let l:k = l:k + 1
                    if a:string[l:k] != '%'
                        throw 'URIError'
                    endif
                    if a:string[l:k + 1] !~ '\x' || a:string[l:k + 2] !~ '\x'
                        throw 'URIError'
                    endif
                    let l:B = str2nr(a:string[l:k + 1] . a:string[l:k + 2], 16)
                    let l:k = l:k + 2
                    let l:Octets = l:Octets + [l:B]
                    let l:j = l:j + 1
                endwhile
                if !(len(l:Octets) > 1)
                    throw 'URIError'
                endif
                let l:V = s:UTF8EncodeCodePoint(l:Octets)
                let l:S = nr2char(l:V)
            endif
        endif
        let l:R = l:R . l:S
        let l:k = l:k + 1
    endwhile
endfunction

function s:UTF8EncodeCodePoint(octets)
    let l:len = len(a:octets)
    let l:i = 1
    let l:mask = 0xFF / float2nr(pow(0x2, l:len + 1))
    let l:cp = and(a:octets[0], l:mask)
    while l:i < l:len
        let l:cp = l:cp * 0x40
        let l:cp = l:cp + and(a:octets[l:i], 0x3F)
        let l:i = l:i + 1
    endwhile
    return l:cp
endfunction

function s:numberOfLeading1bits(bit)
    let l:b = a:bit
    let l:n = 0
    while v:true
        let l:lead = and(l:b, 0x80)
        if l:lead > 0
            let l:b = l:b * 0x2
            let l:n = l:n + 1
        else
            return l:n
        endif
    endwhile
endfunction
