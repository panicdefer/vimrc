" Vim script file
" Language:	XML
" Maintainer:	Devin Weaver <ktohg@tritarget.com>
" Last Change:  Dec 07, 2000
" Version:      $Revision$
" Location:	ftp://tritarget.com/pub/vim/scripts/xmledit.vim
" Contributors: Brad Phelan <bphelan@mathworks.co.uk>

" This script provides some convenience when editing XML (and some SGML)
" formated documents. <M-5> will jump to the beginning or end of the tag block
" your cursor is in. % will jump between '<' and '>' within the tag your
" cursor is in. when in insert mode and you finish a tag (pressing '>') the
" tag will be completed. If you press '>' twice it will complete the tag and
" break it across a blank. If you want to enter a literal '>' without
" parsing use <M-.>

" Kudos to Brad Phelan for completing tag matching and visual tag completion.

" Options:
" xml_use_autocmds - turn on a few XML autocommands that turn on and off the
"     XML mappings depending on the current buffer. Enter the following in your
"     vimrc before source this file to turn this option on:
"     let xml_use_autocmds = 1
" xml_use_html - Allows HTML tag parsing. It functions the same but won't
"     complete typical short tags like <hr> and <br>. Enter the following in your
"     vimrc before source this file to turn this option on:
"     let xml_use_html = 1
" xml_use_xhtml - Allows HTML tag parsing. This functions the same as if you
"     had xml_use_html except it wil auto close the short tags to make valid XML
"     like <hr /> and <br />. This option overrides xml_use_html. Enter the
"     following in your vimrc before source this file to turn this option on:
"     let xml_use_xhtml = 1
" xml_no_sgml - prevents tag completion and block jumping in sgml documents. By
"     default SGML is parsed but in some cases auto completion can hinder some
"     SGML simplification rules. This will disable SGML parsing. Enter the
"     following in your vimrc before source this file to turn this option on:
"     let xml_no_sqml = 1
" xml_file_types - A colon seperated list string for adding custom filetypes that
"     you which to have XML tags parsed when you have xml_use_autocmds on. Ex.
"     let xml_file_types = "perl:php3:java"

" Maps: The following maps have ben created to help you in your XML editing.
"  Map  | Mode   | Description
" ------+--------+-------------
" ,x    | Visual | Place a custom XML tag to suround the selected text.
" <M-.> | Insert | Place a literal '>' without parsing tag.
" <M-5> | Normal | Jump to the begining or end tag.

" Known Bugs:
" - < & > marks inside of a CDATA section are interpreted as actual XML tags
"   even if unmatched.
" - Although the script can handle leading spaces such as < tag></ tag> it is
"   illegal XML syntax and considered very bad form.
" - The matching algorithm can handle illegal tag characters where as the tag
"   completion algorithm can not.

" For those who wish you may uncomment the following to enable a few convinent
" mappings which jump you to the begining or end of a tag (<, >):
"imap ,>> <Esc>/>/e<Cr>a
"imap ,<< <C-o>?<?s<Cr>
"nmap ,>> />/e<Cr>
"nmap ,<< ?<?s<Cr>


if !exists ("did_xmledit_init")
let did_xmledit_init = 1
let is_in_xml_buffer = 0

" Brad Phelan: Wrap the argument in an XML tag                                                
function WrapTag(text)                                                       
    let wraptag = input('tag : ')                                             
    let atts = input('attributes : ')                                         
    if strlen(atts)==0                                                        
	let text = '<'.wraptag.'>'.a:text.'</'.wraptag.'>'                     
    else                                                                      
	let text = '<'.wraptag.' '.atts.'>'.a:text.'</'.wraptag.'>'            
    endif                                                                     
    return text                                                               
endfunction                

function NewFileXML( )
    if &filetype == 'xml' || (!exists ("g:did_xhtmlcf_inits") && exists ("g:xml_use_xhtml") && &filetype == 'html')
	if append (0, '<?xml version="1.0"?>')
	    normal! G
	endif
    endif
endfunction


function AutoOnXML( )
    if exists ("g:xml_use_autocmds")
	if exists ("g:xml_file_types") && &filetype =~? substitute (g:xml_file_types, ':', '\\\|', 'g')
	    call TurnOnXML()
	    return ""
	endif

	if &filetype !~ 'xml\|xsl\|html\|sgml\|docbk'
	    return ""
	elseif &filetype != 'xml'
	    if &filetype == 'html' && ! exists ("g:xml_use_html") && ! exists ("g:xml_use_xhtml")
		return ""
	    elseif &filetype == 'sgml' && exists ("g:xml_no_sgml")
		return ""
	    endif
	endif
    endif

    call TurnOnXML()
