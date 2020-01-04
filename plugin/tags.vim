" License:
" Copyright (c) 2012-2013 Szymon Wrozynski and Contributors.
" Distributed under the same terms as Vim itself.
" See :help license
"
" Usage:
" :help vim-tags

if exists('g:loaded_tags') || &cp || v:version < 700
    finish
endif

let g:loaded_tags = 1

if !exists('g:tags_auto_generate')
    let g:tags_auto_generate = 1
endif

if !exists('g:tags_debug')
    let g:tags_debug = 0
endif

" Cache of tags for large code bases, useful when tags are set globally set,
" e.g. when the linux kernel is added to tags_global_tags in the init.vim.
if !exists('g:tags_global_directory')
    let g:tags_global_directory = ''
endif

if !exists('g:tags_ctags_exe')
    let g:tags_ctags_exe = "ctags -R --fields=+l {OPTIONS} {DIRECTORY} 2>/dev/null"
endif

if !executable(g:tags_ctags_exe[:stridx(g:tags_ctags_exe, ' ')-1])
    echohl WarningMsg
    echomsg "vim-tags: Missing the executable: " . g:tags_ctags_exe[:stridx(g:tags_ctags_exe, ' ')-1]
    echohl None
endif

if !exists('g:tags_cscope_exe')
    let g:tags_cscope_exe = "cscope -Rb {OPTIONS} {DIRECTORY} 2>/dev/null"
endif

" Dont create tags for files that are ignored by the version control
if !exists('g:tags_vcs_ignore')
    let g:tags_vcs_ignore = ['.gitignore', '.svnignore', '.cvsignore']
endif

" The pattern used for comments in ignore file
if !exists('g:tags_ignore_file_comment_pattern')
    let g:tags_ignore_file_comment_pattern = '^[#"]'
endif

" A list of directories used to save the tags.
if !exists('g:tags_directories')
    let g:tags_directories = ['.git', '.svn', 'CVS', '.hg']
endif

" The main tags file name
if !exists('g:tags_main_file')
    let g:tags_main_file = 'tags'
endif

" The extension used for additional tags files
if !exists('g:tags_extension')
    let g:tags_extension = '.tags'
endif

" External libraries and big projects
if !exists('g:tags_global_tags')
    let g:tags_global_tags = {}
endif

fun! s:is_validate_config()
  " Validation is called after loading because the variables can be lazily
  " set.
  if type(g:tags_global_tags) != v:t_dict
    echohl ErrorMsg
    echomsg "vim-tags: g:tags_global_tags must be a dictonary of the form:"
    echomsg "{'unique_name_of_the_project': 'source_directory'}"
    echohl None
    return 0
  endif

  return 1
endfun

call s:is_validate_config()

" Exclude ignored files and directories (also handle negated patterns (!))
" TODO:
"   this will open only the ignore_file that is on the cwd, we need to
"   lookup to projet_directory and --exclude acordingly
fun! s:tags_ignore_files()
  for ignore in g:tags_vcs_ignore
      if filereadable(ignore)
          for line in readfile(ignore)
              if match(line, '^!') != -1
                  call add(b:files_to_include, substitute(line, '^!\|^/', '', ''))
              elseif strlen(line) > 1 && match(line, g:tags_ignore_file_comment_pattern) == -1
                  call add(b:options, '--exclude=' . shellescape(substitute(line, '^/', '', '')))
              endif
          endfor
      endif
  endfor
endfun

fun! s:tags_ignore_directories()
  for source_directory in values(g:tags_global_tags)
      if source_directory[:strlen(b:project_directory)-1] == b:project_directory
          call add(b:options, '--exclude=' . shellescape(source_directory))
      endif
  endfor
endfun

fun! s:tags_directory()
  for directory in g:tags_directories
    let b:tags_directory = simplify(finddir(directory, ';'))  " Search upwards

    if !empty(b:tags_directory)
      " --tag-relative generated the wrong path on a Django project so we are
      "  using absolute path
      let b:tags_directory = fnamemodify(simplify(b:tags_directory), ":p:h")
      let b:project_directory = simplify(b:tags_directory . '/..') . '/'
      break
    endif
  endfor

  if !exists('b:tags_directory')
    let b:tags_directory = '.'
  endif

  if !exists('b:project_directory')
    let b:project_directory = '.'
  endif

  " Use the cache if enabled
  if len(g:tags_global_directory)
    let b:tags_global_directory = g:tags_global_directory
  else
    let b:tags_global_directory = b:tags_directory
  endif

  for file in split(globpath(b:tags_directory, '*' . g:tags_extension, 1), '\n')
      let dir_name = file[strlen(b:tags_directory) + 1:-strlen(g:tags_extension)]

      if isdirectory(dir_name)
          call add(b:options, '--exclude=' . shellescape(dir_name))
      endif
  endfor

  if b:tags_directory[0] == '/'
      let tagentry = b:tags_directory . '/' . g:tags_main_file
  else
      let tagentry = substitute(b:tags_directory . '/' . g:tags_main_file . ';', '^\./', '', '')
  endif

  silent! exe 'setlocal tags+=' . tagentry
