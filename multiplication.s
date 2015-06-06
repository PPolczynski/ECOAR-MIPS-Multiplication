		.data
n64l:		.word		0			#input 64 bit low
n64:		.word		0			#input 64 bit high
n32:		.word		0,0			#input 32 bit
outl:		.word		0			#output 64 bit low
out:		.word		0			#output 64 bit high


prompt64:	.asciiz		"\nInput 64bit number: "
prompt32:	.asciiz		"Input 32 bit number: "
output:		.asciiz		"result of multiplication: "
outfpu:		.asciiz		"\nFPU check: "
prompt: 	.asciiz		 "\nDo You want to continue? [Y\\N]:\n"
answ:	 	.space 		2



		.text
		.globl		main

main:		la		$a0, prompt64		
		li		$v0, 4
		syscall					#ask for first number(64bit)
		
		li		$v0, 7
		syscall					#read first number
		sdc1		$f0, n64l

		la		$a0, prompt32
		li		$v0, 4
		syscall					#ask for 2nd number(32bit)
		
		li		$v0, 6
		syscall					#read second number
		swc1		$f0, n32	



################Sign Manipulation################
		xor		$t0, $t0, $t0		#zeroing temp registers
		xor		$t1, $t1, $t1
		xor		$t2, $t2, $t2
		xor		$t3, $t3, $t3
		xor		$t4, $t4, $t4

		lw		$t1, n64		#load 
		andi		$t3, $t1, 0x7FFFFFFF	#masks everything but sign to check if number is all zeros 
		bne		$t3, 0, setsign		#if not equal 0 go to set sign
		lw		$t4, n64l		#higher part was all zeroes loading lower to check it
		beq		$t4, 0, zero		# if lower eq zero then this is multiplication by 0 
		beq		$t4,0x7FF00000,overfl 	#if infinity do nothing
setsign:		
		srl		$t1, $t1, 31		#leaves just sign bit of 64 bit
		lw		$t2, n32		#loads 2nd number
		andi		$t3, $t2, 0x7FFFFFFF	#again masking to check for zero
		beq		$t3, 0, zero		#check if 2nd number is not zero
		beq		$t4,0x7FF00000,overfl 	#if infinity do nothing
		srl		$t2, $t2, 31		#leaves just sign bit of 32 bit
		xor		$t0, $t1, $t2		#$t0 now contains the sign
		sll		$t0, $t0, 31		#moves bits to more conviniet place

################Exponent inital caluclation################
		xor		$t3, $t3, $t3
		xor		$t2, $t2, $t2

		lw		$t3, n64
		lw		$t2, n32
		
		sll		$t3, $t3, 1		#shifting out sign bits
		sll		$t2, $t2, 1		#
		
		srl		$t3, $t3, 21		#shifting out mantissa bits
		srl		$t2, $t2, 24		#
		
		subu		$t2, $t2, 127		#adding bias
		addu		$t3, $t3, $t2		#$t3 contains exponent	
		

################mantissa################
		lw		$t1, n64		#64bit number higher
		lw		$t6, n64l		#64bit number lower
		lw		$t2, n32		#32bit number
		xor 		$t4,$t4,$t4
		xor 		$t8,$t8,$t8
		xor 		$t9,$t9,$t9
		
	
		sll		$t1, $t1, 12		#shifting out sign and exponent
		sll		$t2, $t2, 9	
		
		srl		$t1, $t1, 9		#moving it back, for easy highest bit store
		srl		$t2, $t2, 9
		srl		$t6, $t6, 29
		ori		$t1, $t1, 0x00800000	#adding explicit 1 from 1.m
		or		$t1, $t1, $t6		#adding mantissa bits from lower register
		ori		$t2, $t2, 0x00800000	
	
		lw		$t6, n64l
		sll		$t6, $t6, 3

		multu 		$t1,$t2			#multiplies high part
		mfhi 		$t9
		mflo		$t8
		
		multu		$t6,$t2 		#multiplies lower part
		mfhi 		$t4


		
		xor		$t7,$t7,$t7
		addu		$t7,$t7,$t8

		addu		$t8,$t8,$t4
		slt		$t7, $t8, $t7		#sums two multiplicatuibs abd checks if overflow occures
		
		addu		$t9,$t9,$t7		#adds carry from lower part if exists

		srl		$t7,$t9,15		# checks if incresment in exponent is needed
		beq		$t7,1,incex		
		
normal:		xor $t9,$t9,0x00004000			#if there is no need to adjust mantiasa
		sll $t9,$t9,6				# shifts exponents to feet result into proper bits pf fp 
		srl $t7,$t8,26
		or  $t9,$t9,$t7
		sll $t8,$t8,6
		mflo	$t7
		srl	$t7,$t7,26
		or	$t8,$t8,$t7
		b combine
		

	
		
incex:		addu $t3, $t3, 1			#if there is need to adjust mantiasa
		xor  $t9, $t9 ,0x00008000
		sll $t9,$t9,5
		srl $t7,$t8,27
		or  $t9,$t9,$t7
		sll $t8,$t8,5
		mflo	$t7
		srl	$t7,$t7,27
		or	$t8,$t8,$t7
		b combine 	


################result preperation################
combine:
		bgt		$t3, 2046, overfl		#checks for overflow
		blt		$t3, 1, zero			#checks for underflow
		
		sll		$t3, $t3, 20			#combining the number
		or		$t0, $t0, $t3			
		or		$t0, $t0, $t9
				
		b		resultStore	


zero:			
		andi		$t0, $t0, 0x00000000	#setting bits for zero
		andi		$t5, $t5, 0x00000000	#setting bits for zero
	
		b		resultStore

overfl:		andi		$t0, $t0, 0x00000000
		ori		$t0,$t0, 0x7FF00000	#setting bits to signal infinity
		andi		$t5,$t5, 0x00000000		

		
resultStore:		
		sw		$t0, out
		sw		$t5, outl

		
		
		la		$a0, output		
		li		$v0, 4
		syscall					#prints output	
	
		l.d		$f12, outl
		li		$v0, 3
		syscall

################FPU check################
	
		l.d		$f2, n64l
		l.s		$f4, n32
		cvt.d.s		$f4, $f4
		mul.d		$f12, $f2, $f4

		la		$a0, outfpu
		li		$v0, 4
		syscall					#print outfpu	
		
		li		$v0, 3
		syscall					#FPU check displey


###############end	
		la		$a0, prompt
		li 		$v0, 4
		syscall

		la 		$a0, answ
		li 		$a1, 2
		li 		$v0, 8
		syscall
		
		la		$t0, answ
		lbu		$t0,($t0)
		beq		$t0,'Y', main
		beq		$t0,'y', main		
		
		li		$v0, 10
		syscall				
