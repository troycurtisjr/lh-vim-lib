"=============================================================================
" File:         autoload/lh/path.vim                               {{{1
" Author:       Luc Hermitte <EMAIL:hermitte {at} free {dot} fr>
"               <URL:http://github.com/LucHermitte/lh-vim-lib>
" License:      GPLv3 with exceptions
"               <URL:http://github.com/LucHermitte/lh-vim-lib/tree/master/License.md>
" Version:      3.6.2
let s:k_version = 3602
" Created:      23rd Jan 2007
" Last Update:  14th Jan 2016
"------------------------------------------------------------------------
" Description:
"       Functions related to the handling of pathnames
"
"------------------------------------------------------------------------
" Installation:
"       Drop this file into {rtp}/autoload/lh
"       Requires Vim7+
" History:
"       v 1.0.0 First Version
"       (*) Functions moved from searchInRuntimeTime
"       v 2.0.1
"       (*) lh#path#Simplify() becomes like |simplify()| except for trailing
"       v 2.0.2
"       (*) lh#path#SelectOne()
"       (*) lh#path#ToRelative()
"       v 2.0.3
"       (*) lh#path#GlobAsList()
"       v 2.0.4
"       (*) lh#path#StripStart()
"       v 2.0.5
"       (*) lh#path#StripStart() interprets '.' as getcwd()
"       v 2.2.0
"       (*) new functions: lh#path#common(), lh#path#to_dirname(),
"           lh#path#depth(), lh#path#relative_to(), lh#path#to_regex(),
"           lh#path#find()
"       (*) lh#path#simplify() fixed
"       (*) lh#path#to_relative() use simplify()
"       v 2.2.2
"       (*) lh#path#strip_common() fixed
"       (*) lh#path#simplify() new optional parameter: make_relative_to_pwd
"       v 2.2.5
"       (*) fix lh#path#to_dirname('') -> return ''
"       v 2.2.6
"       (*) fix lh#path#glob_as_list() does not return the same path several
"           times
"       v 2.2.7
"       (*) fix lh#path#strip_start() to strip as much as possible.
"       (*) lh#path#glob_as_list() changed to handle **
"       v 3.0.0
"       (*) GPLv3
"       v 3.1.0
"       (*) lh#path#glob_as_list accepts a new option: mustSort which value
"       true by default.
"       v 3.1.1
"       (*) lh#path#strip_start() shall support very big lists of dirnames now.
"       v 3.1.4
"       (*) Force to display numerous choices from lh#path#select_one()
"       vertically
"       v 3.1.9
"       (*) lh#path#is_in() that resolves symbolic links to tell wheither a
"       file is within a directory
"       (*) lh#path#readlink() that resolves symbolic links (where readlink is
"       available)
"       v 3.1.11
"       (*) lh#path#strip_start() can find the best match in the middle of a
"       sequence. This fixes a bug in Mu-Template: the filetype of
"       template-files wasn't always correctly working.
"       v 3.1.12
"       (*) New function: lh#path#add_if_exists()
"       v 3.1.14
"       (*) New functions: lh#path#split() and lh#path#join()
"       (*) lh#path#common() fixed as matchstr('^\zs\(.*\)\ze.\{-}@@\1.*$')
"           doesn't work as expected
"       v 3.1.17
"       (*) Fix lh#start#strip_start() to work under windows
"       v 3.2.0
"       (*) New function lh#path#find_in_parents() used in local_vimrc
"       v 3.2.1
"       (*) Bug fix: lh#path#find_in_parents() no more infinite recursion
"           possible
"       v 3.2.2
"       (*) Bug fix: lh#path#find_in_parents() better handling of some paths
"       (see Issue #50)
"       (*) New function lh#path#shellslash()
"       (*) Several functions fixed to take &shellslash into account
"       v3.2.4:
"       (*) new function lh#path#munge()
"       v3.3.0:
"       (*) Steal functions from system-tools
"       v3.3.11
"       (*) Fix lh#path#to_relative() and lh#path#depth()
"       v3.6.1
"       (*) ENH: Use new logging framework
"       v3.6.2
"       (*) BUG: Support comma-separated lists in lh#path#munge()
" TODO:
"       (*) Fix #simplify('../../bar')
" }}}1
"=============================================================================


