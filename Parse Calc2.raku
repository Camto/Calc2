grammar Calc2 {
	rule TOP { <case> }
	
	rule func { <case>? ['|' <case>]* }
	rule case { <patts>? <expr> }
	rule patts { <patt>? [',' <patt>]* '->' }
	
	rule expr { <var_decls>? <expr_unit>* }
	rule expr_unit {
		|| <number>
		|| <obj_destr>
		|| <obj_make>
		|| <ident>
		|| <op>
		|| <string>
		|| <quote>
		|| '[' <expr> ']'
		|| <infix_tuple>
		|| <func_expr>
		|| <match>
	}
	token number { \d+ ['.' \d+]? }
	token obj_destr { <obj> '?' }
	token obj_make { '`'* <obj> }
	token obj { '()' || <:Lu> \w+ }
	token ident { [<:Ll> || '_'] \w* '?'? }
	token op {
		| '+' | '~' | ['-' <![>]>] | '*' | '/'
		| '^' | '%' | '%%'
		| '=' | '<' | '>' | '<=' | '>='
		
		| '<<' | '>>' | '<>'
		
		| '=?' | '<?' | '>?' | '<=?' | '>=?'
		| '<<?' | '>>?'
	}
	token string { '"' ['\\' . || <-["]>]* '"' }
	rule quote { "'" <expr_unit> }
	rule infix_tuple { '(' <expr>? [',' <expr>]* ')' }
	rule func_expr { '{' <func> '}' }
	rule match { ':' <![=]> <func> }
	
	rule var_decls { [<var_decl> || <var_pipe_decl>]+ }
	rule var_decl { <patt> ':=' <func> ';' }
	rule var_pipe_decl { <patt> '|=' <func> ';' }
	
	rule patt { [<expr_unit> || <patt_ident>]* }
	rule patt_ident { '@' <ident> }
}

say Calc2.parse: get() while True;