endfunction


function TurnOnXML( )
    if ! g:is_in_xml_buffer

	let g:is_in_xml_buffer = 1

	if has ("gui_running")
	    " Have this as an escape incase you want a literal '>' not to run the
	    " ParseTag function.
	    inoremap <M-.> >

	    " Jump between the beggining and end tags.
	    nnoremap <M-5> :call TagMatch1()<Cr>
	else
	    inoremap <Esc>. >
	    nnoremap <Esc>5 :call TagMatch1()<Cr>
	endif

	" Wrap selection in XML tag
	vnoremap ,x "xx"=WrapTag(@x)<Cr>P

	" Parse the tag after pressing the close '>'.
	inoremap > ><Esc>:call ParseTag()<Cr>

	"echo "XML Mappings turned on"
    endif
endfunction


function TurnOffXML( )
    if g:is_in_xml_buffer
	let g:is_in_xml_buffer = 0
	if has ("gui_running")
	    iunmap <M-.>
	    nunmap <M-5>
	else
	    iunmap <Esc>.
	    nunmap <Esc>5
	endif
	iunmap >
	vunmap ,x
	"echo "XML Mappings turned off"
    endif
endfunction

function IsParsableTag( tag )
    " The "Should I parse?" flag.
    let parse = 1

    " make sure a:tag has a proper tag in it and is not a instruction or end tag.
    if a:tag !~ '^<[[:alnum:]_:\-].*>$'
	let parse = 0
    endif

    " make sure this tag isn't already closed.
    if strpart (a:tag, strlen (a:tag) - 2, 1) == '/'
	let parse = 0
    endif
    
    return parse
endfunction


function ParseTag( )
    if strpart (getline ("."), col (".") - 2, 2) == '>>'
	let multi_line = 1
	execute "normal! X"
    else
	let multi_line = 0
    endif

    let @" = ""
    execute "normal! y%%"
    let ltag = @"
    if &filetype != 'xml' && (exists ("g:xml_use_html") || exists ("g:xml_use_xhtml"))
	let html_mode = 1
	let ltag = substitute (ltag, '[^[:graph:]]\+', ' ', 'g')
	let ltag = substitute (ltag, '<\s*\([^[:alnum:]_:\-[:blank:]]\=\)\s*\([[:alnum:]_:\-]\+\)\>', '<\1\2', '')
    else
	let html_mode = 0
    endif

    if IsParsableTag (ltag)
	" find the break between tag name and atributes (or closing of tag)
	" Too bad I can't just grab the position index of a pattern in a string.
	let index = 1
	while index < strlen (ltag) && strpart (ltag, index, 1) =~ '[[:alnum:]_:\-]'
	    let index = index + 1
	endwhile

	let tag_name = strpart (ltag, 1, index - 1)

	" That (index - 1) + 2    2 for the '</' and 1 for the extra character the
	" while includes (the '>' is ignored because <Esc> puts the curser on top
	" of the '>'
	let index = index + 2

	" print out the end tag and place the cursor back were it left off
	if html_mode && tag_name =~? '^\(img\|input\|param\|frame\|br\|hr\|meta\|link\|base\|area\)$'
	    if exists ("g:xml_use_xhtml")
		execute "normal! i /\<Esc>l"
	    endif
	else
	    if multi_line
		" Can't use \<Tab> because that indents 'tabstop' not 'shiftwidth'
		" Also >> doesn't shift on an empty line hence the temporary char 'x'
		let com_save = &comments
		set comments-=n:>
		execute "normal! a\<Cr>\<Cr>\<Esc>kAx\<Esc>>>$x"
		execute "set comments=" . com_save
		startinsert!
		return ""
	    else
		execute "normal! a</" . tag_name . ">\<Esc>" . index . "h"
	    endif
	endif
    endif

    if col (".") < strlen (getline ("."))
	execute "normal! l"
	startinsert
    else
	startinsert!
    endif
endfunction


function BuildTagName( )
  "First check to see if we
  "Are allready on the end
  "of the tag. The / search
  "forwards command will jump
  "to the next tag otherwise
  exec "normal! v\"xy"
  if @x=='>'
     " Don't do anything
  else
     exec "normal! />/\<Cr>"
  endif

  " Now we head back to the < to reach the beginning.
  exec "normal! ?<?\<Cr>"

  " Capture the tag (a > will be catured by the /$/ match)
  exec "normal! v/\\s\\|$/\<Cr>\"xy"

  " We need to strip off any junk at the end.
  let @x=strpart(@x, 0, match(@x, "[[:blank:]>\<C-J>]"))

  "remove <, >
  let @x=substitute(@x,'^<\|>$','','')

  " remove spaces.
  let @x=substitute(@x,'/\s*','/', '')
  let @x=substitute(@x,'^\s*','', '')
