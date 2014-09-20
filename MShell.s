# Identificadores de las funciones de sistema
		print_char  = 11             # print [args]
		read_char   = 12             # Not callable
		get_version = 90             # version
		get_time    = 91             # time
		wait_time   = 92             # wait
		print_str   = 93             # Implementar
		
# Hash de las funciones implementadas #
        print_char_hash  = 441
		get_version_hash = 448
		get_time_hash    = 431
		wait_time_hash   = 437
		
# segmento de datos

		.data	
retorn:	.word 0
bondia:	.asciiz "MIPSOS v."
la_hora:	.asciiz " segundos\n"
prompt:     .asciiz "test:mipsos:~# "
promptR:    .asciiz "Response >>  "
notCmd:     .asciiz " ~ Command not identified ~"
buffer_int: .ascii "          " # No tocar. Buffer de printf_integer
command:    .space 300          # Longitud máxima de la orden
# Para hacer simple el parser, mínima longitud de orden 4, 
#con el valor de las cmdLength primeras letras se genera un 
#valor hash simple (suma de ascii) correspondiente a la orden introducida
cmdLength:  .word 4             
buffer_aux: .space 300
## Para reducir colisiones usar una mejor función de dispersión ##
    

#-------------------------------------------------#

# Segmento de código ("text")
	.text
    	.globl main	

main:
# Guarda adreça de retorn
	sw $ra,retorn

# Saluda y da el número de versión
	la $a0,bondia
	jal print_string
	li $v0,get_version
	syscall
	move $a0,$v0
	jal printf_integer
	jal print_NL
	li $s0,0

# Main Loop #
bucle:
	# Prompt de petición #
	la $a0,prompt
	jal print_string
	# Dice la hora # {li $v0,get_time,syscall,move $a0,$v0, jal printf_integer,la $a0,la_hora,jal print_string}	
	# Espera 5 segundos {#li $a0,5,#li $v0,wait_time,#syscall}
	# Read command #
	jal read_string
	jal print_NL
	# Imprimir el prompt de respuesta #
	la $a0,promptR
	jal print_string
	# Parse & Execute #
	la $a0,command
	jal parse_command   # Parsea command y lanza la syscall correspondiente
	jal print_NL
	b bucle

# Shutdown
#	lw $ra,retorn
#	jr $ra


#-------------------------------------------------

print_string: # $a0: puntero a string acabado en \0
	move $t0,$a0
	lb $a0,0($t0)
	beq $a0,$zero,$L4
$L3:	li $v0,print_char 
	syscall
	addiu $t0,$t0,1
	lb $a0,0($t0)
	bne $a0,$zero,$L3
$L4:	jr $ra

#-------------------------------------------------

read_string: 
			 # Read char #
			 li $a1,298   # Contador para bytes de la cadena
			 li $t0,'\n' 
			 la $a2,command
$LS:	     li $v0,read_char   # Leer caracter
             syscall
			 or $a0,$zero,$v0
			 li $v0,print_char  # Imprimir caracter para retroalimentación
			 syscall
			 move $v0,$a0
			 sb $v0,0($a2)      # Guardar el caracter en el buffer de command
			 addiu $a2,$a2,1    # Avanzar puntero a command
             beq $v0,$t0,$LE    # Si se detecta un fin de linea fin de la orden
			 beqz $v0,$LE       # Si es un null byte fin de la orden
			 beqz $a1,$LE       # Si la cadena es de longitud máxima fin de la orden
			 addiu $a1,$a1,-1   # Decrementar contador de longitud
			 b $LS
$LE: 	     sb $zero,0($a2)	# Añadir null byte a la cadena
             jr $ra             # Retornar
             
#-------------------------------------------------

print_NL:	# sense paràmetres: escriu NL (New Line)
	li $a0,'\n'
	li $v0,print_char 
	syscall
	jr $ra

#-------------------------------------------------

printf_integer: # $a0: valor entero
    move $t0,$a0		# dividendo inicial
	li $t1,0          	# cuenta de cifras
	li $t2,10         	# divisor

$L1:	# bucle de cambio de base
	divu $t0,$t2		# división entre 10
	mfhi $t3          	# tomo el resto
	addiu $t3,$t3,'0' 	# calculo código ascii
	sb $t3,buffer_int($t1)	# guardo en buffer
	addi $t1,$t1,1		# avanzo puntero
	mflo $t0			# nou dividendo
	bne $t0,$zero,$L1