"=============================================================================
" Avoid global reinclusion {{{1
let s:cpo_save=&cpo
set cpo&vim

"=============================================================================
" ## Misc Functions     {{{1
" # Version {{{2
function! lh#path#version()
  return s:k_version
endfunction

" # Debug {{{2
let s:verbose = get(s:, 'verbose', 0)
function! lh#path#verbose(...)
  if a:0 > 0 | let s:verbose = a:1 | endif
  return s:verbose
endfunction

function! s:Log(...)
  call call('lh#log#this', a:000)
endfunction

function! s:Verbose(...)
  if s:verbose
    call call('s:Log', a:000)
  endif
endfunction

function! lh#path#debug(expr) abort
  return eval(a:expr)
endfunction


"=============================================================================
" ## Exported functions {{{1
" # Public {{{2

" Function: lh#path#fix(pathname [, shellslash [, quote_char ]]) {{{3
" This function was FixEnsurePath from system_tools
function! lh#path#fix(pathname, ...) abort
  " Parameters       {{{4
  " Ignore the last slash or backslash character, if any
  let pathname   = matchstr(a:pathname, '^.*[^/\\]')
  " Default value for the quote character
  let quote_char = ''
  " Determine if 'shellslash' exists (dos-like platforms)
  if lh#os#OnDOSWindows()
    if lh#os#system_detected() == 'msdos'
      let shellslash = 0
    else
      let shellslash = &shellslash
    endif
  else "unix
    let shellslash = 1
  endif
  " Determine if we will use slashes or backslashes to distinguish directories
  if a:0 >= 1   "
    let shellslash = a:1
    if a:0 >= 2
      let quote_char = a:2
    endif
  endif

  " Smart definition of quote chars for $COMSPEC
  if (lh#os#system_detected() == 'msdos') && !shellslash && (''==quote_char)
    if (&shell =~ 'command\.com')
      if pathname =~ ' '
        " should also test long directory-names...
        " Best: AVOID command.com !!!
        if &verbose >= 1
          call lh#common#error_msg('lh#path#fix: '.
                \ 'Problem expected because of the space in <'.pathname.'>')
        endif
      else
        let quote_char = ''
      endif
    else
      let quote_char = '"'
    endif
  endif

  " Fix the pathname {{{4
  if shellslash
    " return substitute(dname, '\\\([^ ]\|$\)', '/\1', 'g')
    let res = substitute(
          \ substitute(pathname, '\\\([^ ]\|$\)', '/\1', 'g'),
          \ '\(^\|[^\\]\) ', '\1\\ ', 'g')
  else
    " return substitute(
          " \ substitute(pathname, '\([^\\]\) ', '\1\\ ', 'g'),
          " \ '/', '\\', 'g')
    let res = substitute(
          \ substitute(pathname, '\\ ', ' ', 'g'),
          \ '/', '\\', 'g')
  endif
  " Note: problem to take care (that explains the complex substition schemes):
  " sometimes the path passed to the function mix the two writtings, e.g.:
  " "c:\Program Files/longpath/some\ spaces/foo"
  " }}}4
  return quote_char . res . quote_char
endfunction

