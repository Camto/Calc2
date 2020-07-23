grammar Calc2 {
	rule TOP { <var_decls>? <expr> }
	
	rule func { <case>? ['|' <case>]* }
	rule case { <patts>? <var_decls>? <expr> }
	rule patts { <patt>? [',' <patt>]* '->' }
	
	rule expr { <expr_unit>* }
	rule expr_unit {
		|| <number>
		|| <obj_destr>
		|| <obj_make>
		|| <ident>
		|| <op>
		|| <string>
		|| <quote>
		|| '[' <func> ']'
		|| <infix_tuple>
		|| <func_expr>
		|| <match>
	}
	token number { \d+ ['.' \d+]? }
	token obj_destr { <obj> '?' }
	token obj_make { '`'* <obj> }
	token obj { '()' || <:Lu> \w* }
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
	rule var_decl { <patt> ':=' <expr> ';' }
	rule var_pipe_decl { <patt> '|=' <expr> ';' }
	
	rule patt { [<expr_unit> || <patt_ident>]* }
	rule patt_ident { '@' <ident> }
}

say Calc2.parse: get() while True;