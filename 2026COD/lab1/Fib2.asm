	addi x2, x0, 66
	add  x5, x0, x0
	addi x6, x0, 1
	add  x7, x0, x0
	addi x8, x0, 1
	add  x9, x0, x0
	addi x10, x0, 1
	addi x2, x2, -2
	bge  x0, x2, done

loop: 	beq  x0, x2, done
	add  x10, x8, x6
	sltu x11, x10, x6
	add  x9, x5, x11
	add  x9, x9, x7
	add  x5, x7, x0
	add  x6, x8, x0
	add  x7, x9, x0
	add  x8, x10, x0
	addi x2, x2, -1
	beq  x0, x0, loop 
	
done:	add  x3, x9, x0
	add  x4, x10, x0
