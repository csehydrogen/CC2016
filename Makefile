lexer: supl.lex
	flex supl.lex
	gcc -o lexer lex.yy.c -ll

test:
	./lexer test.su

clean:
	rm -f *.o *.sux lexer lex.yy.c
