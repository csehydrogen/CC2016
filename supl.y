/*------------------------------------------------------------------------------
  HEIG-Vd - CoE@SNU              Summer University              July 11-22, 2016

  The Art of Compiler Construction


  suPL parser definition

*/

%locations

%code top {
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define YYDEBUG 1

extern char *yytext;
extern int yylex();
int yyerror(const char *msg);
}

%code requires {
#include "supllib.h"
}

%union {
  int n;
  char     *str;
  IDlist   *idl;
  EType    t;
}

%code {
  Stack   *stack = NULL;
  Symtab *symtab = NULL;
  CodeBlock *cb  = NULL;

  char *fn_pfx   = NULL;
  EType rettype  = tVoid;
  Funclist *funcl = NULL;
}

%start program

%token INTEGER VOID
%token IF ELSE WHILE RETURN
%token READ WRITE PRINT
%token SEMICOLON LPAREN RPAREN LBRACE RBRACE
%token NUMBER IDENT STRING

%left COMMA
%right ASSIGN
%left OR
%left AND
%left CMPE
%left CMPLE CMPL CMPGE CMPG
%left ADD SUB
%left MUL DIV MOD
%right EXP

%type<n>    number NUMBER vardecl fundecl0 call0 call1
%type<str>  ident IDENT string STRING
%type<idl>  vardecl0
%type<t>    type

%%

program:
  {
    stack = init_stack(NULL);
    symtab = init_symtab(stack, NULL);
  }
  decll
  {
    cb = init_codeblock("");
    stack = init_stack(stack);
    symtab = init_symtab(stack, symtab);
    rettype = tVoid;
  }
  stmtblock
  {
    add_op(cb, opHalt, NULL);
    dump_codeblock(cb);
    save_codeblock(cb, fn_pfx);
    Stack *pstck = stack;
    stack = stack->uplink;
    delete_stack(pstck);
    Symtab *pst = symtab;
    symtab = symtab->parent;
    delete_symtab(pst);
  };

decll:
  %empty
| decll vardecl SEMICOLON
| decll fundecl
;

vardecl:
  type
  vardecl0
  {
    if ($type == tVoid) {
      yyerror("Variable cannot be declared as type 'void'.");
      YYABORT;
    }
    IDlist *l = $vardecl0;
    int narg = 0;
    for (; l; ++narg) {
      if (insert_symbol(symtab, l->id, $type) == NULL) {
        char *error = NULL;
        asprintf(&error, "Duplicated variable identifier '%s'.", l->id);
        yyerror(error);
        free(error);
        YYABORT;
      }
      l = l->next;
    }
    delete_idlist($vardecl0);
    $$ = narg;
  }
;

vardecl0:
  ident
  {
    $$ = (IDlist*)calloc(1, sizeof(IDlist));
    $$->id = $ident;
  }
| vardecl0 COMMA ident
  {
    $$ = (IDlist*)calloc(1, sizeof(IDlist));
    $$->id = $ident;
    $$->next = $1;
  }
;

type:
  INTEGER { $$ = tInteger; }
| VOID    { $$ = tVoid; }
;

fundecl:
  type ident
  {
    if (find_func(funcl, $ident) != NULL) {
      char *error = NULL;
      asprintf(&error, "Duplicated function identifier '%s'.", $ident);
      yyerror(error);
      free(error);
      YYABORT;
    }
    cb = init_codeblock($ident);
    stack = init_stack(stack);
    symtab = init_symtab(stack, symtab);
    rettype = $type;
  }
  LPAREN fundecl0 RPAREN
  {
    Funclist *l = (Funclist*)calloc(1, sizeof(Funclist));
    l->id = $ident;
    l->rettype = $type;
    l->narg = $fundecl0;
    l->next = funcl;
    funcl = l;
  }
  stmtblock
  {
    dump_codeblock(cb);
    save_codeblock(cb, fn_pfx);
    Stack *pstck = stack;
    stack = stack->uplink;
    delete_stack(pstck);
    Symtab *pst = symtab;
    symtab = symtab->parent;
    delete_symtab(pst);
  }
;

fundecl0: %empty { $$ = 0; } | vardecl;

stmtblock:
  LBRACE
  {
    symtab = init_symtab(stack, symtab);
  }
  stmtblock0
  {
    Symtab *pst = symtab;
    symtab = symtab->parent;
    delete_symtab(pst);
  }
  RBRACE;

stmtblock0: %empty | stmtblock0 stmt;

stmt:
  vardecl SEMICOLON
| assign SEMICOLON
| if
| while
| call SEMICOLON
| return
| read
| write
| print
;

assign: ident ASSIGN expression
  {
    Symbol *sym = find_symbol(symtab, $ident, sGlobal);
    if (sym == NULL) {
      char *error = NULL;
      asprintf(&error, "Unknown identifier '%s'.", $ident);
      yyerror(error);
      free(error);
      YYABORT;
    }
  }
;

if: IF LPAREN condition RPAREN stmtblock if0;

if0: %empty | ELSE stmtblock;

while: WHILE LPAREN condition RPAREN stmtblock;

call:
  ident LPAREN call0 RPAREN
  {
    Funclist *l = find_func(funcl, $ident);
    if (l == NULL) {
      char *error = NULL;
      asprintf(&error, "Function '%s' does not exist.", $ident);
      yyerror(error);
      free(error);
      YYABORT;
    }
    if (l->narg != $call0) {
      char *error = NULL;
      asprintf(&error, "The number of arguments(%d) does not match with function declaration(%d).", $call0, l->narg);
      yyerror(error);
      free(error);
      YYABORT;
    }
  }
;

call0: %empty { $$ = 0; } | call1;

call1:
  expression { $$ = 1; }
| call1 COMMA expression { $$ = $1 + 1; }
;

return:
  RETURN SEMICOLON
  {
    if (rettype != tVoid) {
      yyerror("Return value is expected.");
      YYABORT;
    }
  }
| RETURN expression SEMICOLON
  {
    if (rettype == tVoid) {
      yyerror("Function must not have return value.");
      YYABORT;
    }
  }

read: READ ident SEMICOLON;

write: WRITE expression SEMICOLON;

print: PRINT string SEMICOLON;

expression:
  number
| ident
| expression ADD expression
| expression SUB expression
| expression MUL expression
| expression DIV expression
| expression MOD expression
| expression EXP expression
| LPAREN expression RPAREN
| call
;

condition:
  expression CMPE expression
| expression CMPLE expression
| expression CMPL expression
| expression CMPGE expression
| expression CMPG expression
| condition AND condition
| condition OR condition
| LPAREN condition RPAREN
;

number: NUMBER;

ident: IDENT;

string: STRING;

%%

int main(int argc, char *argv[])
{
  extern FILE *yyin;
  argv++; argc--;

  while (argc > 0) {
    // prepare filename prefix (cut off extension)
    fn_pfx = strdup(argv[0]);
    char *dot = strrchr(fn_pfx, '.');
    if (dot != NULL) *dot = '\0';

    // open source file
    yyin = fopen(argv[0], "r");
    yydebug = 0;

    // parse
    yyparse();

    // next input
    free(fn_pfx);
    argv++; argc--;
  }

  return 0;
}

int yyerror(const char *msg)
{
  printf("Parse error at %d:%d: %s\n", yylloc.first_line, yylloc.first_column, msg);
  return 0;
}

