grammar Calc2 {
	rule TOP { <func> }
	
	rule func { <case>? ['|' <case>]* }
	rule case { <patts>? <var_decls>? <expr> }
	rule patts { <patt>? [',' <patt>]* '->' }
	
	rule expr { <expr_unit>* }
	rule expr_unit {
		|| <complicated>
		|| <decimal>
		|| <integer>
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
	token complicated { [\d+ ['.' \d+]? '+']? \d+ ['.' \d+]? 'i' }
	token decimal { \d+ '.' \d+ }
	token integer { \d+ }
	token obj_destr { <obj> '?' }
	token obj_make { '`'* <obj> }
	token obj { '()' || <:Lu> \w* }
	token ident { [<:Ll> || '_'] \w* '?'? }
	token op {
		| '+' | '~' | ['-' <![>]>] | '*' | '/'
		| '^' | '%' | '%%'
		| '=' | '/=' | '<' | '>' | '<=' | '>='
		
		| '<<' | '>>' | '<>'
		
		| '$'
		
		| '=?' | '/=?' | '<?' | '>?' | '<=?' | '>=?'
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

sub append(@list, $elem) {
	|@list, $elem
}

sub init(@list) {
	@list.head: *-1
}

sub concat(@list1, @list2) {
	|@list1, |@list2
}

class Calc2er {
	method TOP($/) { make $<func>.made()((), ()) }
	
	method func($match) { $match.make: sub (@stack, @scopes) {
		my @new-stack = @stack;
		for $match<case> -> $case {
			try { if $case<patts> {
				(@new-stack, my @new-scope) = $case<patts>.made()(@new-stack, @scopes);
				@scopes = append(@scopes, @new-scope);
			} }
			
			if not $! {
				(@new-stack, my @new-scope) = $case<var_decls>.made()(@new-stack, @scopes) if $case<var_decls>;
				@scopes = append(@scopes, @new-scope);
				return $case<expr>.made()(@new-stack, @scopes), @scopes;
			}
		}
		die
	} }
	
	method patts($match) { $match.make: sub (@stack, @scopes) {
		die
	} }
	
	method expr($match) { $match.make: sub (@stack, @scopes) {
		my @new-stack = @stack;
		for $match<expr_unit> -> $expr_unit {
			@new-stack = $expr_unit.values[0].made()(@new-stack, @scopes)
		}
		say @new-stack;
		@new-stack
	} }
	
	method complicated($match) { $match.make: sub (@stack, @scopes) {
		append(@stack, $match.Complex);
	} }
	
	method decimal($match) { $match.make: sub (@stack, @scopes) {
		append(@stack, $match.Num);
	} }
	
	method integer($match) { $match.make: sub (@stack, @scopes) {
		append(@stack, $match.Int);
	} }
}

say Calc2.parse(get(), actions => Calc2er).made while True;
# say Calc2.parse: get while True;