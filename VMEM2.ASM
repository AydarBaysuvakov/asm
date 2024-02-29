.model tiny
.code
.186
org 100h
locals @@

;---Program info---------------------------------------------------------------------------------
; This program draw a little window with text
;
;
; Input data:
;    Parametrs:
;    1)width
;    2)height
;    3)colour
;    4)border size
;    5)text
;
; 1)If first symbol is letter, program will interpreter all line as input text.
; All parametrs instead of text will taken from base constants
; 2)If first symbol is number, program will interpreter parametrs in order of the list above.
; 3)Colour code should have 3 symbol, first two should be hexadecimal numbers, third should be "h".
; Otherwise, next symbols will interpreter as text.
; 4)If here text instead of width, height, colour or border size then all symbols after last valid number
; will interpreted as text.
;
;------------------------------------------------------------------------------------------------

;---Constants------------------------------------------------------------------------------------

; Width and height of screen is 80x25
; All frames will centered in position 40x10
; First and last X position calculated as (CenterX - Width  / 2), (CenterX + Width  / 2)
; First and last Y position calculated as (CenterY - Height / 2), (CenterY + Height / 2)
; Base Width and Height are 40 and 15

CenterX         equ 40
CenterY         equ 10

ScreenWidth     equ 80
ScreenHeight    equ 25

BaseWidth       equ 60
BaseHeight      equ 10

; Colour in rgb format:
; high bytes for foregrount
; low bytes for letter colour
; 'h' in the end for hex format
;
; byte:   76543210
; colour:  rgbirgb
;
; if bit 1 -> colour has shade
; if bit 0 -> colour has no shade
;
; Examples:
; 4eh - bright yellow letter on red foreground
; 0fh - white letter on black foreground
; 35h - magenta letter on cyan foreground

BaseColour      equ 3eh
BaseBorderWidth equ 2

; Video memory start address
; (See thelp: bla bla bla)

VideoMemoryStartAddress  equ 0b800h

; Comand line start address
; (See thelp: bla bla bla)

CommandLineLenghtAddress equ 80h
CommandLineStartAddress  equ 81h

SpaceSymbol              equ ' '
Vertical                 equ 0bah
Horizont                 equ 0cdh

;-----------------------------------------------------------------------------------------------

;---Program body--------------------------------------------------------------------------------

Start:
			call InputData
			call DrawFrame
			mov ax, 4c00h
			int 21h

;-----------------------------------------------------------------------------------------------

;---Functions-----------------------------------------------------------------------------------

; InputData function get parametrs from comand line
; Enter:        None
; Return:
; Destroyed:    DI, SI, AX, BX

InputData   proc

		  ; si = di + "LineLenght"

            mov bx, CommandLineLenghtAddress
			mov si, CommandLineStartAddress
            mov bx, [bx]
            mov bh, 0
			add si, bx
            mov di, CommandLineStartAddress

		  ; Error codes:
		  ; 0 - Space (Continue)
		  ; 1 - End of line (Save and exit)
		  ; 2 - Another symbol (Exit)

          ; Read frame Width
            call SkipSpace
            call GetValue
          ; Error -> Exit function
            cmp ax, 0
            je @@End
            cmp ErrorCode, 2
            je @@End
            mov Width, ax
			cmp ErrorCode, 1
            je @@End

          ; Read frame Height
            call SkipSpace
            call GetValue
          ; Error -> Exit function
            cmp ax, 0
            je @@End
            cmp ErrorCode, 2
            je @@End
            mov Height, ax
			cmp ErrorCode, 1
            je @@End


          ; Read Colour code
            call SkipSpace
            call GetColour
          ; Error -> Exit function
            cmp ErrorCode, 0
            jne @@End
            mov Colour, al

          ; Read border width
            call SkipSpace
            call GetValue
          ; Error -> Exit function
            cmp ErrorCode, 2
            je @@End
            mov BorderWidth, ax
			cmp ErrorCode, 1
            je @@End

            call SkipSpace

@@End:
            mov TextOffset, di
            ret
            endp

; SkipSpace skips all space symbols in command line
; Enter:        DI - address to symbol
; Return:       DI - address to next non space symbol
; Destroyed:    DI

SkipSpace   proc

          ; while (di <= si && [di++] == SpaceSymbol)

@@Skip:
            cmp di, si
            jae @@End

            cmp byte ptr[di], SpaceSymbol
		    jne @@End

            inc di
            jmp @@Skip

@@End:
            ret
            endp

; GetValue reads decimal number till gets space
; (if get wrong symbol, returns to first symbol of number and put 1 to dh)
; Enter: DI - addres to first digit
; Exit:  AL - value
; Destr: AX, DX, DI

GetValue    proc
            mov ax, 0
            mov dx, di      ; if wrong number, we should return di its value, so we save it now

@@NextDigit:
          ; if    (di == si) {return 1}
          ; elif  ([di] == SpaceSymbol) {return 0}
          ; elif !('0' <= [di] <= '9') { /opertation\ }
          ; else {return 2}

            mov ErrorCode, 1
			cmp di, si
		    jae @@End

			mov ErrorCode, 0
            cmp byte ptr[di], SpaceSymbol
		    je @@End

            mov ErrorCode, 2
		    cmp byte ptr[di], '0'
		    jb @@WrongSymbol
            cmp byte ptr[di], '9'
            ja @@WrongSymbol

          ; al *= 10
          ; al += [di++] - '0'

            mul Decimal
		    add ax, [di]
		    sub ax, '0'
		    inc di

            jmp @@NextDigit

