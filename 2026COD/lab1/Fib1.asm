	addi x5, x0, 1
	addi x6, x0, 1
	addi x7, x0, 1
	addi x2, x2, -2
	bge  x0, x2, done

loop: 	beq  x0, x2, done
	add  x7, x5, x6
	add  x5, x6, x0
	add  x6, x7, x0
	addi x2, x2, -1
	beq  x0, x0, loop 
	
done:	add  x3, x7, x0
