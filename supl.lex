/*------------------------------------------------------------------------------
  HEIG-Vd - CoE@SNU              Summer University              July 11-22, 2016

  The Art of Compiler Construction

  suPL scanner definition
 */

%%

";"	printf("tSemi(%s)\n", yytext);
","	printf("tComma(%s)\n", yytext);
"int"	printf("tInt(%s)\n", yytext);
"void"	printf("tVoid(%s)\n", yytext);
"("	printf("tLParen(%s)\n", yytext);
")"	printf("tRParen(%s)\n", yytext);
"{"	printf("tLBrace(%s)\n", yytext);
"}"	printf("tRBrace(%s)\n", yytext);
"="	printf("tAssign(%s)\n", yytext);
"if"	printf("tIf(%s)\n", yytext);
"else"	printf("tElse(%s)\n", yytext);
"while"	printf("tWhile(%s)\n", yytext);
"read"	printf("tRead(%s)\n", yytext);
"write"	printf("tWrite(%s)\n", yytext);
"print"	printf("tPrint(%s)\n", yytext);
"+"	printf("tPlus(%s)\n", yytext);
"-"	printf("tMinus(%s)\n", yytext);
"*"	printf("tMul(%s)\n", yytext);
"/"	printf("tDiv(%s)\n", yytext);
"%"	printf("tMod(%s)\n", yytext);
"^"	printf("tExp(%s)\n", yytext);
"=="	printf("tE(%s)\n", yytext);
"<="	printf("tLE(%s)\n", yytext);
"<"	printf("tL(%s)\n", yytext);
">"	printf("tG(%s)\n", yytext);
[[:digit:]]+	printf("tNumber(%s)\n", yytext);
[[:alpha:]][[:alnum:]]*	printf("tIdent(%s)\n", yytext);
"\""([[:print:]]{-}["\\]|"\\t"|"\\n"|"\\\""|"\\\\")*"\""	printf("tString(%s)\n", yytext);
[[:space:]]+	/* space */
.	printf("tUndefined(%s)\n", yytext);

%%

int main( int argc, char **argv )
{
	yyin = stdin;
	if (argc > 1) yyin = fopen(argv[1], "r");

	yylex();

	return 0;
}
