.8086
.MODEL  TINY
.STACK  100H
COD     SEGMENT PARA
ASSUME  CS:COD,DS:DATA,SS:STACK
LEN_COM_LOADER      EQU     END_COM_LOADER-COM_LOADER
LEN_COM_INT_9       EQU     L1-COM_INT_9
COM_LOADER  PROC
        CALL    L1
COM_INT_9:
;        PUSH    AX
;        IN      AL,60H
;        CMP     AL,10H
;        JNZ     L5
;        PUSH    DS
;        XOR     AX,AX
;        MOV     DS,AX
;        TEST    BYTE PTR DS:[417H],1000B
;        POP     DS
;        JZ      L5
;        PUSH    CX
;        PUSH    SI
;        PUSH    DI
;        PUSH    BP
;        PUSH    DS
;        PUSH    ES
;        MOV     BP,SP
;        LES     DI,SS:[BP+14]
;        PUSH    CS
;        POP     DS
;        MOV     SI,QUITER-COM_INT_9+100H
;        CLD
;        MOV     CX,5
;        REP     MOVSB
;        POP     ES
;        POP     DS
;        POP     BP
;        POP     DI
;        POP     SI
;        POP     CX
;L5:
;        POP     AX
        JMP     DWORD PTR CS:[OLD_COM_INT_9]
QUITER:
        MOV     AX,4C00H
        INT     21H
OLD_COM_INT_9       DD      ?
LOW_    DW      ?
HIGH_   DW      0A000H
L1:
        POP     AX
        MOV     SP,100H
        PUSH    AX
        ;Копирование загрузчика
        SUB     AX,100H
        MOV     SI,AX
        MOV     AX,CS
        ADD     AX,10H
        MOV     DS,AX
        MOV     DI,100H
        MOV     CX,(LEN_COM_LOADER)-3
        REP     MOVSB
        MOV     AX,L4-COM_INT_9+100H
        PUSH    AX
        RET
L4:
        XOR     AX,AX
        MOV     DS,AX
        MOV     AX,DS:[9*4]
        MOV     WORD PTR ES:[OLD_COM_INT_9-COM_INT_9+100H],AX
        MOV     AX,DS:[9*4+2]
        MOV     WORD PTR ES:[OLD_COM_INT_9-COM_INT_9+102H],AX
        MOV     AX,ES
        MOV     DS,AX
        MOV     DS:[BLOCK-COM_INT_9+104H],AX
        MOV     DS:[BLOCK-COM_INT_9+108H],AX
        MOV     DS:[BLOCK-COM_INT_9+10CH],AX
        MOV     DS:[LOW_-COM_INT_9+100H],AX
        POP     AX
        MOV     DS:[SHIFT-COM_INT_9+100H],AX

        ;Загрузка файла
        MOV     AH,4AH
        MOV     BX,10H+(LEN_COM_LOADER+15)/16
        INT     21H
        JC      L_EXIT
        PUSH    ES
        POP     DS
        MOV     DX,PROG_NAME-COM_INT_9+100H
        MOV     BX,BLOCK-COM_INT_9+100H
        MOV     AX,4B01H
        INT     21H
        JNC     L2
        MOV     DX,CALL_FILE-COM_INT_9+100H
        MOV     AH,09H
        INT     21H
L_EXIT:
        MOV     AX,4C00H
        INT     21H
L2:
        ;Запись в таблицу векторов прерываний
        XOR     AX,AX
        MOV     DS,AX
        MOV     AX,100H
        CLI
        MOV     DS:[9*4],AX
        MOV     AX,CS
        MOV     DS:[9*4+2],AX
        STI
        MOV     AX,CS:[SHIFT-COM_INT_9+100H]
        SUB     AX,6
        MOV     SI,AX
        MOV     DS,CS:[BLOCK-COM_INT_9+100H+14H]
        PUSH    DS
        POP     ES
        MOV     DI,100H
        MOV     CX,3
        REP     MOVSB
        CLI
        MOV     SP,CS:[BLOCK-COM_INT_9+10EH]
        MOV     SS,CS:[BLOCK-COM_INT_9+110H]
        STI
        XOR     AX,AX
        MOV     BX,AX
        MOV     CX,AX
        MOV     DX,AX
        MOV     SI,AX
        MOV     DI,AX
        MOV     BP,AX
        JMP     DWORD PTR CS:[BLOCK-COM_INT_9+112H]
SHIFT   DW      0
BLOCK   DW      0
        DW      81H,?
        DW      5CH,?
        DW      6CH,?
        DW      ?,?
        DW      ?,?
CALL_FILE       DB      'Назовите этот файл:'
PROG_NAME       DB      14H     DUP     ('$')
END_COM_LOADER:
ENDP
START:
        MOV     SI,81H
A1:
        LODSB
        CMP     AL,0DH
        JNZ     A2
        JMP     NO_FILE
A2:
        CMP     AL,' '
        JZ      A1
        DEC     SI
        PUSH    DS
        PUSH    SI
        PUSH    CS
        POP     ES
        LEA     DI,PROG_NAME
A4:
        LODSB
        CMP     AL,' '
        JZ      A5
        CMP     AL,0DH
        JZ      A5
        STOSB
        JMP     SHORT   A4
