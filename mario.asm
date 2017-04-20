%include "asm_io.inc"
%include "io.inc"
; initialized data is put in the .data segment
segment .data
clear db 27,"[2J",27,"[1;1H",0
cc db 27,"c",0
scanFormat db "%c",0
file db "input.txt",0
mode db "r",0
formatA db "%c",0
x dd 3
y dd 3
prevX dd 0
prevY dd 0
exitX dd 0
exitY dd 0

rows dd 8
cols dd 27
; uninitialized data is put in the .bss segment
segment .bss
text resb 2000

; code is put in the .text segment
segment .text
	global  asm_main
	extern fscanf
	extern fopen
	extern fclose
	extern scanf
	extern getchar
	extern putchar
asm_main:
	enter   0,0               ; setup routine
	pusha

	;***************CODE STARTS HERE*******
	mov eax, clear    ;two lines to clear
	call print_string ;clear the screen
	mov eax, cc
	call load	;load the file into text
	call update ;update the file with the location

	continue:
		mov eax, text
		call print_string

		call movement

		; Print what is where mario attempted to move to.
		push dword [x]
		push dword [y]
		call getPosition
		call print_char
		call print_nl

		call update

		; Redraw the screen
		mov eax, clear
		call print_string

		; Check if at the exit.
		mov eax, [prevX]
		mov ebx, [exitX]
		cmp eax, ebx
		jnz continue

		mov eax, [prevY]
		mov ebx, [exitY]
		cmp eax, ebx
		jnz continue
	;***************CODE ENDS HERE*********

	popa
	mov     eax, 0            ; return back to C
	leave
	ret


;*********************************
;* Function to load var text with*
;* input from input.txt          *
;*********************************
load:
	push eax
	push esi
	mov esi, 0

	sub esp, 20h
	;get the file pointer
	mov dword [esp+4], mode; the mode for the file which is "r"
	mov dword [esp], file; the name of the file.  Hard coded here (input.txt)
	call fopen ; call fopen to open the file

	;read stuff
	mov [esp], eax; mov the file pointer to param 1
	mov eax, esp  ;use stack to store a pointer where char goes
	add eax, 1Ch  ;address is 1C up from the bottom of the stack
	mov [esp+8], eax ;pointer is param 3
	mov dword [esp+4], scanFormat; format is param 2

	mov edx, 0
	mov [prevX], edx
	mov [prevY], edx

	scan:
		call fscanf; call scanf
		cmp eax, 0 ; eax will be less than 1 when EOF
		jl done; eof means quit
		mov eax, [esp+1Ch]; mov the result (on the stack) to eax

		cmp al, 'M'
		jz Mario

		cmp al, 'E'
		jz Exit

		mov edx, [prevX]; increment prevX
		inc edx
		mov [prevX], edx

		cmp al, 10
		jz NewLine
		jmp save

	NewLine:
		mov dword [prevX], 0
		mov edx, [prevY]
		inc edx
		mov [prevY], edx
		jmp save

	Mario:
		mov edx, [prevX]
		mov [x], edx
		mov edx, [prevY]
		mov [y], edx
		jmp save

	Exit:
		mov edx, [prevX]
		mov [exitX], edx
		mov edx, [prevY]
		mov [exitY], edx
		jmp save

	save:
		mov [text + esi], al; store in the array
		inc esi; add one to esi (index in the array)
		cmp esi, 2000; dont go tooo far into the array
		jz done; quit if went too far
		jmp scan ;loop back

	done:
		call fclose; close the file pointer
		mov byte [text+esi],0 ;set the last char to null
		add esp, 20h; unallocate stack space

	pop esi	;restore registers
	pop eax
	ret

; getPosition returns the character at the position passed in via the stack.
getPosition:
	enter 0, 0

	mov eax, [ebp+4] ; X value passed in.
	mov ebx, [ebp+8] ; Y value passed in.
	mov edx, 0
	imul ebx, [cols]

	add eax, ebx

	mov ecx, 0

	mov cl, byte [text + eax]
	mov eax, 0
	mov al, cl

	leave
	ret


;*********************************
;* Function to update the screen *
;*                               *
;*********************************
update:
	push eax
	push ebx

	;update the new loc
	mov eax, [x]
	mov ebx, [y]
	mov edx, 0
	imul ebx, [cols]

	add eax, ebx
	mov byte [text + eax], 'M'

	;update the old loc
	mov eax, [prevX]
	mov ebx, [prevY]
	mov edx, 0
	imul ebx, [cols]

	add eax, ebx
	mov byte [text + eax], ' '

	pop ebx
	pop eax
	ret


;*********************************
;* Function to get mouse movement*
;*                               *
;*********************************
movement:
	pushad
	mov ebx, [x]
	mov [prevX], ebx;save old value of x in prevX

	mov ebx, [y]
	mov [prevY], ebx; save old value of y in prevY

	call canonical_off
	call echo_off
	mov eax, formatA
	push eax

	;http://stackoverflow.com/questions/15306463/getchar-returns-the-same-value-27-for-up-and-down-arrow-keys
	call getchar
	call getchar
	call getchar
	call canonical_on
	call echo_on

	; Up
	cmp eax, 41h
	jz up

	; Down
	cmp eax, 42h
	jz down

	; Right
	cmp eax, 43h
	jz right

	; Left
	cmp eax, 44h
	jz left

	jmp mDone

up:
	mov eax, [y]
	dec eax
	mov [y], eax
	jmp mDone

down:
	mov eax, [y]
	inc eax
	mov [y], eax
	jmp mDone

right:
	mov eax, [x]
	inc eax
	mov [x], eax
	jmp mDone

left:
	mov eax, [x]
	dec eax
	mov [x], eax
	jmp mDone

mDone:
	pop eax
	popad
	ret
