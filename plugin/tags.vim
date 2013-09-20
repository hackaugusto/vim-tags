" vim-tags - The Ctags generator for Vim
" Maintainer:   Szymon Wrozynski
" Version:      0.0.9
"
" Installation:
" Place in ~/.vim/plugin/tags.vim or in case of Pathogen:
"
"     cd ~/.vim/bundle
"     git clone https://github.com/szw/vim-tags.git
"
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

" Auto generate ctags
if !exists('g:tags_auto_generate')
    let g:tags_auto_generate = 1
endif

if !exists('g:tags_debug')
    let g:tags_debug = 0
endif

" Main tags
if !exists('g:tags_ctags_exe')
    let g:tags_ctags_exe = "ctags -R {OPTIONS} {DIRECTORY} 2>/dev/null"
endif

if !executable(g:tags_ctags_exe[:stridx(g:tags_ctags_exe, ' ')-1])
    echohl WarningMsg
    echomsg "vim-tags: Missing the executable: " . g:tags_ctags_exe[:stridx(g:tags_ctags_exe, ' ')-1]
    echohl None
endif

if !exists('g:tags_cscope_exe')
    let g:tags_cscope_exe = "cscope -Rb {OPTIONS} {DIRECTORY} 2>/dev/null"
endif

" Gemfile tags
if !exists('g:tags_gems_tags_command')
    let g:tags_gems_tags_command = "ctags -R {OPTIONS} `bundle show --paths` 2>/dev/null"
endif

" Ignored files and directories list
if !exists('g:tags_ignore_files')
    let g:tags_ignore_files = ['.gitignore', '.svnignore', '.cvsignore']
endif

" The pattern used for comments in ignore file
if !exists('g:tags_ignore_file_comment_pattern')
    let g:tags_ignore_file_comment_pattern = '^[#"]'
endif

" A list of directories used as a place for tags.
if !exists('g:tags_directories')
    let g:tags_directories = ['.git', '.svn', 'CVS']
endif

" The main tags file name
if !exists('g:tags_main_file')
    let g:tags_main_file = 'tags'
endif

" The extension used for additional tags files
if !exists('g:tags_extension')
    let g:tags_extension = '.tags'
endif

" Should be the Vim-Dispatch plugin used for asynchronous tags generating if present?
if !exists('g:tags_use_vim_dispatch')
    let g:tags_use_vim_dispatch = 1
endif

" External libraries and big projects
if !exists('g:tags_global_tags')
    let g:tags_global_tags = {}
endif

" Should the --field+=l option be used
if !exists('g:tags_use_language_field')
    let g:tags_use_language_field = 1
endif

" Add the support for completion plugins (like YouCompleteMe or WiseComplete) (add --fields=+l)
if g:tags_use_language_field
  let g:tags_ctags_exe = substitute(g:tags_ctags_exe, "{OPTIONS}", '--fields=+l {OPTIONS}', "")
  let g:tags_gems_tags_command = substitute(g:tags_gems_tags_command, "{OPTIONS}", '--fields=+l {OPTIONS}', "")
endif

command! -bang -nargs=0 TagsGenerate :call s:generate_tags(<bang>0, 1)

" Generate options and custom dirs list
" `--tag-relative` produced wrong paths for one python project, now just
" change the directory to the one where the tag file will be saved
" let options = ['--tag-relative']  
let options = []
let s:files_to_include = []

" Exclude ignored files and directories (also handle negated patterns (!))
for ignore_file in g:tags_ignore_files
    if filereadable(ignore_file)
        for line in readfile(ignore_file)
            if match(line, '^!') != -1
                call add(s:files_to_include, substitute(line, '^!\|^/', '', ''))
            elseif strlen(line) > 1 && match(line, g:tags_ignore_file_comment_pattern) == -1
                call add(options, '--exclude=' . shellescape(substitute(line, '^/', '', '')))
            endif
        endfor
    endif
endfor

" Search upwards for s:tags_directory
for tags_dir in g:tags_directories
    let s:tags_directory = finddir(tags_dir, ';') 
    if !empty(s:tags_directory)
        let s:project_directory = simplify(s:tags_directory . '/..') . '/'
        break
    endif
endfor

if !exists('s:tags_directory')
    let s:tags_directory = '.'
endif
if !exists('s:project_directory')
    let s:project_directory = '.'
endif

if !exists('g:tags_global_directory')
    let g:tags_global_directory = s:tags_directory
endif


" Add main tags file to tags option
if s:tags_directory[0] == '/'
    let tagentry = s:tags_directory . '/' . g:tags_main_file
else
    let tagentry = substitute(s:tags_directory . '/' . g:tags_main_file . ';', '^\./', '', '')
endif
silent! exe 'set tags+=' . tagentry

