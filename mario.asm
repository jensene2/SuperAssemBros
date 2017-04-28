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

score dd 0
scoreFormat db "You scored: ", 0

rows dd 10
cols dd 40
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
		; Redraw the screen
		mov eax, clear
		call print_string
		mov eax, text
		call print_string

		call movement

		; Check for a valid move. If invalid, loop again.
		call isValidMove
		cmp eax, 1
		jz doMove

		; Invalid move. Move mario back to previous.
		mov edx, [prevX]
		mov [x], edx
		mov edx, [prevY]
		mov [y], edx
		; Continue loop.
		jmp continue

		doMove:
			; Valid move. Resolve the move.

			; Moving subtracts one from the score.
			; If the score is already at zero, don't subtract.
			mov eax, [score]
			cmp eax, 0
			jz skipScore

			dec dword [score]

			skipScore:

			; First determine if that's the exit.
			; Get the ascii value of the new position.
			push dword [x]
			push dword [y]
			call getPosition

			; Clean stack.
			pop ebx
			pop ebx

			; Resolve the move.
			call update

			; Gold (eax == 71) adds 100 to the score.
			cmp eax, 71
			jnz skipScoreGain

			add dword [score], 100

			skipScoreGain:

			; The exit is eax == 69
			cmp eax, 69
			jz finish

			jmp continue
	;***************CODE ENDS HERE*********

	finish:
		; Redraw the screen
		mov eax, clear
		call print_string
		mov eax, text
		call print_string

		call print_nl
		mov eax, scoreFormat
		call print_string
		mov eax, [score]
		call print_int
		call print_nl

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


; isValidMove sets eax to 1 if it was a valid move, 0 otherwise.
isValidMove:
	push ebp
	mov ebp, esp

	; Get the current character at desired location.
	push dword [x]
	push dword [y]
	call getPosition

	; Clean stack.
	pop ebx
	pop ebx

	; If somehow mario is attempting to move onto mario, it should be invalid.
	cmp eax, 77
	jz invalid

	; Check if the new position is valid. Valid means nonsolid.
	push eax
	call isSolid
	pop ebx

	cmp eax, 1 ; If solid, invalid.
	jz invalid

	;valid:
		mov eax, 1
		jmp finishValidityCheck

	invalid:
		mov eax, 0
		jmp finishValidityCheck

	finishValidityCheck:
		; Return
	pop ebp
	ret


; getPosition returns the character at the position passed in via the stack.
getPosition:
	push ebp
	mov ebp, esp
	push ebx
	push ecx
	push edx

	mov eax, [ebp+12] ; X value passed in.
	mov ebx, [ebp+8] ; Y value passed in.
	mov edx, 0
	imul ebx, [cols]

	add eax, ebx

	mov ecx, 0

	mov cl, byte [text + eax]
	mov eax, 0
	mov al, cl

	pop edx
	pop ecx
	pop ebx
	pop ebp
	ret


; isSolid returns whether the given character is considered solid.
;   - A return value of 1 is solid, 0 is non-solid.
isSolid:
	push ebp
	mov ebp, esp

	mov eax, [ebp+8]

	cmp eax, 2Ah ; * = Border
	jz solid

	cmp eax, 42h ; B = Block
	jz solid

	;nonSolid:
		mov eax, 0
		jmp solidityReturn

	solid:
		mov eax, 1
		jmp solidityReturn

	solidityReturn:
		; Return
	pop ebp
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

collectGold:
	pushad

	add dword [score], 100

	mov eax, [x]
	mov ebx, [y]
	mov edx, 0
	imul ebx, [cols]

	add eax, ebx
	mov byte [text + eax], ' '

	popad
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
	; Can't jump if already in the air.
	push dword [x]
	mov ecx, [y]
	inc ecx
	push ecx
	call getPosition
	pop ebx
	pop ebx

	push eax
	call isSolid
	pop ebx

	cmp eax, 0 ; If nonsolid, jump to done.
	jz mDone

	mov ecx, 3
	mov eax, [x]
	push eax

	jumpLoop:
		; If the position above is nonsolid, move up.
		mov eax, [y]
		dec eax
		mov edx, eax

		push eax
		call getPosition

		cmp eax, 71 ; If it's gold, collect it.
		jnz skipCollectGold

		mov [y], edx
		call collectGold

		skipCollectGold:
		pop ebx

		push eax
		call isSolid
		pop ebx

		cmp eax, 1
		jz finishJump

		mov [y], edx
		loop jumpLoop
	finishJump:
		pop eax
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
	call handleFalling
	jmp mDone

left:
	mov eax, [x]
	dec eax
	mov [x], eax
	call handleFalling
	jmp mDone

mDone:
	pop eax
	popad
	ret


; handleFalling resolves the falling that should occur.
handleFalling:
	pushad

	push dword [x]
	mov ecx, [y]
	inc ecx
	push ecx
	call getPosition
	pop ebx
	pop ebx

	push eax
	call isSolid
	pop ebx

	cmp eax, 0 ; If nonsolid, fall.
	jz doFall

	jmp fallingReturn

	doFall:
		mov [y], ecx
		jmp fallingReturn

	fallingReturn:
		;Return
	popad
	ret