endfun

fun! s:tags_global()
  let base_directory = substitute(b:tags_global_directory, '^\~', $HOME, '')

  for tag_name in keys(g:tags_global_tags)
    let tag_path = simplify(base_directory . '/' . tag_name . g:tags_extension)
    silent! exe 'setlocal tags+=' . tag_path
  endfor
endfun

fun! s:global_tag_name(tag_name)
  let l:directory = substitute(b:tags_global_directory, '^\~', $HOME, '')
  return simplify(l:directory . '/' . a:tag_name . g:tags_extension)
endfun

fun! s:tags_init_for_buffer()
  if !s:is_validate_config()
    return
  endif

  let old_cwd = getcwd()

  if g:tags_debug
    echomsg "[Tags] running Init: " . expand("%:p:h")
  endif

  exe ':cd %:p:h'
    let b:options = []
    let b:files_to_include = []

    call s:tags_directory()

    call s:tags_ignore_files()
    call s:tags_ignore_directories()
    call s:tags_global()
  exe ':cd ' . old_cwd
endfun

fun! s:execute_async_command(command)
  if g:tags_debug
    echomsg "[Tags] execute async: " . a:command
  endif

  if !len(a:command)
    return
  endif

  if g:tags_debug
     exe '!' . a:command '&'
  else
    silent! exe '!' . a:command '&'
  endif
endfun

fun! s:tags_generate(bang, redraw)
  if !s:is_validate_config()
    return
  endif

  call s:tags_init_for_buffer()

  " Remove existing tags
  if a:bang
    let l:files = split(globpath(b:tags_directory, '*' . g:tags_extension, 1), '\n')
            \ + [b:tags_directory . '/' . g:tags_main_file]
            \ + split(globpath(b:tags_global_directory, '*' . g:tags_extension), '\n')

    for file in l:files
      call writefile([], file, 'b')
    endfor
  endif

  for [tag_name, source_directory] in items(g:tags_global_tags)
    let file_name = s:global_tag_name(tag_name)

    " create directory if needed
    let curdir = strpart(file_name, 0, strridx(file_name, '/'))
    if !isdirectory(curdir)
      call mkdir(curdir, 'p')
    endif

    if (getftime(file_name) < getftime(source_directory)) || (getfsize(file_name) == 0)
      let custom_tags_command = substitute(g:tags_ctags_exe, '{DIRECTORY}', shellescape(source_directory), '')
      let custom_tags_command = substitute(custom_tags_command, '{OPTIONS}', '-f ' . shellescape(file_name), '')
      call s:execute_async_command(custom_tags_command)
    endif
  endfor

  let project_tags_command = 'cd ' . b:tags_directory . '; ' . g:tags_ctags_exe
  let project_tags_command = substitute(project_tags_command, '{OPTIONS}', join(b:options, ' ') . ' -f ' . g:tags_main_file, '')
  let project_tags_command = substitute(project_tags_command, '{DIRECTORY}', b:project_directory, '')

  if g:tags_debug
    echomsg "Tags: ctags comand: " . project_tags_command
  endif

  call s:execute_async_command(project_tags_command)

  " Append files from negated patterns
  if !empty(b:files_to_include)
    let append_command_template = substitute(g:tags_ctags_exe, '{OPTIONS}', '-a -f ' . b:tags_directory . '/' . g:tags_main_file, '')
    for file_to_include in b:files_to_include
      call s:execute_async_command(substitute(append_command_template, '{DIRECTORY}', file_to_include, ''))
    endfor
  endif

  if a:redraw
    redraw!
  endif
endfun

fun! s:auto_generate(bang, redraw)
  " do not generate tags if we are not inside a vcs, because if the user open
  " vim on / we will generate tags for the whole filesystem
  if exists('b:tags_directory') && !empty(b:tags_directory) && b:tags_directory != '.'
    call s:tags_generate(a:bang, a:redraw)
  endif
endfun

if g:tags_auto_generate
  autocmd FileType * :TagsInit
  autocmd FileType * :call s:auto_generate(0, 0)
  autocmd BufWritePost * :call s:auto_generate(0, 0)
endif

command! -bang -nargs=0 TagsInit :call s:tags_init_for_buffer()
command! -bang -nargs=0 TagsGenerate :call s:tags_generate(<bang>0, 1)