A5:
        XOR     AL,AL
        MOV     BYTE PTR DS:[SI-1],AL
        STOSB
        POP     SI
        PUSH    SI
        PUSH    DS
        POP     ES
        MOV     DX,SI
        MOV     AX,BUF
        MOV     DS,AX
        XOR     DX,DX
        PUSH    DS
        PUSH    DX
        MOV     AX,-1
        CALL    LOAD_FILE
        JNC     A3
        JMP     ERROR
A3:
        ;Определение типа файла
        MOV     AX,BUF
        MOV     DS,AX
        XOR     SI,SI
        ROR     BX,4
        PUSH    CX
        SHR     CX,4
        ADD     AX,CX
        ADD     AX,BX
        MOV     ES,AX
        POP     AX
        AND     AX,0FH
        MOV     DI,AX
        MOV     DX,AX
        CMP     WORD PTR DS:[SI],'ZM'
        MOV     AX,101H;EXE-файл
        JZ      ERROR
        ;Замена звголовка
        MOV     CX,3
        REP     MOVSB
        MOV     BX,ES
        MOV     AX,DS
        SUB     BX,AX
        MOV     AX,102H;Неправильная длина
        CMP     BX,0FFFH
        JNC     ERROR
        PUSH    ES
        PUSH    DI
        PUSH    DS
        POP     ES
        XOR     DI,DI
        MOV     AL,0E9H
        STOSB
        MOV     AX,BX
        SHL     AX,4
        ADD     AX,DX
        STOSW
        POP     DI
        POP     ES
        ;Допись загрузчика
        MOV     AX,COD
        MOV     DS,AX
        LEA     SI,COM_LOADER
        MOV     CX,LEN_COM_LOADER
        REP     MOVSB
        ;Вычисление общей длины
        MOV     AX,DI
        AND     DI,0FH
        SHR     AX,4
        MOV     BX,ES
        ADD     AX,BX
        SUB     AX,BUF
        ROL     AX,4
        MOV     BX,AX
        AND     BX,0FH
        AND     AX,0FFF0H
        ADD     AX,DI; BX:AX - Новая длина файла
        MOV     CX,AX
        POP     DX
        POP     DS
        POP     SI
        POP     ES
        CALL    SAVE_FILE
        JC      ERROR
        MOV     AX,4C00H
        INT     21H
NO_FILE:
        MOV     AX,100H;Не указан файл
ERROR:
        CALL    PRINT_IO_ERRORS
        MOV     AX,4C01H
        INT     21H
PRINT_IO_ERRORS PROC
        PUSH    AX
        PUSH    DX
        PUSH    DS


        PUSH    CS
        POP     DS
        PUSH    AX
        LEA     DX,NO_FILE_
        SUB     AX,100H
        JZ      PRINT_IO_ERROR_5
        LEA     DX,EXE_FILE_
        DEC     AX
        JZ      PRINT_IO_ERROR_5
        LEA     DX,WRONG_LENGHT_
        DEC     AX
        JZ      PRINT_IO_ERROR_5
        POP     AX
        PUSH    AX
        PUSH    DX
        LEA     DX,FILE_
        DEC     AX
        DEC     AX
        JZ      PRINT_IO_ERROR_3
        LEA     DX,PATH_
        DEC     AX
        JNZ     PRINT_IO_ERROR_1
PRINT_IO_ERROR_3:
        CALL    WW_
        POP     DX
        JMP     SHORT   PRINT_IO_ERROR_4
PRINT_IO_ERROR_1:
        POP     DX
        LEA     DX,ERROR_
PRINT_IO_ERROR_4:
        CALL    WW_
        POP     AX
        LEA     DX,WRONG_NUMBER_OF_FUNCTION_
        DEC     AX
        JZ      PRINT_IO_ERROR_2
        LEA     DX,NOT_FOUND_
        DEC     AX
        JZ      PRINT_IO_ERROR_2
        DEC     AX
        JZ      PRINT_IO_ERROR_2
        LEA     DX,NO_MORE_DESCRIPTORS_
        DEC     AX
        JZ      PRINT_IO_ERROR_2
        LEA     DX,ACCESS_DENIED_
        DEC     AX
        JZ      PRINT_IO_ERROR_2
        LEA     DX,FILE_ERROR_
        PUSH    AX
PRINT_IO_ERROR_5:
        POP     AX
PRINT_IO_ERROR_2:
        CALL    WW_
        POP     DS
        POP     DX
        POP     AX
        RET
WW_     PROC
        PUSH    AX
        MOV     AH,09H
        INT     21H
        POP     AX
        RET
ENDP
FILE_   DB      'File $'
PATH_   DB      'Path to file $'
NOT_FOUND_      DB      ' not found',0dh,0ah,'$'
ERROR_  DB      'Error:$'

WRONG_NUMBER_OF_FUNCTION_       DB      'Wrong number of function',0dh,0ah,'$'
NO_MORE_DESCRIPTORS_    DB      'No more descriptors',0dh,0ah,'$'
ACCESS_DENIED_  DB      'Access denied',0dh,0ah,'$'
WRONG_DESCRIPTOR_       DB      'Wrong descriptors',0dh,0ah,'$'
NO_FILE_        DB      'Needed file is absent',0dh,0ah,'$'
EXE_FILE_       DB      'This is not COM-file',0dh,0ah,'$'
WRONG_LENGHT_   DB      'Wrong lenght of file',0dh,0ah,'$'
FILE_ERROR_     DB      'Unrecognized file error',0dh,0ah,'$'
ENDP
INCLUDE IO.LIB
ENDS
DATA    SEGMENT PARA
ENDS
BUF     SEGMENT PARA
ENDS
END     START