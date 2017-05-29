format PE console
entry start

include 'win32a.inc'

section '.data' data readable writeable
	fsize	dd ?
	nbyte	dd ?
	;
	hfile	dd ?
	hmap	dd ?
	hout	dd ?
	hin	dd ?
	;
	fmtd	db '%d',13,10,0
	fmts	db '%s',13,10,0
	fmtc	db '%c',13,10,0
	;
	buf	   db MAX_PATH dup 0
	buflen	   = $ - buf
	fbuf	   db MAX_PATH dup 0
	fbuflen    = $ - fbuf
	flgbuf	   db 1024 dup 0
	flgbuflen  = $ - flgbuf
	;
	flg_f	db 'f',0
	flg_l	db 'l',0
	;
	title	db "ERROR",0
	;
	pmem	dd ?
	pmemend dd ?
	;
	promptf 	db 'Enter filename: ',0
	promptf.len	= $ - promptf - 1
	promptflg	db 'Enter read flag[f\l]: ',0
	promptflg.len	= $ - promptflg - 1
	;
	msg_continue	    db 'Press any key...',13,10,0
	msg_continue.len    = $ - msg_continue - 1
	msg_unknown_flg     db 'Unknown read flag',13,10,0
	msg_unknown_flg.len = $ - msg_unknown_flg - 1
	;

section '.code' code readable executable
;
; String functions
;
strlen:
	push	ebp
	mov	ebp, esp
	push	ebx
	; set eax to 0
	xor	eax, eax
	; store first string address to ebx
	mov	ebx, [ebp + 8]
@@:
	cmp	byte [ebx + eax], 0
	je	@f
	; increment eax until 0
	inc	eax
	jmp	@b
@@:
	; restore previous stack pointer
	pop	ebx
	mov	esp, ebp
	pop	ebp
	ret

strcmp:
	push	ebp
	mov	ebp, esp
	; save previous values of registers
	push	esi
	push	edi
	push	ecx
	; return result to eax
	xor	eax, eax
	;
	mov	esi, [ebp + 8]
	mov	edi, [ebp + 12]
	; compute string lengths
	push	esi
	call	strlen
	mov	ecx, eax
	add	esp, 4
	;
	push	edi
	call	strlen
	add	esp, 4
	; compare string lengthg
	cmp	eax, ecx
	jnz	@f
	; set direction flag register (DF) to 0
	cld
	; repe automticaly decrement value in ecx where we stored string length
	repe	cmpsb
@@:
	; set al depending on the ZF flag value
	setnz	al
	; stretch value to 4 bytes
	movsx	eax, al
	pop	ecx
	pop	edi
	pop	esi
	;
	mov	esp, ebp
	pop	ebp
	ret

strstrip:
	push	ebp
	mov	ebp, esp
	push	ecx
	push	edi
	push	esi
	; register for offset
	xor	ecx, ecx
	; get string address
	mov	esi, [ebp + 8]
	;
	; skip spaces at the beginning
	;
.loop1:
	; space
	cmp	byte [esi + ecx], 32
	je	.skip
	; tab
	cmp	byte [esi + ecx], 9
	je	.skip
	; move esi to address of non-space symbol
	add	esi, ecx
	; compute string length
	push	esi
	call	strlen
	add	esp, 4
	; string length
	mov	ecx, eax
	dec	ecx
	;
	; strip trailing space
	;
.loop2:
	; space
	cmp	byte [esi + ecx], 32
	je	.strip
	; tab
	cmp	byte [esi + ecx], 9
	je	.strip
	; cr
	cmp	byte [esi + ecx], 13
	je	.strip
	; lf
	cmp	byte [esi + ecx], 10
	je	.strip
	;
	; RETURN
	;
	cld
	; ecx now contains offset from first non-space symbol to last non-space one
	; increment it to get whole string length with zero byte at the end
	add    ecx, 2
	; save length
	mov    edi, [ebp + 8]
	; previously we stored address of first non-space symbol to esi
	; shift array elements to beginning
	rep    movsb
	mov	eax, edi
	jmp	.ret
.skip:
	inc	ecx
	jmp	.loop1
.strip:
	mov	byte [esi + ecx], 0
	dec	ecx
	jmp	.loop2
.ret:
	pop	esi
	pop	edi
	pop	ecx
	mov	esp, ebp
	pop	ebp
	ret
;
; String macroses
;
macro strlen str
{
	push	str
	call	strlen
	add	esp, 4
}

macro strcmp str1, str2
{
	push	str2
	push	str1
	call	strcmp
	add	esp, 8
}

macro strstrip	str
{
	push	str
	call	strstrip
	add	esp, 4
}
;
; File macroses
;
macro _fopen fname
{
	invoke	CreateFile, fname, GENERIC_READ, \
		FILE_SHARE_READ,\
		NULL, OPEN_EXISTING, \
		FILE_ATTRIBUTE_NORMAL, NULL
}

