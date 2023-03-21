DOSSEG

.MODEL TINY
.STACK 100h

.386

org 100h

.DATA

    alarmHours      db 00011000b    ; Часы в BCD формате (11 часов -> 1 -> 0001b, следовательно, 11 -> 00010001b)
    alarmMinutes    db 01000101b    ; Минуты в BCD формате (45 минут -> 4 -> 0100b, 5 -> 0101b, следовательно, 45 -> 01000101b)
    alarmSeconds    db 00000000b    ; Секудны в BCD формате (00 -> 00000000b)
    alarmSetMsg     db "Alarm set on 11:45. Press any key to cancel, message ", 22h, "Error", 22h, " will appear.", 10, 13, '$'
    alarmSetError   db "Can't set alarm", 10, 13, '$'
    residentError   db "Alarm is already set", 10, 13, '$'
    alarmError      db "Error", 10, 13, '$'
    alarmOldVect    dd 0            ; "Оригинальный" вектор прерывания будильника
    keyboardOldVect dd 0            ; "Оригинальный" вектор прерывания клавиатуры
    isEnterUp       db 0            ; Запуск резидентной программы

.CODE

Start:

    jmp Transit     ; Переход в транзитную часть

; Резидентная часть
Resident:

    resetIntHandlers:
        ; Сохраняем регистры
        push ax
        push dx
        push ds

        mov ax, @data
        mov ds, ax

        ; Возвращаем старый обработчик прерывания клавиатуры
        mov ah, 25h     ; Функция 25h прерывания 21h (Установить вектор прерывания)
        mov al, 09h     ; Номер прерывания вектор которого восстанавливаем (прерывание клавиатуры)
        mov dx, word ptr [offset keyboardOldVect]       ; смещение (крайняя часть до :)
        mov bx, word ptr [offset keyboardOldVect + 2]   ; сегмент (адрес старого прерывания)
        mov ds, bx
        int 21h         ; Заменяем

        ; Возвращаем старый обработчик прерывания будильника
        mov ah, 25h     ; Функция 25h прерывания 21h (Установить вектор прерывания)
        mov al, 4Ah     ; Номер прерывания вектор которого восстанавливаем (прерывание будильника)
        mov dx, word ptr [offset alarmOldVect]          ; смещение (крайняя часть до :)
        mov bx, word ptr [offset alarmOldVect + 2]      ; сегмент (адрес старого прерывания)
        mov ds, bx
        int 21h         ; Заменяем

        ; Восстанавливаем регистр
        pop ds
        pop dx
        pop ax

        ret
    
    programKey dw 5555h
    
    ; Новый обработчик прерывания клавиатуры
    int09h_handler:

        ; Сохранение регистров
        push ax
        push dx
        push ds

        mov ax, @data
        mov ds, ax

        ; Проверяем отжатие клавиши Enter после запуска программы
        cmp isEnterUp, 0
        je ignoreEnterUp

        ; Вывод сообщения об ошибке
        mov ah, 09h
        mov dx, offset alarmError
        int 21h

        ; Сброс будильника
        mov ah, 07h
        int 1Ah

        ; Восстановление регистров
        pop ds
        pop dx
        pop ax

        ; Переход к выгрузке программы из памяти
        jmp unloadResident

    ignoreEnterUp:

        ; Ставим флаг отжатия клавиши Enter
        inc byte ptr [offset isEnterUp]
        
        ; Восстанавливаем регистры
        pop ds
        pop dx
        pop ax
        
        ; Переход к старому обработчику клавиатуры
        jmp cs:keyboardOldVect

    ; Новый обработчик прерывания будильника
    int4Ah_handler:

        ; Сохраняем регистры
        push ax
        push bx
        push dx
        push cx
        push ds

        mov ax, @data
        mov ds, ax

        ; Вывод сообщения об ошибке
        mov ah, 09h
        mov dx, offset alarmError
        int 21h

        ; Проигрывание звука
        mov bx, 200         ; частота
        mov ax, 34DDh
        mov dx, 12h         ; (dx,ax)=1193181
        cmp dx, bx          ; если bx < 18Гц, то выход
        jnb done            ; чтобы избежать переполнения
        div bx              ; ax=(dx,ax)/bx

        mov bx, ax          ; счетчик таймера
        in al, 61h          ; порт РВ
        or al, 3            ; установить биты 0-1
        out 61h, al
        mov al, 00001011b   ; управляющее слово таймера:
                            ; канал 2, режим 3, двоичное слово
        mov dx, 43h         ; вывод в регистр режима
        out dx, al          ; устанавливаем режим работы таймера
        dec dx              ; порт 2-го канала
        mov al, bl          ; младший байт счетчика
        out dx, al          ; записываем
        mov al, bh          ; старший байт счетчика
        out dx, al          ; записываем

        mov dx, 50
        nextCycle:

            mov cx, 150     ; длительность первой половины

        cycleUp:

            loop cycleUp    ; задержка пока сигнал высокий

        cycleDown:

            loop cycleDown  ; задержка пока сигнал низкий
            dec dx          ; уменьшаем счетчик циклов
            jnz nextCycle   ; повторяем цикл пока DX не 0

        done:

            in  al, 61h         ; порт РВ
            and al, not 3       ; сброс битов 0-1
            out 61h, al         ; возвращаем значение в порт

        ; Восстановление регистров
        pop ds
        pop cx
        pop dx
        pop bx
        pop ax

        ; Переход к выгрузке программы из памяти
        jmp unloadResident

    ; Выгрузка программы из памяти
    unloadResident:

        ; Блокируем прерывания
        CLI

        call resetIntHandlers

        push cs
        pop ds
        ; Настраиваемся на текущий сегмент и выгружаемся
        push cs
        pop  es

        ; Разрешаем прерывания
        STI

        ; Сброс будильника
        mov ah, 07h
        int 1Ah

        ; Освобождение памяти резидента
        mov ah, 49h
        int 21h

        ; Переход к старому обработчику клавиатуры
        jmp cs:keyboardOldVect

    ; Освобождение памяти резидента и обычное завершение программы
    freeResident:

        call resetIntHandlers

        mov si, 0Bh
        and byte ptr [si], 11011111b

        mov ah, 49h
        int 21h

        jmp quit