@@WrongSymbol:
            mov di, dx

@@End:
            mov ah, 0
        	ret
            endp


; GetValue reads colour code in hex format
; (if get wrong symbol, returns to first symbol of number and put 2 to dh)
; Enter:  DI - addres to first symbol
; Return: AL - colour code
; Destr: AX, DI

GetColour   proc
            mov ax, 0
            mov dx, di

@@NextValue:
            mov ErrorCode, 0
            cmp byte ptr[di], 'h'
            je @@End

            mov ErrorCode, 2
			cmp di, si
		    je @@End
            cmp byte ptr[di], SpaceSymbol
		    je @@End

          ; ax *= 16
          ; ax += [di++]

            shl ax, 4
            add ax, [di]

@@Numbers:

          ; if ('0' <= [di] <= '9') {ax -= '0'}

		    cmp byte ptr[di], '0'
		    jb @@SmallLetters
            cmp byte ptr[di], '9'
            ja @@SmallLetters

            sub ax, '0'
            inc di
            jmp @@NextValue

@@SmallLetters:

          ; if ('a' <= [di] <= 'f') {ax += 10 - 'a'}

		    cmp byte ptr[di], 'a'
		    jb @@CapitalLetters
            cmp byte ptr[di], 'f'
            ja @@CapitalLetters

            sub ax, 'a'
            add ax, 10
            inc di
            jmp @@NextValue

@@CapitalLetters:

          ; if ('A' <= [di] <= 'F') {ax += 10 - 'A'}

		    cmp byte ptr[di], '0'
		    jb @@End
            cmp byte ptr[di], '9'
            ja @@End

            sub ax, 'A'
            add ax, 10
            inc di
            jmp @@NextValue

@@End:
            inc di
        	ret
            endp


; Draw a frame with a text
; Enter:    Width
;           Height
;           Colour
;           BorderWidth
;           TextOffset
;           SI - Offset to comand line end
; Destroyed: AX, BX, CX, DX, ES, DI, SI, BP

DrawFrame   proc
	        mov bx, 0b800h
	        mov es, bx

            mov bp, TextOffset

          ; ((CenterY - Height  / 2) * ScreenWidth + (CenterX - Width / 2)) * 2

            mov di, CenterY
            mov ax, Height
            shr ax, 1
            sub di, ax

            mov ax, di
            mul ScreenW                      ; ScreenWidth
            mov di, ax

            add di, CenterX
            mov ax, Width
            shr ax, 1
            sub di, ax

            shl di, 1

		    mov cx, Width
            mov dx, Height

@@DrawRow:
            call ChooseSymbol
            stosw
		    loop @@DrawRow

          ; di += (ScreenWidth - Width) * 2

            mov ax, ScreenWidth
            sub ax, Width
            shl ax, 1
            add di, ax

            mov cx, Width
            dec dx
            cmp dx, 0
            jne @@DrawRow

            ret
            endp

ChooseSymbol    proc
            mov ah, Colour

@@ExternalBorders:
          ; if (cx <= BorderWidth || cx > Width - BorderWidth) {return SpaceSymbol}

            mov al, SpaceSymbol
            mov bx, BorderWidth
            cmp cx, bx
            jbe @@End
            mov bx, Width
            sub bx, BorderWidth
            cmp cx, bx
            ja @@End

@@RightBorders:
          ; if (cx == BorderWidth + 1)
          ;    {
          ;    if      (dx == 1)      {return "RightDown"}
          ;    else if (dx == Height) {return "RightUp"}
          ;    else                   {return "Vertical"}
          ;    }

            mov bx, BorderWidth
            inc bx
            cmp cx, bx
            jne @@LeftBorders

            mov al, 0bbh        ; RightUp
            mov bx, Height
            cmp dx, bx
            je @@End

            mov al, 0bch        ; RightDown
            mov bx, 1
            cmp dx, bx
            je @@End

            mov al, Vertical
            jmp @@End

@@LeftBorders:
          ; if (cx == Width - BorderWidth)
          ;    {
          ;    if (dx == 1)      {return "LeftDown"}
          ;    if (dx == Height) {return "LeftUp"}
          ;    else              {return "Vertical"}
          ;    }

            mov bx, Width
            sub bx, BorderWidth
            cmp cx, bx
            jne @@HorizontalBorders

            mov al, 0c9h        ; LeftUp
            mov bx, Height
            cmp dx, bx
            je @@End

            mov al, 0c8h        ; LeftDown
            mov bx, 1
            cmp dx, bx
            je @@End

            mov al, Vertical
            jmp @@End

@@HorizontalBorders:
          ; if (dx == 1 || dx == Height) {return Horizont}

            mov al, Horizont
            mov bx, Height
            cmp dx, bx
            je @@End
            mov bx, 1
            cmp dx, bx
            je @@End

@@FrameEntry:
          ; else if (bp < si) {return [bp]} else {return SpaseSymbol}

            mov al, SpaceSymbol
            cmp bp, si
            jae @@End
            mov al, [bp]
            inc bp
            jmp @@End

@@End:      ret
            endp

;------------------------------------------------------------------------------------------------

;---Variables------------------------------------------------------------------------------------

Width       DW BaseWidth
Height      DW BaseHeight
Colour      DB BaseColour
BorderWidth DW BaseBorderWidth
TextOffset  DW CommandLineStartAddress
ErrorCode   DB 0
Decimal     DB 10
Hex         DB 16
ScreenW     DW ScreenWidth

;-----------------------------------------------------------------------------------------------

end         Start
