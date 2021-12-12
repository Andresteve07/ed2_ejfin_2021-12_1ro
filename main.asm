; TODO INSERT CONFIG CODE HERE USING CONFIG BITS GENERATOR
LIST P=16F887
    #INCLUDE "p16f887.inc"
RES_VECT  CODE    0x0000            ; processor reset vector
    GOTO    MAIN                   ; go to beginning of program

; TODO ADD INTERRUPTS HERE IF USED
    ORG 0x04
	GOTO RUTINA_INTERR;
REGRE_60 EQU 0x20
ROT_2BITS EQU 0x21
CORTAR_UART EQU 0x22
 
TABLA_CANAL:
    ADDWF PCL, F;
    ;ADCON0 [K K C C C C GO ENC]
    ;[0 0 1 0 1 0 0 0] 10
    ;[0 0 1 0 1 1 0 0] 11
    ;[0 0 1 1 0 0 0 0] 12
    ;[0 0 1 1 0 1 0 0] 13
    RETLW B'00101000';
    RETLW B'00101100';
    RETLW B'00110000';
    RETLW B'00110100';
    
MEDIR_SENSOR:
    ;decidir proximo canal medir
    INCF ROT_2BITS; incrementa el contador para ir rotando de canal
    MOVFW ADCON0;
    ANDLW B'11000011'; pongo 0 todos los bits de canal del adcon0 para poder sobreescribir con los valores de la tabla
    MOVWF ADCON0_MASK; guardo lo obtenido en la variable para conservar el clock y go y enc.
    MOVFW ROT_2BITS; 
    ANDLW B'00000011'; hace mascara de los bits menos significativos para que solo rote entre 0 y 3 
    CALL TABLA_CANAL;
    IORWF ADCON0_MASK,0;uso el valor de la tabla para seleccionar el proximo canal.
    MOVWF ADCON0;
    
    ;una vez que cambio el canal tengo que esperar un tiempo minimo de ...ms
    CALL ESPERA_XXUS;
    
    ;arranco la medicion del adc en el canal que esta configurado actualmente
    BSF ADCON0, GO;
    RETURN;
    
PASARON_2SEG:
    MOVLW 0x0B;
    MOVWF TMR1H;
    MOVLW 0xDC;
    MOVWF TMR1L;
    BCF PIR1, TMR1F;bajo bandera de interr del tmr1
    
    DECFSZ REGRE_60;
    RETURN;
    CALL MEDIR_SENSOR;
    MOVLW .60;
    MOVWF REGRE_60;recargar el contador
    RETURN;
    
    
ENVIAR_PROX_8BITS:
    ;0xF0 [1 1 1 1 0 0 0 0]
    ;0x01 [0 0 0 0 0 0 0 1] XOR
    ;0xF1 [1 1 1 1 0 0 0 1]
    BCF PIR1, TXIF;
    BTFSC CORTAR_UART,1;
    RETURN
    MOVFW INDF;
    MOVWF TXREG;cuando se carga este reg inmediamente inicia la transmision
    MOVFW FSR; Hago el toggle del primer bit para cambiar el registro
    XORLW .1;
    MOVWF FSR;actualizo el puntero para la proxima
    INCF CORTAR_UART;
    RETURN
    
CONVERSION_DISPONIBLE:
    MOVFW ADRESH;
    MOVWF 0xF1;
    MOVFW ADRESL;
    MOVWF 0xF0;
    
    ;[1 1 \ 1 1 1 1 1 1 1 1] 100%
    ;[1 0 \ 1 1 1 1 1 1 1 1] 75%
    ;[0 1 \ 1 1 1 1 1 1 1 1] 50%
    ;[0 0 \ 1 1 1 1 1 1 1 1] 25%
    ;[0 0 \ 0 0 0 0 0 0 0 0] 0%
     ;solo en 10 RANGO PERMITIDO
     CLRF CORTAR_UART;
     
     BTFSS ADRESH,1;
     CALL ENVIAR_PROX_8BITS;
     BTFSC ADRESH,0;
     CALL ENVIAR_PROX_8BITS;
    
     ;Alternativa con resta
     ;MOVFW ADRESH;
     ;SUBLW B'00000010';
     ;BTFSC STATUS, Z;
     ;CALL ENVIAR_8BITS;
     
     BCF PIR1, ADIF;
    
    RETURN;
    
RUTINA_INTERRUP:
    ;salvar contexto
    
    BTFSC PIR1, TMR1F;pregunta si salto el tmr1 osea pasaron 2 segs
    CALL PASARON_2SEG;
    BTFSC PIR1, ADIF;SALTO EL ADC?
    CALL CONVERSION_DISPONIBLE;
    BTFSC PIR1, TXIF;terminó la transmision de 8bits
    CALL ENVIAR_PROX_8BITS;
    
    ;rescuperar contexto
    RETFIE;
    
CONFIG:
    MOVLW .60;
    MOVWF REGRE_60;
    CLRF ROT_2BITS;
    CLRF CORTAR_UART;
    
    CALL CONFIG_TMR1;
    CALL CONFIG_ADC;
    CALL CONFIG_UART;
    RETURN
MAIN_PROG CODE                      ; let linker place main program
 

MAIN
 CALL CONFIG;
BUCLE
    GOTO BUCLE                          ; loop forever

    END