; Транзитная часть
Transit:

    mov ax, @data
    mov ds, ax

    mov ah, 02h
    int 1Ah

    mov dl, ch
    shr dl, 4
    add dl, 30h
    int 21h

    mov dl, ch
    shl dl, 4
    shr dl, 4
    add dl, 30h
    int 21h

    mov dl, 58
    int 21h

    mov dl, cl
    shr dl, 4
    add dl, 30h
    int 21h

    mov dl, cl
    shl dl, 4
    shr dl, 4
    add dl, 30h
    int 21h

    mov dl, 10
    int 21h

    mov dl, 13
    int 21h

    ; Блокируем прерывания
    CLI

    ; Получаем вектор прерывания клавиатуры (int 09h)
    mov ah, 35h     ; Функция прерывания 21h, выдаёт текущий вектор прерывания al
    mov al, 09h     ; Прерывание клавиатуры
	int 21h

    ; Проверяем загружен ли уже резидент
    mov ax, es:[bx - 2]     ; Отступаем на слово, так как перед меткой нового обработчика как раз лежит слово-ключ резидента
	cmp ax, cs:programKey   ; Сверяем ключ
	je freeResident         ; Если ключи совпадают, резидент ещё загружен в памяти, переходим к выводу ошибки и завершению

    mov word ptr [offset keyboardOldVect], bx
	mov word ptr [offset keyboardOldVect + 2], es

    ; Устанавливаем новый обработчик прерывания клавиатуры
    mov ah, 25h     ; Функция прерывания 21h, устанавливает вектор прерывания al
    mov al, 09h     ; Прерывание клавиатуры
	mov dx, offset int09h_handler
	int 21h

    ; Аналогично с прерывание будильника (int 4Ah)
    ; Сброс будильника
    mov ah, 07h
    int 1Ah

    mov ah, 35h
    mov al, 4Ah     ; Прерывание будильника
	int 21h

	mov word ptr [offset alarmOldVect], bx
	mov word ptr [offset alarmOldVect + 2], es

    mov ah, 25h
    mov al, 4Ah
	mov dx, offset int4Ah_handler
	int 21h
	STI

    mov si, 0Bh
    or byte ptr [si], 00100000b

    ; Устанавливаем будильник
    mov ah, 06h             ; Функция прерывания будильника для его установки
    mov ch, alarmHours      ; Устанавливаем часы
    mov cl, alarmMinutes    ; Устанавливаем минуты
    mov bh, alarmSeconds     ; Устанавливаем секунды через регистр общего назначения
    mov dh, bh
    int 1Ah

    ; Проверка, установлен ли будильник
    jc quitAlarmSetError

    ; Выводим сообщение об установке будильника
    mov ah, 09h
    mov dx, offset alarmSetMsg
	int 21h

    ; Выгружаем сегмент окружения (PSP)
    ; mov ah, 49h     ; Освободить распределённый блок памяти
	; mov es, word ptr cs:[2Ch]
	; int 21h

    jmp quitButStayResident     ; Переходим к завершению

    ; очистка экрана путем установки нового режима
    ; mov ah, 0 ; номер функции установки режима дисплея
    ; mov al, 2 ; код текстового режима 80*25(разрешения) черно-белый
    ; int 10H   ; очистка экрана

    ; Завершаем программу но оставляем резидентной
    quitButStayResident:
        
        mov dx, offset Transit
	    int 27h

    ; Вывести сообщение об ошибки и завершить программу
    quitWithError:

        ; Вывод сообщения об ошибке
        mov ah, 09h
        mov dx, offset residentError
        int 21h

        jmp quit

    quitAlarmSetError:

        call resetIntHandlers

        ; Вывод сообщения об ошибке
        mov ah, 09h
        mov dx, offset alarmSetError
        int 21h

        jmp quit

    ; Завершение программы
    quit:

        mov si, 0Bh
        and byte ptr [si], 11011111b

        mov ah, 4ch
        int 21h

END Start
