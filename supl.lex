/*------------------------------------------------------------------------------
  HEIG-Vd - CoE@SNU              Summer University              July 11-22, 2016

  The Art of Compiler Construction


  suPL scanner definition

*/

%option yylineno

%{
#include "supl.tab.h"       // token definitions and yylval - generated by bison

int yycolumn = 1;

#define YY_USER_ACTION {                            \
  yylloc.first_line = yylloc.last_line = yylineno;  \
  yylloc.first_column = yycolumn;                   \
  yylloc.last_column = yycolumn + yyleng - 1;       \
  yycolumn += yyleng;                               \
}
%}

%%

"int"     { return INTEGER; }
"void"    { return VOID; }
"if"      { return IF; }
"else"    { return ELSE; }
"while"   { return WHILE; }
"return"  { return RETURN; }
"read"    { return READ; }
"write"   { return WRITE; }
"print"   { return PRINT; }
";"       { return SEMICOLON; }
","       { return COMMA; }
"("       { return LPAREN; }
")"       { return RPAREN; }
"{"       { return LBRACE; }
"}"       { return RBRACE; }
"="       { return ASSIGN; }
"+"       { return ADD; }
"-"       { return SUB; }
"*"       { return MUL; }
"/"       { return DIV; }
"%"       { return MOD; }
"^"       { return EXP; }
"=="      { return CMPE; }
"<="      { return CMPLE; }
"<"       { return CMPL; }
">="      { return CMPGE; }
">"       { return CMPG; }
"&&"      { return AND; }
"||"      { return OR; }
[[:digit:]]+  { yylval.n = atoi(yytext); return NUMBER; }
[[:alpha:]][_[:alnum:]]* { yylval.str = strdup(yytext); return IDENT; }
"\""([\x1B[:print:]]{-}["\\]|"\\t"|"\\n"|"\\\""|"\\\\")*"\"" { yylval.str = strdup(yytext); return STRING; }
[ \t]+  /* ignore whitespace */
[\n]+   { yycolumn = 1; }
.       { printf("undefined: %c\n", yytext[0]); } /* undefined */

%%
