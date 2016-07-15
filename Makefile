lexer: 
	flex supl.lex
	gcc -o lexer lex.yy.c -lfl

test:
	./lexer test.su

clean:
	rm -f *.o *.sux lexer lex.yy.c
