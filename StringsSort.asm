DOSSEG
.model TINY

ABOVE equ 0
BELOW equ 1
EQUAL equ 2
SYMBOLS_PER_WORD equ 12

printText macro text

    mov dx, offset text
    mov ah, 9h
    int 21h

endm printText

.DATA

array1  db "ABCDEFGHIJ", 10, 13             ; ABCDEFGHIJ   sngtsrgvsr
        db "KLMNOPQRST", 10, 13             ; KLMNOPQRST   aoijcwaehd
        db "UVWXYZABCD", 10, 13             ; UVWXYZABCD   iufhnviuif
        db "EFGHIJKLMN", 10, 13             ; EFGHIJKLMN   siudghwapp
        db "OPQRSTUVWX", 10, 13             ; OPQRSTUVWX   kbjcxbtawe
        db "yzabcdefgh", 10, 13             ; yzabcdefgh   nuvwohafcp
        db "ijklmnopqr", 10, 13             ; ijklmnopqr   xpqewcpckv
        db "stuvwxyzab", 10, 13             ; stuvwxyzab   ygvyfdnmoi
        db "cdefghijkl", 10, 13             ; cdefghijkl   dsnfmwakew
        db "mnopqrstuv", 10, 13             ; mnopqrstuv   iusdngseff
        db "WXYZABCDEF", 10, 13             ; WXYZABCDEF   iuewvbgfai
        db "GHIJKLMNOP", 10, 13             ; GHIJKLMNOP   IGFIASiuan
        db "QRSTUVWXYZ", 10, 13             ; QRSTUVWXYZ   ANIGDhdaui
        db "ABCDEFGHIJ", 10, 13             ; ABCDEFGHIJ   bvdiunuiwe
        db "KLMNOPQRST", 10, 13             ; KLMNOPQRST   pwqpeoqwcd
        db "uvwxyzabcd", 10, 13             ; uvwxyzabcd   nvpsefwfwS
        db "efghijklmn", 10, 13             ; efghijklmn   HCFcEUIHSs
        db "opqrstuvwx", 10, 13             ; opqrstuvwx   DASvWACVDa
        db "yzabcdefgh", 10, 13             ; yzabcdefgh   VDAWDawdav
        db "ijklmnopqr", 10, 13             ; ijklmnopqr   DASJKvhafg
        db "$"

array2  db 20 dup(10 dup("$"), 10, 13)
        db "$"

delimiter db "---------------------", 10, 13, "$"

lastWordOffset db 228

.CODE

    start:

        mov ax, @data
        mov ds, ax

        ; Печать на экран массива и разделителя
        printText(array1)
        printText(delimiter)
        
        mov cx, 19
        loop2:
            push cx     ; запоминаем счетчик цикла loop2
            mov bx, offset array1

            loop1:

                push ax
                push dx
                push cx

                mov si, bx
                add si, SYMBOLS_PER_WORD

                push si
                push bx

                call compareWords
                
                cmp ax, ABOVE
                je nextPairAfterCompare

                cmp ax, EQUAL
                jne notRepeat

                takeOutRepeat:

                    mov ah, 0
                    mov al, lastWordOffset
                    sub ax, si
                    add ax, offset array1

                    mov dl, SYMBOLS_PER_WORD

                    div dl

                    mov ah, 0

                    mov cx, ax
                    mov di, bx
                    add di, SYMBOLS_PER_WORD
                    mov si, di
                    add si, SYMBOLS_PER_WORD

                    repeatSwap:

                        push cx

                        push si
                        push di

                        call swapWords

                        add si, SYMBOLS_PER_WORD
                        add di, SYMBOLS_PER_WORD

                        pop cx

                    loop repeatSwap

                    sub byte ptr [offset lastWordOffset], SYMBOLS_PER_WORD

                    pop cx
                    pop dx
                    pop ax

                    jmp nextPair

                notRepeat:
                
                    pop cx
                    pop dx
                    pop ax

                    ; если надо поменять строки местами
                    push ax
                    push cx

                    mov si, bx
                    add si, SYMBOLS_PER_WORD

                    push si
                    push bx

                    call swapWords
                    
                    pop cx
                    pop ax

            nextPair:

                add bx, SYMBOLS_PER_WORD    ; переход к следующей паре строк
                loop loop1
                pop cx
                loop loop2
                jmp exit

            nextPairAfterCompare:

                pop cx
                pop dx
                pop ax
                jmp nextPair
        
        exit:

            mov di, offset array1
            mov ax, 0
            mov al, lastWordOffset
            add al, SYMBOLS_PER_WORD
            add di, ax
            mov byte ptr [di], 24h

            mov dx, offset array1
            mov ah, 9h
            int 21h  
            
            mov dx, offset delimiter
            mov ah, 9h
            int 21h

            mov ah, 4ch
            int 21h

    ; Функция для сравнения двух строк в обратном лексикографическом порядке
    compareWords proc

        ; Переносим base pointer на начало фрейма функции
        push bp
        mov bp, sp

        ; Сохраняем регистры
        push bx
        push si
        push di

        ; Достаём из аргументов слова
        mov si, [bp + 4]    ; Первое слово
        mov di, [bp + 6]    ; Второе слово

        mov cx, 10
        compare:

            getSymbols:

                ; Помещаем по букве из каждого слова в dh и dl
                mov dh, byte ptr [si]
                mov dl, byte ptr [di]
            
            fisrtWordLetter:

                cmp dh, 5Ah         ; Проверяем, что dh — буква в верхнем регистре
                ja secondWordLetter ; Если нет, то переходим к букве второго слова

            ; Если так, то переводим в нижний регистр
            dhToLowerCase:
                
                add dh, 20h         ; Перевод dh в нижний регистр

            secondWordLetter:

                cmp dl, 5Ah         ; Проверяем, что dl — буква в верхнем регистре
                ja directСomparison ; Если нет, то переходим к непосредственному сравнению

            ; Если так, то переводим в нижний регистр
            dlToLowerCase:

                add dl, 20h         ; Перевод dl в нижний регистр

            directСomparison:

                cmp dh, dl
                ja compareWordsAbove

                cmp dh, dl
                jb compareWordsBelow

                inc si
                inc di

            loop compare

        compareWordsEqual:

            mov ax, EQUAL
            jmp compareWordsReturn

        compareWordsAbove:

            mov ax, ABOVE
            jmp compareWordsReturn

        compareWordsBelow:

            mov ax, BELOW
            jmp compareWordsReturn

        compareWordsReturn:

            ; Восстанавливаем регистры
            pop di
            pop si
            pop bx

            ; Восстанавливаем base pointer
            pop bp
            ret 4

    endp compareWords

    swapWords proc

        ; Переносим base pointer на начало фрейма функции
        push bp
        mov bp, sp

        ; Сохраняем регистры
        push bx
        push si
        push di

        mov si, [bp + 4]
        mov di, [bp + 6]

        mov cx, 10
        swapFor:

            mov al, byte ptr [si]
            mov bl, byte ptr [di]
            mov byte ptr [si], bl
            mov byte ptr [di], al
            inc si
            inc di

        loop swapFor

        ; Восстанавливаем регистры
        pop di
        pop si
        pop bx

        ; Восстанавливаем base pointer
        pop bp

        ret 4
    
    endp swapWords

end start
