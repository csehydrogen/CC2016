/*------------------------------------------------------------------------------
  HEIG-Vd - CoE@SNU              Summer University              July 11-22, 2016

  The Art of Compiler Construction


  suPL scanner definition

*/


%%


%%
    

int main( int argc, char **argv )
{
  yyin = stdin;
  if (argc > 1) yyin = fopen(argv[1], "r");

  yylex();

  return 0;
}


