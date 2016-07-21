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
  long int n;
  char     *str;
  IDlist   *idl;
  EType    t;
  EOpcode  opc;
  BPrecord *bpr;
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

%type<n>    number NUMBER call0 call1
%type<str>  ident IDENT string STRING
%type<idl>  vardecl vardecl0 fundecl0
%type<t>    type call
%type<opc>  condition
%type<bpr>  IF WHILE

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
| decll vardecl SEMICOLON { delete_idlist($vardecl); }
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
    $$ = $vardecl0;
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
    int narg = 0;
    IDlist *idl = $fundecl0;
    for(; idl; idl = idl->next, ++narg) {
      add_op(cb, opStore, find_symbol(symtab, idl->id, sLocal));
    }
    l->narg = narg;
    l->next = funcl;
    funcl = l;
    delete_idlist($fundecl0);
  }
  stmtblock
  {
    add_op(cb, opReturn, NULL);
    dump_codeblock(cb);
    save_codeblock(cb, fn_pfx);
    Stack *pstck = stack;
    stack = stack->uplink;
    delete_stack(pstck);
    Symtab *pst = symtab;
    symtab = symtab->parent;
  }
;

fundecl0: %empty { $$ = NULL; } | vardecl;

stmtblock:
  LBRACE
  {
    symtab = init_symtab(stack, symtab);
  }
  stmtblock0
  {
    Symtab *pst = symtab;
    symtab = symtab->parent;
  }
  RBRACE
;

stmtblock0: %empty | stmtblock0 stmt;

stmt:
  vardecl SEMICOLON
| assign SEMICOLON
| if
| while
| call SEMICOLON
  {
    if ($call != tVoid) {
      yyerror("Return value is not used.");
      YYABORT;
    }
  }
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
    add_op(cb, opStore, sym);
  }
;

if:
  IF LPAREN condition RPAREN
  {
    $IF = (BPrecord*)calloc(1, sizeof(BPrecord));
    Operation *tb = add_op(cb, $condition, NULL);
    Operation *fb = add_op(cb, opJump, NULL);
    $IF->ttrue = add_backpatch($IF->ttrue, tb);
    $IF->tfalse = add_backpatch($IF->tfalse, fb);
    pending_backpatch(cb, $IF->ttrue);
  }
  stmtblock
  {
    Operation *next = add_op(cb, opJump, NULL);
    $IF->end = add_backpatch($IF->end, next);
    pending_backpatch(cb, $IF->tfalse);
  }
  if0
  {
    pending_backpatch(cb, $IF->end);
  }
;

if0: %empty | ELSE stmtblock;

while:
  WHILE
  {
    $WHILE = (BPrecord*)calloc(1, sizeof(BPrecord));
    $WHILE->pos = cb->nops;
  }
  LPAREN condition RPAREN
  {
    Operation *tb = add_op(cb, $condition, NULL);
    Operation *fb = add_op(cb, opJump, NULL);
    $WHILE->ttrue = add_backpatch($WHILE->ttrue, tb);
    $WHILE->tfalse = add_backpatch($WHILE->tfalse, fb);
    pending_backpatch(cb, $WHILE->ttrue);
  }
  stmtblock
  {
    add_op(cb, opJump, get_op(cb, $WHILE->pos));
    pending_backpatch(cb, $WHILE->tfalse);
  }
;

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
      asprintf(&error, "The number of arguments(%ld) does not match with function declaration(%d).", $call0, l->narg);
      yyerror(error);
      free(error);
      YYABORT;
    }
    add_op(cb, opCall, $ident);
    $$ = l->rettype;
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
    add_op(cb, opReturn, NULL);
  }
| RETURN expression SEMICOLON
  {
    if (rettype == tVoid) {
      yyerror("Function must not have return value.");
      YYABORT;
    }
    add_op(cb, opReturn, NULL);
  }

read:
  READ ident SEMICOLON
  {
    Symbol *sym = find_symbol(symtab, $ident, sGlobal);
    if (sym == NULL) {
      char *error = NULL;
      asprintf(&error, "Unknown identifier '%s'.", $ident);
      yyerror(error);
      free(error);
      YYABORT;
    }
    add_op(cb, opRead, sym);
  }
;

write:
  WRITE expression SEMICOLON
  {
    add_op(cb, opWrite, NULL);
  }
;

print:
  PRINT string SEMICOLON
  {
    char *s, *d;
    for (s = d = $string + 1; *s != '"'; ++s, ++d) {
      if (*s == '\\') {
        switch (*++s) {
          case 't': *d = '\t'; break;
          case 'n': *d = '\n'; break;
          case '"': *d = '"'; break;
          case '\\': *d = '\\'; break;
        }
      } else {
        *d = *s;
      }
    }
    *d = 0;
    add_op(cb, opPrint, $string + 1);
  }
;

expression:
  number { add_op(cb, opPush, (void*)(long int)$number); }
| ident
  {
    Symbol *sym = find_symbol(symtab, $ident, sGlobal);
    if (sym == NULL) {
      char *error = NULL;
      asprintf(&error, "Unknown identifier '%s'.", $ident);
      yyerror(error);
      free(error);
      YYABORT;
    }
    add_op(cb, opLoad, sym);
  }
| expression ADD expression { add_op(cb, opAdd, NULL); }
| expression SUB expression { add_op(cb, opSub, NULL); }
| expression MUL expression { add_op(cb, opMul, NULL); }
| expression DIV expression { add_op(cb, opDiv, NULL); }
| expression MOD expression { add_op(cb, opMod, NULL); }
| expression EXP expression { add_op(cb, opPow, NULL); }
| LPAREN expression RPAREN
| call
  {
    if ($call == tVoid) {
      yyerror("The function has no return value.");
      YYABORT;
    }
  }
;

condition:
  expression CMPE expression  { $$ = opJeq; }
| expression CMPLE expression { $$ = opJle; }
| expression CMPL expression  { $$ = opJlt; }
//| expression CMPGE expression
//| expression CMPG expression
//| condition AND condition
//| condition OR condition
//| LPAREN condition RPAREN
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

