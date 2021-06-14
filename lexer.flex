/*
 *  The scanner definition for COOL.
 */

/*
 *  Stuff enclosed in %{ %} in the first section is copied verbatim to the
 *  output, so headers and global definitions are placed here to be visible
 * to the code in the file.  Don't remove anything that was here initially
 */
%{
#include <cool-parse.h>
#include <stringtab.h>
#include <utilities.h>
#include <stdlib.h>


/* The compiler assumes these identifiers. */
#define yylval cool_yylval
#define yylex  cool_yylex

/* Max size of string constants */
#define MAX_STR_CONST 1025
#define YY_NO_UNPUT   /* keep g++ happy */

extern FILE *fin; /* we read from this file */

/* define YY_INPUT so we read from the FILE fin:
 * This change makes it possible to use this scanner in
 * the Cool compiler.
 */
#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
	if ( (result = fread( (char*)buf, sizeof(char), max_size, fin)) < 0) \
		YY_FATAL_ERROR( "read() in flex scanner failed");

char string_buf[MAX_STR_CONST]; /* to assemble string constants */
char *string_buf_ptr;

extern int curr_lineno;
extern int verbose_flag;

extern YYSTYPE cool_yylval;

/*
 *  Add Your own definitions here
 */

int counter;
void print_string();
void print_string_length();
bool check_string_length(void);

%}

%x STRING
%x INV_STRING
%x COMMENT
%x NN_COMMENT


/*
 * Define names for regular expressions here.
 */

DIGIT		[0-9]
ALPHABET	[a-zA-Z]
NEW_LINE	(\r\n|\n)
WHITE_SPACE	[ \t\v\f\r]*
DASH_COMMENT	--.*\n
OPERATORS	("+"|"-"|"*"|\/)
SINGLE_CHARACTER_OPERATORS	("~"|"<"|"="|"("|")"|"{"|"}"|";"|":"|"."|","|"@")

TRUE		(t)(?i:rue)
FALSE		(f)(?i:alse)

CLASS		(?i:class)
ELSE		(?i:else)
IF		(?i:if)
FI		(?i:fi)
IN		(?i:in)
INHERITS	(?i:inherits)
LET		(?i:let)
LOOP		(?i:loop)
POOL		(?i:pool)
WHILE		(?i:while)
THEN		(?i:then)
CASE		(?i:case)
ESAC		(?i:esac)
OF		(?i:of)
NEW		(?i:new)
ISVOID		(?i:isvoid)
NOT		(?i:not)

INT_CONST   {DIGIT}+
TYPEID      ([A-Z]({DIGIT}|{ALPHABET}|"_")*)
OBJECTID    ([a-z]({DIGIT}|{ALPHABET}|"_")*)

DARROW      "=>"
LE          "<="
ASSIGN      "<-"


%%


"."		{ return '.'; }
","         	{ return ','; }
"="         	{ return '='; }
"~"         	{ return '~'; }
"<"         	{ return '<'; }
"@"         	{ return '@'; }
"+"         	{ return '+'; }
"-"         	{ return '-'; }
"*"         	{ return '*'; }
"/"         	{ return '/'; }
"("         	{ return '('; }
")"         	{ return ')'; }
"}"         	{ return '}'; }
"{"         	{ return '{'; }
":"		{ return ':'; }
";"         	{ return ';'; }




 /*
  *  Nested comments
  */


"*)"		{
		     	cool_yylval.error_msg = "Unmatched *)";
		     	return ERROR;
 		}

"(*" 		{
			++counter;
     			BEGIN(COMMENT);
 		}

<COMMENT>"("+		{ }

<COMMENT>"*"+		{ }

<COMMENT>"("+"*"	{
				counter++;
			}

<COMMENT>"*"+")"	{
				counter--;
				if (counter == 0)
					BEGIN(INITIAL);
			}

<COMMENT>{NEW_LINE} 	{ 
				curr_lineno++; 
 			}

<COMMENT>\\\n		{
				++curr_lineno;
			}

<COMMENT>[^*(\n]*

<COMMENT><<EOF>> 	{
				BEGIN(INITIAL);
			    	cool_yylval.error_msg = "EOF in comment";
			    	return ERROR;
			}

<COMMENT>. 		{ }



"--"    BEGIN(NN_COMMENT);

<NN_COMMENT>[^\n]*

<NN_COMMENT>{NEW_LINE}		{
					curr_lineno++;
					BEGIN(INITIAL);
				}

<NN_COMMENT><<EOF>>		{
					BEGIN(EOF);
				}



"--".*			;

{DASH_COMMENT}		{ 
				curr_lineno++; 
			}



 /*
  *  The multiple-character operators.
  */


{DARROW}        { return DARROW; }
{LE}        	{ return LE; }
{ASSIGN}        { return ASSIGN; }


 
 /*
  * Keywords are case-insensitive except for the values true and false,
  * which must begin with a lower-case letter.
  */


{CLASS}		{ return CLASS; }
{ELSE}		{ return ELSE; }
{IF}		{ return IF; }
{FI}		{ return FI; }
{IN}		{ return IN; }
{INHERITS}	{ return INHERITS; } 
{LET}		{ return LET; } 
{LOOP}		{ return LOOP; }    
{POOL}		{ return POOL; }
{WHILE}		{ return WHILE; }
{THEN}		{ return THEN; }
{CASE}		{ return CASE; }
{ESAC}		{ return ESAC;}
{OF}		{ return OF; }
{NEW}		{ return NEW; }
{ISVOID}	{ return ISVOID;}
{NOT}		{ return NOT; }


t[Rr][Uu][Ee]		{
				cool_yylval.boolean = 1;
				return (BOOL_CONST);
			}

f[Aa][Ll][Ss][Ee]       {
				cool_yylval.boolean = 0;
				return (BOOL_CONST);
			}


{INT_CONST}		{ 
				cool_yylval.symbol = inttable.add_string(yytext);
				return INT_CONST; 
			}

{OBJECTID}		{ 
				cool_yylval.symbol = idtable.add_string(yytext); 
				return OBJECTID; 
			}

{TYPEID}		{ 
				cool_yylval.symbol = idtable.add_string(yytext); 
				return TYPEID; 
			}


{OPERATORS}		{
				return (int)(yytext[0]);
			}

{SINGLE_CHARACTER_OPERATORS}	{
					return (int)(yytext[0]);
				}



 /*
  *  String constants (C syntax)
  *  Escape sequence \c is accepted for all characters c. Except for 
  *  \n \t \b \f, the result is c.
  *
  */


\"	{
    		BEGIN(STRING);
		string_buf_ptr = string_buf;
	}