$L2:	# bucle de escritura
	addiu $t1,$t1,-1		# retrocedo en buffer
	lb $a0,buffer_int($t1)	# tomo carácter
	li $v0,print_char		# escribo carácter
	syscall			        # llamada
	bne $t1,$zero,$L2	
	li $v0,print_char 
	jr $ra

#-------------------------------------------------
extract_n_command: # $a0: dirección de command, [$a1: parámetro número n] ( para tests únicamente funciones de aridad 1, no se usa el 2º parámetro )
                   li $t0,' ' # Constante ' '
				   li $t2,300  # Constante: máxima longitud del command (contador)"
				   la $t3,buffer_aux # Dirección del buffer auxiliar que provee el SO para funciones tipo print char, get char etc #
				   li $s0,'\n'       # Constante: fin de linea
$LN:               lb $t1,0($a0) # Cargar byte del command #
                   beq $t1,$t0,$GP # Si es un espacio, se supone que lo siguiente es un parámetro #
				   addiu $a0,$a0,1  # Si no se encuentra, avanzar el puntero de $a0 hasta encontrar 
				   # uno o hasta alcanzar la longitud máxima del comando #
				   addiu $t2,$t2,-1 # Decrementar el contador
				   beqz $t2,$LN
$GP:               ## Si el puntero se encuentra sobre un espacio, avanzar hasta 
				   ##el salto de linea, almacenando los valores del parametro en una variable ##
				   lb $t1,0($a0)    # Cargar el valor del caracter actual (parte del param)
				   sb $t1,0($t3)    # Almacenar en el buffer auxiliar
				   addiu $a0,$a0,1  # Avanzar puntero del string command
				   addiu $t3,$t3,1  # Avanzar puntero al buffer auxiliar
				   bne $t1,$s0,$GP  #
				   ## Cuando ya se haya alcanzado el fin de linea ##
				   sb $zero,0($t3)  # "Cerrar" el buffer auxiliar añadiendo null byte eof
				   la $v0,buffer_aux # Cargar dirección inicial del buffer auxiliar
				   lb $v0,0($v0)
				   jr $ra
				                  

clear_buffer: la $a0,buffer_aux
			  li $t0,300
$LB:          sb $zero,0($a0)
			  addiu $a0,$a0,1
			  addiu $t0,$t0,-1
			  bnez $t0,$LB
			  jr $ra
## Parser ##
parse_command: # $a0: command string address
				 ## Salvar contexto en la pila, para subllamadas ##
				 addiu $sp,$sp,-4
				 sw $ra,0($sp)
				 la $t1,cmdLength
				 lw $t1,0($t1) # Cargar longitud máxima de orden (contador)
				 li $t2,0      # Hash inicial
$LP:             lb $t3,0($a0)
                 addu $t2,$t2,$t3 # Sumar al hash
				 addiu $t1,$t1,-1  # Decrementar contador
				 addiu $a0,$a0,1   # Avanzar puntero orden
				 bnez $t1,$LP
				 ## Ya se han sumado los 4 primeros caracteres             ##
				 ## Salvar en $v0, el identificador de syscall de la orden ##
$CPC: 			 li $a0,print_char_hash
				 bne $t2,$a0,$CGV
				 #la $a0,command
				 #jal extract_n_command
				 #move $a0,$v0
				 syscall
                 j $LPE			 
$CGV:			 li $a0,get_version_hash
				 bne $t2,$a0,$CGT			 
				 li $v0,90
				 syscall
				 move $a0,$v0
				 jal printf_integer
				 j $LPE
$CGT:            li $a0,get_time_hash
				 bne $t2,$a0,$CWT
				 li $v0,91
				 syscall
				 move $a0,$v0
				 jal printf_integer
				 la $a0,la_hora
				 jal print_string
				 j $LPE
$CWT:            li $a0,wait_time_hash
				 bne $t2,$a0,$NOT
				 li $a0,5    # Espera los segundos que introduzca el usuario como parametro en el ejemplo 5 segundos #
				 li $v0,92
				 syscall
				 j $LPE
$NOT:            la $a0,notCmd
				 jal print_string
$LPE:            ## Limpiar buffers    ##
				 jal clear_buffer
				 ## Restaurar Contexto ##
				 lw $ra,0($sp)
				 addiu $sp,$sp,4	 
				 jr $ra
               

			 