macro _fclose hfile
{
	invoke	CloseHandle, [hfile]
}
; get map handle
macro _fmaph hfile
{
	invoke	CreateFileMapping, [hfile], NULL, \
		PAGE_READONLY, 0, 0, NULL
}
; get memory address of mapped file
macro _fmapm hmap
{
	invoke	MapViewOfFile, [hmap], \
		FILE_MAP_COPY, 0, 0, 0
}

macro _funmap pmem
{
	invoke	UnmapViewOfFile, pmem
}

macro _fsize hfile
{
	invoke	GetFileSize, [hfile], NULL
}

macro perror
{
	invoke	GetLastError
	mov	edi, eax
	invoke	FormatMessage, FORMAT_MESSAGE_FROM_SYSTEM, \
		NULL, edi, 0, buf, 512, NULL
	invoke	MessageBox, NULL, buf, title, MB_OK
}

macro _get_stdout
{
       invoke GetStdHandle, STD_OUTPUT_HANDLE
}

macro _get_stdin
{
	invoke GetStdHandle, STD_INPUT_HANDLE
}

macro _stdwrite str, size
{
	invoke WriteConsole, [hout], str, size, 0, 0
}

macro _stdread buf, buflen
{
	invoke ReadConsole, [hin], buf, buflen, nbyte, 0
	mov	  edi, buf
	mov	  eax, [nbyte]
	mov	  byte [edi + eax], 0
}
;
; ENTRY POINT
;
start:
	; get console handles
	_get_stdout
	mov	[hout], eax
	_get_stdin
	mov	[hin],	eax
	; ask user a file name
	_stdwrite promptf, promptf.len
	_stdread  fbuf, fbuflen
	strstrip fbuf
	;
	; open file for reading
	;
	_fopen	fbuf
	cmp	eax, INVALID_HANDLE_VALUE
	je	.error
	mov	[hfile], eax
	; get map handle
	_fmaph	hfile
	test	eax, eax
	je	.error
	mov	[hmap], eax
	; get address of first byte of mapped file
	_fmapm	hmap
	test	eax, eax
	je	.error
	mov    [pmem], eax
	; get file size
	_fsize	hfile
	mov	[fsize], eax
	;
	mov	ebx, [pmem]
	add	ebx, [fsize]
	dec	ebx
	; address of last symbol
	mov	[pmemend], ebx
.ask_again:
	; ask user a read flag
	_stdwrite promptflg, promptflg.len
	_stdread  flgbuf, flgbuflen
	strstrip flgbuf
	;
	; check selected flag
	;
	strcmp	flgbuf, flg_f
	cmp	eax, 0
	je	.print_first
	;
	strcmp	flgbuf, flg_l
	cmp	eax, 0
	je	.print_last
	;
	_stdwrite msg_unknown_flg, msg_unknown_flg.len
	_stdwrite msg_continue, msg_continue.len
	;
	jmp	.ask_again
.print_first:
	xor	ebx ,ebx
	xor	edx, edx
	mov	eax, 10 ; LF
	mov	edi, [pmem]
	; move forward
	cld
	; pointer to file beginning
	mov	esi, edi
	; file size
	mov	ecx, [fsize]
@@:	; walk through string till LF
	repne  scasb
	; count LF symbols
	inc	ebx
	; reached the end ?
	cmp	ecx, 0
	je	@f
	cmp	ebx, 15
	je	@f
	; continue
	jmp	@b
@@:
	; compute offset
	mov	edx, [fsize]
	sub	edx, ecx
	; print data
	_stdwrite esi, edx
	;
	cinvoke getch
	jmp	.ask_again
.print_last:
	; backward direction
	std
	;
	xor	ebx, ebx
	xor	edx, edx
	;
	mov	eax, 10 ; LF
	mov	ecx, [fsize]
	mov	edi, [pmemend]
	; save address of the last symbol
	mov	esi, edi
	cmp	byte [edi], byte 10
	jne	 @f
	; skip CRLF sequense
	sub	edi, 2
	sub	ecx, 2
@@:
	repne  scasb
	; count LF symbols
	inc	ebx
	; reached the end ?
	cmp	ecx, 0
	je	@f
	cmp	ebx, 15
	je	@f
	; continue
	jmp	@b
@@:
	inc	edi
	mov	edx, [fsize]
	sub	edx, ecx
	cmp	byte [edi], byte 10
	jne	@f
	; move to non-space symbol
	inc	edi
@@:
	; restore DF flag and print
	cld
	_stdwrite edi, edx
	cinvoke getch
	jmp	.ask_again
.error:
	perror
	invoke	ExitProcess, 1
.exit:
	_funmap pmem
	_fclose hfile
	_fclose hmap
	invoke ExitProcess, 0


section '.idata' import data readable writeable

    library kernel32,'KERNEL32.DLL',user32,'USER32.DLL',gdi32,'GDI32.DLL', msvcrt,'MSVCRT.DLL'

    include 'API\Kernel32.Inc' 
    include 'API\User32.Inc' 
    include 'API\Gdi32.Inc'

    import msvcrt, \
	   getch, '_getch', \
	   printf, 'printf'