<STRING>\"		{
				BEGIN(INITIAL);
				if(check_string_length()) 
					{	
						cool_yylval.error_msg = "String constant too long";
					        return ERROR;
					}		
				cool_yylval.symbol = stringtable.add_string(string_buf);
				string_buf_ptr = 0;
			    	return STR_CONST;		
		  	}

<STRING>[\0]		{	
				BEGIN(INV_STRING);		
	    			cool_yylval.error_msg = "String contains null character";
				return ERROR;		  		
			}

<STRING>\\\0		{   
				BEGIN(INV_STRING);
  				cool_yylval.error_msg = "String contains escaped null character.";
				return ERROR;
			}

<STRING><<EOF>>		{
				BEGIN(INITIAL);
				cool_yylval.error_msg = "EOF in string constant";
			    	return ERROR;		
 			}

<STRING>{NEW_LINE}	{
				BEGIN(INITIAL);
				curr_lineno++;
			    	cool_yylval.error_msg = "Unterminated string constant";
				return ERROR;		
	        	}

<STRING>\\\n		{	
				curr_lineno++; 		
 			}

<STRING>[^\\\"]\n	{
				cool_yylval.error_msg = "Unterminated string constant";
				BEGIN(INITIAL);
				return (ERROR);
  			}

<STRING>\\[n]		{
				if(check_string_length())
					{
						BEGIN(INITIAL);
						cool_yylval.error_msg = "String constant too long";
	    					return ERROR;		
					}
				*string_buf_ptr++ = '\n';
			}

<STRING>\\[t]		{    
				if(check_string_length())
					{
						BEGIN(INITIAL);
						cool_yylval.error_msg = "String constant too long";
	    					return ERROR;		
					}
				*string_buf_ptr++ = '\t';
 	        	}

<STRING>\\[b]		{	
				if(check_string_length())
					{
						BEGIN(INITIAL);
						cool_yylval.error_msg = "String constant too long";
	    					return ERROR;		
					}
    				*string_buf_ptr++ = '\b';
			}

<STRING>\\[f]		{
				if(check_string_length())
					{
						BEGIN(INITIAL);
						cool_yylval.error_msg = "String constant too long";
	    					return ERROR;		
					}
	    			*string_buf_ptr++ = '\f';
			}

<STRING>\\[^ntbf]	{
				if(check_string_length())
					{
						BEGIN(INITIAL);
						cool_yylval.error_msg = "String constant too long";
	    					return ERROR;		
					}
			   	*string_buf_ptr++ = yytext[1];
		  	}

<STRING>[^\\\n\0\"]+	{
		                if (check_string_length()) {
			            BEGIN(INV_STRING); 
		                    cool_yylval.error_msg = "String constant too long";
					    return ERROR;
		                }
		                strcpy(string_buf_ptr, yytext);
                        	string_buf_ptr += yyleng;
                        }


<STRING>. 		{
				if(check_string_length()) {
					BEGIN(INITIAL);
					cool_yylval.error_msg = "String constant too long";
			    		return ERROR;
			        }
	    			*string_buf_ptr++ = *yytext;
			}




<INV_STRING>\"		{
				BEGIN(INITIAL);
			}

<INV_STRING>{NEW_LINE}	{
		                ++curr_lineno;
		          	BEGIN(INITIAL);
                	}

<INV_STRING>\\\n	{
				++curr_lineno;
			}

<INV_STRING>[^\\\n\"]+	;

<INV_STRING>\\.		;



{NEW_LINE}	{ 
			curr_lineno++; 
		}

{WHITE_SPACE}+	{}

. 		{
		    	cool_yylval.error_msg = strdup(yytext);
		    	return ERROR;
		}

%%

void print_string () {
    printf("String is:'%s'\n", string_buf);
}

void print_string_length () { 
    printf("String length is: %d\n", string_buf_ptr - string_buf); 
}

bool check_string_length(void)
{
	if(string_buf_ptr - string_buf + 1 > MAX_STR_CONST)
		return true;
	else
		return false;
}