endfunction

" Brad Phelan: First step in tag matching.
function TagMatch1()
  "Drop a marker here just in case we have a mismatched tag and
  "wish to return (:mark looses column position)
  normal! mz

  call BuildTagName()

  "Check to see if it is an end tag
  "If it is place a 1 in the register y
  if match(@x, '^/')==-1
    let endtag = 0
  else
    let endtag = 1  
  endif

 " Extract the tag from the whole tag block
 " eg if the block =
 "   tag attrib1=blah attrib2=blah
 " we will end up with 
 "   tag
 " with no trailing or leading spaces
 let @x=substitute(@x,'^/','','g')

 " Make sure the tag is valid.
 " Malformed tags could be <?xml ?>, <![CDATA[]]>, etc.
 if match(@x,'^[[:alnum:]_:\-]') != -1
     " Pass the tag to the matching 
     " routine
     call TagMatch2(@x, endtag)
 endif
endfunction


" Brad Phelan: Second step in tag matching.
function TagMatch2(tag,endtag)
  let match_type=''

  " Build the pattern for searching for XML tags based
  " on the 'tag' type passed into the function.
  " Note we search forwards for end tags and
  " backwards for start tags
  if a:endtag==0
     "let nextMatch='normal /\(<\s*' . a:tag . '\(\s\+.\{-}\)*>\)\|\(<\/' . a:tag . '\s*>\)'
     let match_type = '/'
  else
     "let nextMatch='normal ?\(<\s*' . a:tag . '\(\s\+.\{-}\)*>\)\|\(<\/' . a:tag . '\s*>\)'
     let match_type = '?'
  endif

  if a:endtag==0
     let stk = 1 
  else
     let stk = 1
  end

 " wrapscan must be turned on. We'll recored the value and reset it afterward.
 " We have it on because if we don't we'll get a nasty error if the search hits
 " BOF or EOF.
 let wrapval = &wrapscan
 let &wrapscan = 1

  "Get the current location of the cursor so we can 
  "detect if we wrap on ourselves
  let lpos = line(".")
  let cpos = col(".")

  if a:endtag==0
      " If we are trying to find a start tag
      " then decrement when we find a start tag
      let iter = 1
  else
      " If we are trying to find an end tag
      " then increment when we find a start tag
      let iter = -1
  endif

  "Loop until stk == 0. 
  while 1 
     " exec search.
     " Make sure to avoid />$/ as well as /\s$/ and /$/.
     exec "normal! " . match_type . '<\s*\/*\s*' . a:tag . '\([[:blank:]>]\|$\)' . "\<Cr>"

     " Check to see if our match makes sence.
     if a:endtag == 0
	 if line(".") < lpos
	     call MisMatchedTag (0, a:tag)
	     break
	 elseif line(".") == lpos && col(".") <= cpos
	     call MisMatchedTag (1, a:tag)
	     break
	 endif
     else
	 if line(".") > lpos
	     call MisMatchedTag (2, '/'.a:tag)
	     break
	 elseif line(".") == lpos && col(".") >= cpos
	     call MisMatchedTag (3, '/'.a:tag)
	     break
	 endif
     endif

     call BuildTagName()

     if match(@x,'^/')==-1
	" Found start tag
	let stk = stk + iter 
     else
	" Found end tag
	let stk = stk - iter
     endif

     if stk == 0
	break
     endif    
  endwhile

  let &wrapscan = wrapval
endfunction

function MisMatchedTag( id, tag )
    "Jump back to our formor spot
    normal! `z
    normal zz
    echohl WarningMsg
    " For debugging
    "echo "Mismatched tag " . a:id . ": <" . a:tag . ">"
    " For release
    echo "Mismatched tag <" . a:tag . ">"
    echohl None
endfunction

" This makes the '%' jump between the start and end of a single tag.
set matchpairs+=<:>

if exists ("xml_use_autocmds")
    " Auto Commands
    augroup xml
	au!
	au BufNewFile * call NewFileXML()
	au BufEnter * call AutoOnXML()
	au BufLeave * call TurnOffXML()
    augroup END
else
    call TurnOnXML()
endif


endif