" Function: lh#path#simplify({pathname}, [make_relative_to_pwd=true]) {{{3
" Like |simplify()|, but also strip the leading './'
" It seems unable to simplify '..\' when compiled without +shellslash
function! lh#path#simplify(pathname, ...)
  let make_relative_to_pwd = a:0 == 0 || a:1 == 1
  let pathname = simplify(a:pathname)
  let pathname = substitute(pathname, '^\%(\.[/\\]\)\+', '', '')
  let pathname = substitute(pathname, '\([/\\]\)\%(\.[/\\]\)\+', '\1', 'g')
  if make_relative_to_pwd
    let pwd = getcwd().'/'
    let pathname = substitute(pathname, '^'.lh#path#to_regex(pwd), '', 'g')
  endif
  return pathname
endfunction
function! lh#path#Simplify(pathname)
  return lh#path#simplify(a:pathname)
endfunction

" Function: lh#path#split(pathname) {{{3
" Split pathname parts: "/home/me/foo/bar" -> [ "home", "me", "foo", "bar" ]
function! lh#path#split(pathname)
  let parts = split(a:pathname, '[/\\]')
  return parts
endfunction

" Function: lh#path#join(pathparts, {path_separator}) {{{3
function! lh#path#join(pathparts, ...)
  let sep
        \ = (a:0) == 0                       ? '/'
        \ : type(a:1)==type(0) && (a:1) == 0 ? '/'
        \ : (a:1) == 1                       ? '\'
        \ : (a:1) =~ 'shellslash\|ssl'       ? (&ssl ? '\' : '/')
        \ :                                    (a:1)
  return join(a:pathparts, sep)
endfunction

" Function: lh#path#common({pathnames}) {{{3
" Find the common leading path between all pathnames
function! lh#path#common(pathnames)
  " assert(len(pathnames)) > 1
  let common = a:pathnames[0]
  let lCommon = lh#path#split(common)
  let i = 1
  while i < len(a:pathnames)
    let fcrt = a:pathnames[i]
    " Can't make it work => split paths, and test each subdir manually...
    " let common = matchstr(common.'@@'.fcrt, '^\zs\(.*[/\\]\)\ze.\{-}@@\1.*$')
    " let common = matchstr(common.'@@'.fcrt, '^\zs\(.*\>\)\ze.\{-}@@\1\>.*$')
    let lFcrt = lh#path#split(fcrt)
    let Mcrt = len(lFcrt)
    let Mcom = len(lCommon)
    let p = 0
    while 1
      if p == Mcom
        break
      elseif p==Mcrt || lCommon[p] != lFcrt[p]
        call remove(lCommon, p, -1)
        break
      endif
      let p += 1
    endwhile
    if len(lCommon) == 0 " No need to further checks
      break
    endif
    let i += 1
  endwhile
  return join(lCommon, '/')
endfunction

" Function: lh#path#strip_common({pathnames}) {{{3
" Find the common leading path between all pathnames, and strip it
function! lh#path#strip_common(pathnames)
  " assert(len(pathnames)) > 1
  let common = lh#path#common(a:pathnames)
  let common = lh#path#to_dirname(common)
  let l = strlen(common)
  if l == 0
    return a:pathnames
  else
    let pathnames = a:pathnames
    call map(pathnames, 'strpart(v:val, '.l.')' )
    call map(pathnames, 'substitute(v:val, "^/", "", "")' )
    return pathnames
  endif
endfunction
function! lh#path#StripCommon(pathnames)
  return lh#path#strip_common(a:pathnames)
endfunction

" Function: lh#path#is_absolute_path({path}) {{{3
function! lh#path#is_absolute_path(path)
  return a:path =~ '^/'
        \ . '\|^[a-zA-Z]:[/\\]'
        \ . '\|^[/\\]\{2}'
  "    Unix absolute path
  " or Windows absolute path
  " or UNC path
endfunction
function! lh#path#IsAbsolutePath(path)
  return lh#path#is_absolute_path(a:path)
endfunction

" Function: lh#path#is_url({path}) {{{3
function! lh#path#is_url(path)
  " todo: support UNC paths and other urls
  return a:path =~ '^\%(https\=\|s\=ftp\|dav\|fetch\|file\|rcp\|rsynch\|scp\)://'
endfunction
function! lh#path#IsURL(path)
  return lh#path#is_url(a:path)
endfunction

" Function: lh#path#select_one({pathnames},{prompt}) {{{3
function! lh#path#select_one(pathnames, prompt)
  if len(a:pathnames) > 1
    let simpl_pathnames = deepcopy(a:pathnames)
    let simpl_pathnames = lh#path#strip_common(simpl_pathnames)
    let simpl_pathnames = [ '&Cancel' ] + simpl_pathnames
    " Consider guioptions+=c is case of difficulties with the gui
    try
      let guioptions_save = &guioptions
      set guioptions+=v
      let selection = confirm(a:prompt, join(simpl_pathnames,"\n"), 1, 'Question')
    finally
      let &guioptions = guioptions_save
    endtry
    let file = (selection == 1) ? '' : a:pathnames[selection-2]
    return file
  elseif len(a:pathnames) == 0
    return ''
  else
    return a:pathnames[0]
  endif
endfunction
function! lh#path#SelectOne(pathnames, prompt)
  return lh#path#select_one(a:pathnames, a:prompt)
endfunction

" Function: lh#path#to_relative({pathname}) {{{3
" Notes:
" - ":p:." turns getcwd().'/../bar' into an absolute path
" - ":~:." turns getcwd().'/../bar' into "../bar"
" - ":p:." turns getcwd().'/./foo' into "foo"
" - ":~:." turns getcwd().'/./foo' into "./foo"
" Hence lh#path#simplify() executed at the end.
function! lh#path#to_relative(pathname)
  " let newpath = fnamemodify(a:pathname, ':p:.')
  let newpath = fnamemodify(a:pathname, ':~:.')
  let newpath = lh#path#simplify(newpath)
  return newpath
endfunction
function! lh#path#ToRelative(pathname)
  return lh#path#to_relative(a:pathname)
endfunction

" Function: lh#path#to_dirname({dirname}) {{{3
function! lh#path#to_dirname(dirname)
  let dirname = a:dirname . (empty(a:dirname) || a:dirname[-1:] =~ '[/\\]'
        \ ? '' : lh#path#shellslash())
  return dirname
endfunction

" Function: lh#path#depth({dirname}) {{{3
" todo: make a choice about "negative" paths like "../../foo"
function! lh#path#depth(dirname)
  if empty(a:dirname) | return 0 | endif
  let dirname = lh#path#to_dirname(a:dirname)
  let dirname = lh#path#simplify(dirname)
  if lh#path#is_absolute_path(dirname)
    let dirname = matchstr(dirname, '.\{-}[/\\]\zs.*')
  endif
  let parts = split(dirname, '[/\\]')
  let depth = len(parts) - 2 * count(parts, '..')
  return depth
endfunction

" Function: lh#path#relative_to({from}, {to}) {{{3
" @param two directories
" @return a directories delta that ends with a '/' (may depends on
" &shellslash)
function! lh#path#relative_to(from, to)
  " let from = fnamemodify(a:from, ':p')
  " let to   = fnamemodify(a:to  , ':p')
  let from = lh#path#to_dirname(a:from)
  let to   = lh#path#to_dirname(a:to  )
  let [from, to] = lh#path#strip_common([from, to])
  let nb_up =  lh#path#depth(from)
  return repeat('..'.lh#path#shellslash(), nb_up).to

  " cannot rely on :cd (as it alters things, and doesn't work with
  " non-existant paths)
  let pwd = getcwd()
  exe 'cd '.a:to
  let res = lh#path#to_relative(a:from)
  exe 'cd '.pwd
  return res
endfunction

" Function: lh#path#glob_as_list({pathslist}, {expr} [, mustSort=1]) {{{3
function! s:GlobAsList(pathslist, expr,  mustSort)
  let pathslist = type(a:pathslist) == type([]) ? join(a:pathslist, ',') : a:pathslist
  let sResult = globpath(pathslist, a:expr)
  let lResult = split(sResult, '\n')
  " workaround a non feature of wildignore: it does not ignore directories
  for ignored_pattern in split(&wildignore,',')
    if stridx(ignored_pattern,'/') != -1
      call filter(lResult, 'v:val !~ '.string(ignored_pattern))
    endif
  endfor
  return a:mustSort ? lh#list#unique_sort(lResult) : lResult
endfunction

function! lh#path#glob_as_list(pathslist, expr, ...)
  let mustSort = (a:0 > 0) ? (a:1) : 0
  if type(a:expr) == type('string')
    return s:GlobAsList(a:pathslist, a:expr, mustSort)
  elseif type(a:expr) == type([])
    let res = []
    for expr in a:expr
      call extend(res, s:GlobAsList(a:pathslist, expr, mustSort))
    endfor
    return res
  else
    throw "Unexpected type for a:expression"
  endif
endfunction
function! lh#path#GlobAsList(pathslist, expr)
  return lh#path#glob_as_list(a:pathslist, a:expr)
endfunction

" Function: lh#path#strip_start({pathname}, {pathslist}) {{{3
" Strip occurrence of paths from {pathslist} in {pathname}
" @param[in] {pathname} name to simplify
" @param[in] {pathslist} list of pathname (can be a |string| of pathnames
" separated by ",", of a |List|).
function! lh#path#strip_start(pathname, pathslist)
  if type(a:pathslist) == type('string')
    " let strip_re = escape(a:pathslist, '\\.')
    " let strip_re = '^' . substitute(strip_re, ',', '\\|^', 'g')
    let pathslist = split(a:pathslist, ',')
  elseif type(a:pathslist) == type([])
    let pathslist = deepcopy(a:pathslist)
  else
    throw "Unexpected type for a:pathname"
  endif

  " apply a realpath like operation
  let nb_paths = len(pathslist) " set before the loop
  let i = 0
  " while i != nb_paths
    " if pathslist[i] =~ '^\.\%(/\|$\)'
      " let path2 = getcwd().pathslist[i][1:]
      " call add(pathslist, path2)
    " endif
    " let i += 1
  " endwhile
  let pathslist_abs=filter(copy(pathslist), 'v:val =~ "^\\.\\%(/\\|$\\)"')
  let pathslist += pathslist_abs
  " replace path separators by a regex that can match them
  call map(pathslist, 'substitute(v:val, "[\\\\/]", "[\\\\/]", "g")')
  " echomsg string(pathslist)
  " escape . and ~
  call map(pathslist, '"^".escape(v:val, ".~")')
  " handle "**" as anything
  call map(pathslist, 'substitute(v:val, "\\*\\*", "\\\\%([^\\\\/]*[\\\\/]\\\\)*", "g")')
  " reverse the list to use the real best match, which is "after"
  call reverse(pathslist)
  if 0
    " build the strip regex
    let strip_re = join(pathslist, '\|')
    " echomsg strip_re
    let best_match = substitute(a:pathname, '\%('.strip_re.'\)[/\\]\=', '', '')
  else
    if !empty(pathslist)
      let best_match = substitute(a:pathname, '\%('.pathslist[0].'\)[/\\]\=', '', '')
      for path in pathslist[1:]
        let a_match = substitute(a:pathname, '\%('.path.'\)[/\\]\=', '', '')
        if len(a_match) < len(best_match)
          let best_match = a_match
        endif
      endfor
    endif
  endif
  return best_match
endfunction
function! lh#path#StripStart(pathname, pathslist)
  return lh#path#strip_start(a:pathname, a:pathslist)
endfunction

" Function: lh#path#to_regex({pathname}) {{{3
function! lh#path#to_regex(path)
  let regex = substitute(a:path, '[/\\]', '[/\\\\]', 'g')
  return regex
endfunction

" Function: lh#path#find({pathname}, {regex}) {{{3
function! lh#path#find(paths, regex)
  let paths = (type(a:paths) == type([]))
        \ ? (a:paths)
        \ : split(a:paths,',')
  for path in paths
    if match(path ,a:regex) != -1
      return path
    endif
  endfor
  return ''
endfunction

" Function: lh#path#vimfiles() {{{3
function! lh#path#vimfiles()
  let HOME = exists('$LUCHOME') ? $LUCHOME : $HOME
  let expected_win = HOME . '/vimfiles'
  let expected_nix = HOME . '/.vim'
  let what =  lh#path#to_regex(HOME.'/').'\(vimfiles\|.vim\)'
  " Comment what
  let z = lh#path#find(&rtp,what)
  return z
endfunction

" Function: lh#path#is_in(file, path) {{{3
function! lh#path#is_in(file, path)
  if stridx(a:file, a:path) == 0
    return 1
  else
    " try to check with readlink
    return stridx(lh#path#readlink(a:file), lh#path#readlink(a:path)) == 0
  endif
endfunction

" Function: lh#path#readlink(pathname) {{{3
let s:has_readlink = 0
function! lh#path#readlink(pathname)
  if s:has_readlink || executable('readlink')
    let s:has_readlink = 1
    return lh#os#system('readlink -f '.shellescape(a:pathname))
  else
    return a:pathname
  endif
endfunction

" Function: lh#path#add_path_if_exists(listname, path) {{{3
function! lh#path#add_path_if_exists(listname, path)
  let path = substitute(a:path, '[/\\]\*\*$', '', '')
  if isdirectory(path)
    let {a:listname} += [a:path]
  endif
endfunction

" Function: lh#path#shellslash() {{{3
function! lh#path#shellslash()
  return exists('+shellslash') && !&ssl ? '\' : '/'
endfunction

" Function: lh#path#find_in_parents(paths, kinds, last_valid_path) {{{3
" @param {last_valid_path} will likelly contain a REGEX pattern aimed at
" identifying things like $HOME
function! lh#path#find_in_parents(path, path_patterns, kinds, last_valid_path)
  if a:path =~ '^\(//\|\\\\\)$'
    " The root path (/) is not a place where to store files like _vimrc_local
    call s:Verbose('Stop recursion in UNC invalid root path: '.a:path)
    return []
  elseif a:path =~ '^\v(|\a:[/\\]*|[/\\])$'
    " The root path (/) is not a place where to store files like _vimrc_local
    call s:Verbose('Wont recurse anymore in root path: '.a:path)
    let can_try_to_recurse = 0
  else
    let can_try_to_recurse = 1
  endif

  let res = []

  let path = fnamemodify(a:path, ':p')

  if can_try_to_recurse
    if path[len(path)-1] =~ '[/\\]'
      let path = path[:-2]
    endif
    let up_path = fnamemodify(path,':h')
    if up_path == '.' " Likely a non existent path
      if ! isdirectory(path)
        call lh#common#warning_msg("The current file '".expand('%:p:')."' seems to be in a non-existent directory: '".path."'")
      endif
      let up_path = getcwd()
    endif
    " call confirm('crt='.path."\nup=".up_path."\n$HOME=".s:home, '&Ok', 1)
    " echomsg ('crt='.path."\nup=".up_path."\n$HOME=".s:home)

    " Recursive call:
    " - first check the parent directory
    if path !~ a:last_valid_path && path != up_path
      " Terminal condition
      let res += lh#path#find_in_parents(up_path, a:path_patterns, a:kinds, a:last_valid_path)
    else
      call s:Verbose('Terminal condition reached: path '.path.' matches '.string(a:last_valid_path). ' or parent dir is the same')

    endif
  endif

  " - then check the current path
  "   Unless it's not a directory
  if ! isdirectory(path)
    return res
  endif
  " Restore the trailling '/'
  if empty(path) || path[len(path)-1] !~ '[/\\]'
    let path .= lh#path#shellslash()
  endif
  let path_patterns = type(a:path_patterns) == type([]) ? a:path_patterns : [a:path_patterns]
  for pattern in path_patterns
    let tested_path = path.pattern
    let smthg_found = 0
    if a:kinds =~ '.*dir.*' && isdirectory(tested_path)
      let res += [tested_path]
      let smthg_found = 1
      call s:Verbose('Check '.path.' ... '.pattern.' directory found!')
    elseif a:kinds =~ '.*file.*' && filereadable(tested_path)
      let res += [tested_path]
      let smthg_found = 1
      call s:Verbose('Check '.path.' ... '.pattern.' file found!')
    endif
  endfor
  if smthg_found == 0
    call s:Verbose('Check '.path.' for '.string(path_patterns).' ... none found!')
  endif

  return res
endfunction

" Function: lh#path#munge(pathlist, path) {{{3
function! lh#path#munge(pathlist, path)
  if type(a:pathlist) == type('str')
    let pathlist = split(a:pathlist, ',')
    return join(lh#path#munge(pathlist, a:path), ',')
  else
    " if filereadable(a:path) || isdirectory(a:path)
    if ! empty(glob(a:path))
      call lh#list#push_if_new(a:pathlist, a:path)
    endif
    return a:pathlist
  endif
endfunction
" }}}1
"=============================================================================
let &cpo=s:cpo_save
"=============================================================================
" vim600: set fdm=marker:
