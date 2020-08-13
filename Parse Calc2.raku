grammar Calc2 {
	rule TOP { <func> }
	
	rule func { <case>? ['|' <case>]* }
	rule case { <patts>? <var-decls>? <expr> }
	rule patts { <patt>? [',' <patt>]* '->' }
	
	rule expr { <expr-unit>* }
	rule expr-unit {
		|| <complicated>
		|| <decimal>
		|| <integer>
		|| <obj-destr>
		|| <obj-make>
		|| <ident>
		|| <op>
		|| <string>
		|| <quote>
		|| '[' <func> ']'
		|| <infix-tuple>
		|| <func-expr>
		|| <match>
	}
	token complicated { [\d+ ['.' \d+]? '+']? \d+ ['.' \d+]? 'i' }
	token decimal { \d+ '.' \d+ }
	token integer { \d+ }
	token obj-destr { <obj> '?' }
	token obj-make { '`'* <obj> }
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
	rule quote { "'" <expr-unit> }
	rule infix-tuple { '(' <expr>? [',' <expr>]* ')' }
	rule func-expr { '{' <func> '}' }
	rule match { ':' <![=]> <func> }
	
	rule var-decls { [<var-decl> || <var-pipe-decl>]+ }
	rule var-decl { <patt> ':=' <expr> ';' }
	rule var-pipe-decl { <patt> '|=' <expr> ';' }
	
	rule patt { [<expr-unit> || <patt-ident>]* }
	rule patt-ident { '@' <ident> }
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

enum Type <
	Obj-Val
	Complicated-Val Decimal-Val Integer-Val
	String-Val
	Func-Val
>;

class Val { has Type $.type }

class Obj is Val {
	has $.type = Obj-Val;
	has Str $.tag;
	has @.vals;
}

class Complicated {
	has $.type = Complicated-Val;
	has Complex $.val;
}

class Decimal {
	has $.type = Decimal-Val;
	has Num $.val;
}

class Integer {
	has $.type = Integer-Val;
	has Int $.val;
}

class String {
	has $.type = String-Val;
	has Str $.val;
}

class Func {
	has $.type = Func-Val;
	has $.val;
}

class Calc2er {
	method TOP($/) { make $<func>.made()((), ()) }
	
	method func($match) { $match.make: sub (@stack, @scopes) {
		my @new-stack = @stack;
		for $match<case> -> $case {
			try { if $case<patts> {
				(@new-stack, my %new-scope) = $case<patts>.made()(@new-stack, @scopes);
				@scopes = append(@scopes, %new-scope);
			} }
			
			if not $! {
				(@new-stack, my %new-scope) = $case<var-decls>.made()(@new-stack, @scopes) if $case<var-decls>;
				@scopes = append(@scopes, %new-scope);
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
		for $match<expr-unit> -> $expr-unit {
			@new-stack = $expr-unit.made()(@new-stack, @scopes)
		}
		@new-stack
	} }
	
	method expr-unit($/) { make $/.values[0].made() }
	
	method complicated($match) { $match.make: sub (@stack, @scopes) {
		append(@stack, Complicated.new: val => $match.Complex);
	} }
	
	method decimal($match) { $match.make: sub (@stack, @scopes) {
		append(@stack, Decimal.new: val => $match.Num);
	} }
	
	method integer($match) { $match.make: sub (@stack, @scopes) {
		append(@stack, Integer.new: val => $match.Int);
	} }
	
	method obj-destr($match) { $match.make: sub (@stack, @scopes) {
		my $tag = $match<obj>.Str;
		$tag = 'Tup' if $tag eq '()';
		my $obj = @stack[*-1];
		given $obj.type {
			when Obj-Val { concat(init(@stack), $obj.vals.reverse) }
			default { say 'NOT IMPLEMENTED YET AAA'; @stack }
		}
	} }
	
	method obj-make($match) { $match.make: sub (@stack, @scopes) {
		my $tag = $match<obj>.Str;
		$tag = 'Tup' if $tag eq '()';
		my $obj-len = ($match ~~ /'`'*/).chars;
		append(
			@stack.head(*-$obj-len),
			Obj.new: tag => $tag, vals => @stack.tail($obj-len).reverse
		)
	} }
	
	# For testing.
	method ident($match) { $match.make: sub (@stack, @scopes) {
		given $match.Str {
			when 'dup' { append(@stack, @stack[*-1]) }
			when 'drop' { init(@stack) }
			when 'do' { @stack[*-1].val.made()(init(@stack), @scopes) }
		}
	} }
	
	method string($match) { $match.make: sub (@stack, @scopes) {
		my @string = [];
		my Bool $escaping = False;
		for $match.Str.split('').head(*-2).tail(*-2) {
			if $escaping {
				given $_ {
					when 'n' { @string.push("\n") }
					when 't' { @string.push("\t") }
					default { @string.push($_) }
				}
				$escaping = False;
			}
			elsif $_ ne '\\' { @string.push($_) }
			else { $escaping = True }
		}
		append(@stack, String.new: val => @string.join)
	} }
	
	method quote($match) { $match.make: sub (@stack, @scopes) {
		append(@stack, Func.new: val => $match<expr-unit>)
	} }
	
	method infix-tuple($match) { $match.make: sub (@stack, @scopes) {
		my @tuple = [];
		my @new-stack = @stack;
		for $match<expr> -> $expr {
			@new-stack = $expr.made()(@new-stack, @scopes);
			@tuple.push(@new-stack[*-1]);
			@new-stack = init(@new-stack);
		}
		append(@new-stack, Obj.new: tag => 'Tup', vals => @tuple)
	} }
	
	method func-expr($match) { $match.make: sub (@stack, @scopes) {
		append(@stack, Func.new: val => $match<func>)
	} }
	
	method match($/) { make $<func>.made }
}

say Calc2.parse(get, actions => Calc2er).made while True;
# say Calc2.parse: get while True;