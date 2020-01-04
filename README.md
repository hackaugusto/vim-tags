Notes
-----

Creates a '.tags' in the .git folder
Allows for source directories, e.g. '.' and '/usr/include'.

Usage
-----

Install using a plugin manager, the tags are automatically generated when a
filer under source control is open.

Configuration
-------------

* `vim_tags_auto_generate`

    * Default: `1`

    If enabled, Vim-Tags will generate tags on file saving

        let g:vim_tags_auto_generate = 1

* `vim_tags_project_tags_command`

    * Default: `"ctags -R --fields=+l {OPTIONS} {DIRECTORY} 2>/dev/null"`

    This command is used for main Ctags generation.

    let g:vim_tags_project_tags_command = "ctags -R {OPTIONS} {DIRECTORY} 2>/dev/null"

* `vim_tags_ignore_files`

    * Default: `['.gitignore', '.svnignore', '.cvsignore']`

    Files containing directories and files excluded from Ctags generation.

        let g:vim_tags_ignore_files = ['.gitignore', '.svnignore', '.cvsignore']

* `vim_tags_ignore_file_comment_pattern`

    * Default: `'^[#"]'`

    The pattern used to recognize comments in the ignore file.

        let g:vim_tags_ignore_file_comment_pattern = '^[#"]'

* `vim_tags_directories`

    * Default: `['.git', '.svn', 'CVS']`

    The default directories list where the tags files will be created. The first one found will be
    used. If none exists the current directory (`'.'`) will be taken.

        let g:vim_tags_directories = ['.git', '.svn', 'CVS']

* `vim_tags_main_file`

    * Default: `'tags'`

    The main tags file name.

        let g:vim_tags_main_file = 'tags'

* `tags_global_tags`

    * Default: `{}`

    A mapping from project name to source directory, tags will be generated for
    these extra directories and automatically included, this enables
    out-of-tree dependencies to be included in your tags database.

        let g:tags_global_tags = {
          \ 'system': '/usr/include'
          \ }

* `tags_global_directory`

    * Default: `''`

    If set, all the tag files from `tags_global_tags` are cached here. Useful
    if you have `g:tags_global_tags` set in the init.vim and the projects are
    of considerable size (because the configuration is globally set these tags
    will be generated on every version control opened locally, which is far
    from ideal, consider using something like local_vimrc instead).

        let g:tags_global_tags = {
          \ 'system': '/usr/include'
          \ }

* `vim_tags_extension`

    * Default: `'.tags'`

    The extension used for additional tags files.

        let g:vim_tags_extension = '.tags'

* `tags_debug`

    * Default: `0`

    Enable debugging, every call to the tags command will be printed out.

        let g:tags_debug = 1

Author and License
------------------

Vim-Tags plugin was written by Augusto Hack, based on the vim-tags from Szymon
Wrozynski and Contributors. It is licensed under the same terms as Vim itself.
For more info see `:help license`.
