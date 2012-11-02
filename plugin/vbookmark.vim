" Name: Vim bookmark
" Author: Name5566 <name5566@gmail.com>
" Version: 0.2.4

if exists('loaded_vbookmark')
	finish
endif
let loaded_vbookmark = 1

let s:savedCpo = &cpo
set cpo&vim


"""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Sign
"""""""""""""""""""""""""""""""""""""""""""""""""""""""
exec 'sign define vbookmark_sign text=>> texthl=Visual'

function! s:Vbookmark_placeSign(id, file, lineNo)
	exec 'sign place ' . a:id
		\ . ' line=' . a:lineNo
		\ . ' name=vbookmark_sign'
		\ . ' file=' . a:file
endfunction

function! s:Vbookmark_unplaceSign(id, file)
	exec 'sign unplace ' . a:id
		\ . ' file=' . a:file
endfunction

function! s:Vbookmark_jumpSign(id, file)
	exec 'sign jump ' . a:id
		\ . ' file=' . a:file
endfunction

function! s:Vbookmark_isSignIdExist(id)
	for mark in s:vbookmark_bookmarks
		if mark.id == a:id
			return 1
		endif
	endfor
	return 0
endfunction

" TODO: optimizing
function! s:Vbookmark_generateSignId()
	if !exists('s:vbookmark_signSeed')
		let s:vbookmark_signSeed = 201210
	endif
	while s:Vbookmark_isSignIdExist(s:vbookmark_signSeed)
		let s:vbookmark_signSeed += 1
	endwhile
	return s:vbookmark_signSeed
endfunction

function! s:Vbookmark_getSignId(line)
	let savedZ = @z
	redir @z
	silent! exec 'sign place buffer=' . winbufnr(0)
	redir END
	let output = @z
	let @z = savedZ

	let match = matchlist(output, '    \S\+=' . a:line . '  id=\(\d\+\)')
	if empty(match)
		return -1
	else
		return match[1]
	endif
endfun


"""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Bookmark
"""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! s:Vbookmark_initVariables()
	let s:vbookmark_bookmarks = []
	let s:vbookmark_curMarkIndex = -1
endfunction
call s:Vbookmark_initVariables()

function! s:Vbookmark_adjustCurMarkIndex()
	let size = len(s:vbookmark_bookmarks)
	if s:vbookmark_curMarkIndex >= size
		let s:vbookmark_curMarkIndex -= size
	elseif s:vbookmark_curMarkIndex < 0
		let s:vbookmark_curMarkIndex += size
	endif
endfunction

function! s:Vbookmark_setBookmark(line)
	let id = s:Vbookmark_generateSignId()
	let file = expand("%:p")
	if file == ''
		echo "No valid file name."
		return
	endif
	call s:Vbookmark_placeSign(id, file, a:line)
	call add(s:vbookmark_bookmarks, {'id': id, 'file': file, 'line': a:line})
endfunction

function! s:Vbookmark_unsetBookmark(id)
	let i = 0
	let size = len(s:vbookmark_bookmarks)
	while i < size
		let mark = s:vbookmark_bookmarks[i]
		if mark.id == a:id
			call s:Vbookmark_unplaceSign(mark.id, mark.file)
			call remove(s:vbookmark_bookmarks, i)
			call s:Vbookmark_adjustCurMarkIndex()
			break
		endif
		let i += 1
	endwhile
endfunction

function! s:Vbookmark_refreshSign(file)
	for mark in s:vbookmark_bookmarks
		if mark.file == a:file
			call s:Vbookmark_placeSign(mark.id, mark.file, mark.line)
		endif
	endfor
endfunction

function! s:Vbookmark_jumpBookmark(method)
	if empty(s:vbookmark_bookmarks)
        echo "No bookmarks found."
		return
	endif

	if a:method == 'next'
		let s:vbookmark_curMarkIndex += 1
	elseif a:method == 'prev'
		let s:vbookmark_curMarkIndex -= 1
	endif
	call s:Vbookmark_adjustCurMarkIndex()

	let mark = s:vbookmark_bookmarks[s:vbookmark_curMarkIndex]
	try
		call s:Vbookmark_jumpSign(mark.id, mark.file)
	catch
		if !filereadable(mark.file)
			call remove(s:vbookmark_bookmarks, s:vbookmark_curMarkIndex)
			call s:Vbookmark_adjustCurMarkIndex()
			call s:Vbookmark_jumpBookmark(a:method)
			return
		endif
		exec 'e ' . mark.file
		call s:Vbookmark_refreshSign(mark.file)
		call s:Vbookmark_jumpSign(mark.id, mark.file)
	endtry
endfunction

function! s:Vbookmark_nextBookmark()
	call s:Vbookmark_jumpBookmark('next')
endfunction

function! s:Vbookmark_previousBookmark()
	call s:Vbookmark_jumpBookmark('prev')
endfunction

function! s:Vbookmark_clearAllBookmark()
	for mark in s:vbookmark_bookmarks
		call s:Vbookmark_unplaceSign(mark.id, mark.file)
	endfor

	call s:Vbookmark_initVariables()
endfunction

function! s:Vbookmark_saveAllBookmark()
	if !exists('g:vbookmark_bookmarkSaveFile')
		return
	end
	let outputBookmarks = 'let g:__vbookmark_bookmarks__ = ['
	for mark in s:vbookmark_bookmarks
		let outputBookmarks .= '{"id": ' . mark.id . ', "file": "' . escape(mark.file, ' \') . '", "line": ' . mark.line . '},'
	endfor
	let outputBookmarks .= ']'
	let outputCurMarkIndex = "let g:__vbookmark_curMarkIndex__ = " . s:vbookmark_curMarkIndex
	call writefile([outputBookmarks, outputCurMarkIndex], g:vbookmark_bookmarkSaveFile)
endfunction
autocmd VimLeave * call s:Vbookmark_saveAllBookmark()

function! s:Vbookmark_loadAllBookmark()
	if !exists('g:vbookmark_bookmarkSaveFile') || !filereadable(g:vbookmark_bookmarkSaveFile)
		return
	end
	try
		exec 'source ' . g:vbookmark_bookmarkSaveFile
	catch
        echo "Bookmark save file is broken."
		return
	endtry
	if !exists('g:__vbookmark_bookmarks__') || type(g:__vbookmark_bookmarks__) != 3
		\ || !exists('g:__vbookmark_curMarkIndex__') || type(g:__vbookmark_curMarkIndex__) != 0
		echo "Bookmark save file is invalid."
		return
	end

	let s:vbookmark_bookmarks = deepcopy(g:__vbookmark_bookmarks__)
	let s:vbookmark_curMarkIndex = g:__vbookmark_curMarkIndex__
	unlet g:__vbookmark_bookmarks__
	unlet g:__vbookmark_curMarkIndex__
	for mark in s:vbookmark_bookmarks
		try
			call s:Vbookmark_placeSign(mark.id, mark.file, mark.line)
		catch
		endtry
	endfor
endfunction
autocmd VimEnter * call s:Vbookmark_loadAllBookmark()


"""""""""""""""""""""""""""""""""""""""""""""""""""""""
" Interface
"""""""""""""""""""""""""""""""""""""""""""""""""""""""
function! s:VbookmarkToggle()
	let line = line('.')
	let id = s:Vbookmark_getSignId(line)
	if id == -1
		call s:Vbookmark_setBookmark(line)
	else
		call s:Vbookmark_unsetBookmark(id)
	endif
endfunction

function! s:VbookmarkNext()
	call s:Vbookmark_nextBookmark()
endfunction

function! s:VbookmarkPrevious()
	call s:Vbookmark_previousBookmark()
endfunction

function! s:VbookmarkClearAll()
	call s:Vbookmark_clearAllBookmark()
endfunction

if !exists(':VbookmarkToggle')
	command -nargs=0 VbookmarkToggle :call s:VbookmarkToggle()
endif

if !exists(':VbookmarkNext')
	command -nargs=0 VbookmarkNext :call s:VbookmarkNext()
endif

if !exists(':VbookmarkPrevious')
	command -nargs=0 VbookmarkPrevious :call s:VbookmarkPrevious()
endif

if !exists(':VbookmarkClearAll')
	command -nargs=0 VbookmarkClearAll :call s:VbookmarkClearAll()
endif

if !exists('g:vbookmark_disableMapping')
	nnoremap <silent> mm :VbookmarkToggle<CR>
	nnoremap <silent> mn :VbookmarkNext<CR>
	nnoremap <silent> mp :VbookmarkPrevious<CR>
	nnoremap <silent> ma :VbookmarkClearAll<CR>
endif

let &cpo = s:savedCpo
