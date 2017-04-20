segment .data
termios:        times 36 db 0
stdin:          equ 0
ICANON:         equ 1<<1
ECHO:           equ 1<<3

segment .text
global canonical_off, echo_off,echo_on, canonical_on, write_stdin_termios, read_stdin_termios

;*********************************
;* Function turn off canonical   *
;*                               *
;*********************************
canonical_off:
	call read_stdin_termios
	; clear canonical bit in local mode flags
	push eax
	mov eax, ICANON
	not eax
	and [termios+12], eax
	pop eax
	call write_stdin_termios
	ret

;*********************************
;* Function turn off echo        *
;*                               *
;*********************************
echo_off:
	call read_stdin_termios
	; clear echo bit in local mode flags
	push eax
	mov eax, ECHO
	not eax
	and [termios+12], eax
	pop eax
	call write_stdin_termios
	ret

;*********************************
;* Function turn canonical on    *
;*                               *
;*********************************
canonical_on:
	call read_stdin_termios
	; set canonical bit in local mode flags
	or dword [termios+12], ICANON
	call write_stdin_termios
	ret

;*********************************
;* Function turn echo on         *
;*                               *
;*********************************
echo_on:
	call read_stdin_termios
	; set echo bit in local mode flags
	or dword [termios+12], ECHO
	call write_stdin_termios
	ret

;*********************************
;* Function read termios         *
;*                               *
;*********************************
read_stdin_termios:
	push eax
	push ebx
	push ecx
	push edx

	mov eax, 36h
	mov ebx, stdin
	mov ecx, 5401h
	mov edx, termios
	int 80h

	pop edx
	pop ecx
	pop ebx
	pop eax
	ret

;*********************************
;* Function write a termios      *
;*                               *
;*********************************
write_stdin_termios:
	push eax
	push ebx
	push ecx
	push edx

	mov eax, 36h
	mov ebx, stdin
	mov ecx, 5402h
	mov edx, termios
	int 80h

	pop edx
	pop ecx
	pop ebx
	pop eax
	ret