" ignore directories 
for f in values(g:tags_global_tags)
    if f[:strlen(s:project_directory)-1] == s:project_directory
        call add(options, '--exclude=' . shellescape(f))
    endif

    silent! exe 'set tags+=' . substitute(s:tags_directory . '/' . g:tags_main_file, '^\./', '', '')
endfor

for f in split(globpath(s:tags_directory, '*' . g:tags_extension, 1), '\n')
    let dir_name = f[strlen(s:tags_directory) + 1:-strlen(g:tags_extension)]

    if isdirectory(dir_name)
        call add(options, '--exclude=' . shellescape(dir_name))
        call add(s:custom_dirs, dir_name)
    endif
endfor

let s:ctags_options = join(options, ' ')

" Add global tags
fun! s:add_global_tags()
    for t in keys(g:tags_global_tags)
        silent! exe 'set tags+=' . s:global_tag_name(t)
    endfor
endfun
autocmd FileType * call s:add_global_tags()

fun! s:global_tag_name(tag_name)
    let l:directory = substitute(g:tags_global_directory, '^\~', $HOME, '')
    return simplify(l:directory . '/' . a:tag_name . g:tags_extension)
endfun

fun! s:execute_async_command(command)
    if g:tags_use_vim_dispatch && exists('g:loaded_dispatch')
        silent! exe 'Start!' a:command
    else
        silent! exe '!' . a:command '&'
    endif
endfun

fun! s:generate_tags(bang, redraw)
    "Remove existing tags
    if a:bang
        let l:files = split(globpath(s:tags_directory, '*' . g:tags_extension, 1), '\n')
                \ + [s:tags_directory . '/' . g:tags_main_file]
                \ + split(globpath(s:tags_global_directory, '*' . g:tags_extension), '\n')

        for f in l:files
            call writefile([], f, 'b')
        endfor
    endif

    "Global tags
    for [tag_name, tagdir_name] in items(g:tags_global_tags)
        let file_name = s:global_tag_name(tag_name)

        " create directory if needed
        let curdir = strpart(file_name, 0, strridx(file_name, '/'))
        if !isdirectory(curdir)
          call mkdir(curdir, 'p')
        endif

        if (getftime(file_name) < getftime(tagdir_name)) || (getfsize(file_name) == 0)
            let custom_tags_command = substitute(g:tags_ctags_exe, '{DIRECTORY}', shellescape(tagdir_name), '')
            let custom_tags_command = substitute(custom_tags_command, '{OPTIONS}', '-f ' . shellescape(file_name), '')
            call s:execute_async_command(custom_tags_command)
        endif
    endfor

    " --tag-relative generated the wrong path on a python project (Django website app/managers.py was app/mangers.py.py)
    " changing directory and fixing path instead
    let project_tags_command = 'cd ' . s:tags_directory . '; ' . g:tags_ctags_exe
    let directory = simplify(substitute(s:tags_directory, '[^/]\+\(/\|$\)', '../', 'g') . s:project_directory)
    let options = s:ctags_options . ' -f ' . g:tags_main_file

    let project_tags_command = substitute(project_tags_command, '{OPTIONS}', options, '')
    let project_tags_command = substitute(project_tags_command, '{DIRECTORY}', directory, '')
    
    "Project tags file
    call s:execute_async_command(project_tags_command)

    if g:tags_debug
        echomsg "Tags: ctags comand: " . project_tags_command
    endif

    " Append files from negated patterns
    if !empty(s:files_to_include)
        let append_command_template = substitute(g:tags_ctags_exe, '{OPTIONS}', '-a -f ' . s:tags_directory . '/' . g:tags_main_file, '')
        for file_to_include in s:files_to_include
            call s:execute_async_command(substitute(append_command_template, '{DIRECTORY}', file_to_include, ''))
        endfor
    endif

    "Gemfile.lock
    let gemfile_time = getftime('Gemfile.lock')
    if gemfile_time > -1
        let gems_path = s:tags_directory . '/Gemfile.lock' . g:tags_extension
        let gems_command = substitute(g:tags_gems_tags_command, '{OPTIONS}', '-f ' . gems_path, '')
        let gems_time = getftime(gems_path)
        if gems_time > -1
            if (gems_time < gemfile_time) || (getfsize(gems_path) == 0)
                call s:execute_async_command(gems_command)
            endif
        else
            call s:execute_async_command(gems_command)
            silent! exe 'set tags+=' . substitute(gems_path, '^\./', '', '')
        endif
    endif

    if a:redraw
        redraw!
    endif
endfun

if filereadable(s:tags_directory . '/' . g:tags_main_file) && g:tags_auto_generate
    autocmd BufWritePost * call s:generate_tags(0, 0)
endif
