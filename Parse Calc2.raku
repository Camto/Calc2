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
	(|@list, $elem).Array
}

sub init(@list) {
	@list.head: *-1
}

sub concat(@list1, @list2) {
	(|@list1, |@list2).Array
}

sub depth-update($depth-affected, $popped, $pushed) {
	max(0, $depth-affected - $popped) + $pushed
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
	method TOP($/) { make $<func>.made }
	
	method func($match) { $match.make: sub (@stack, $depth-affected, @scopes) {
		my @new-stack = @stack;
		my $new-depth-affected = $depth-affected;
		my @new-scopes = @scopes;
		for $match<case> -> $case {
			try { if $case<patts> {
				my $dumb-tmp = $case<patts>.made()(@new-stack, $new-depth-affected, @new-scopes);
				@new-stack = $dumb-tmp[0];
				$new-depth-affected = $dumb-tmp[1];
				@new-scopes = $dumb-tmp[2];
			} }
			
			if not $! {
				if $case<var-decls> {
					my $dumb-tmp = $case<var-decls>.made()(@new-stack, $new-depth-affected, @new-scopes);
					@new-stack = $dumb-tmp[0];
					$new-depth-affected = $dumb-tmp[1];
					@new-scopes = $dumb-tmp[2];
				}
				return $case<expr>.made()(@new-stack, $new-depth-affected, @new-scopes);
			}
		}
		die
	} }
	
	method patts($match) { $match.make: sub (@stack, @scopes) {
		my %new-scope = {};
		
	} }
	
	method patt($match) { $match.make: sub (@stack, @scopes) {
		#
	} }
	
	method expr($match) { $match.make: sub (@stack, $depth-affected, @scopes) {
		my @new-stack = @stack;
		my $new-depth-affected = $depth-affected;
		for $match<expr-unit> -> $expr-unit {
			my $dumb-tmp = $expr-unit.made()(@new-stack, $new-depth-affected, @scopes);
			say 'dump-tmp: ', $dumb-tmp;
			@new-stack = $dumb-tmp[0];
			say 'new-stack: ', $dumb-tmp[0];
			say 'new-stack: ', @new-stack;
			$new-depth-affected = $dumb-tmp[1];
		}
		@new-stack, $new-depth-affected
	} }
	
	method expr-unit($/) { make $/.values[0].made }
	
	method complicated($match) { $match.make: sub (@stack, $depth-affected, @scopes) {
		append(@stack, Complicated.new: val => $match.Complex), depth-update($depth-affected, 0, 1)
	} }
	
	method decimal($match) { $match.make: sub (@stack, $depth-affected, @scopes) {
		append(@stack, Decimal.new: val => $match.Num), depth-update($depth-affected, 0, 1)
	} }
	
	method integer($match) { $match.make: sub (@stack, $depth-affected, @scopes) {
		append(@stack, Integer.new: val => $match.Int), depth-update($depth-affected, 0, 1)
	} }
	
	method obj-destr($match) { $match.make: sub (@stack, $depth-affected, @scopes) {
		my $tag = $match<obj>.Str;
		$tag = 'Tup' if $tag eq '()';
		my $obj = @stack[*-1];
		given $obj.type {
			when Obj-Val {
				concat(init(@stack), $obj.vals.reverse), depth-update($depth-affected, 1, $obj.elems)
			}
			default { say 'NOT IMPLEMENTED YET AAA'; @stack }
		}
	} }
	
	method obj-make($match) { $match.make: sub (@stack, $depth-affected, @scopes) {
		my $tag = $match<obj>.Str;
		$tag = 'Tup' if $tag eq '()';
		my $obj-len = ($match ~~ /'`'*/).chars;
		append(
			@stack.head(*-$obj-len),
			Obj.new: tag => $tag, vals => @stack.tail($obj-len).reverse
		), depth-update($depth-affected, $obj-len, 1)
	} }
	
	# For testing.
	method ident($match) { $match.make: sub (@stack, $depth-affected, @scopes) {
		my $name = $match.Str;
		given $name {
			when 'do' {
				my $intermediate = @stack[*-1].val.made()(init(@stack), $depth-affected, @scopes);
				$intermediate[1] = depth-update($intermediate[1], 1, 0);
				$intermediate
			}
		}
	} }
	
	method string($match) { $match.make: sub (@stack, $depth-affected, @scopes) {
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
		append(@stack, String.new: val => @string.join), depth-update($depth-affected, 0, 1)
	} }
	
	method quote($match) { $match.make: sub (@stack, $depth-affected, @scopes) {
		append(@stack, Func.new: val => $match<expr-unit>), depth-update($depth-affected, 0, 1)
	} }
	
	method infix-tuple($match) { $match.make: sub (@stack, $depth-affected, @scopes) {
		my @tuple = [];
		my @new-stack = @stack;
		my $new-depth-affected = $depth-affected;
		for $match<expr> -> $expr {
			my $dumb-tmp = $expr.made()(@new-stack, $new-depth-affected, @scopes);
			@new-stack = $dumb-tmp[0];
			$new-depth-affected = $dumb-tmp[1];
			@tuple.push(@new-stack[*-1]);
			@new-stack = init(@new-stack);
			$new-depth-affected = depth-update($new-depth-affected, 1, 0);
		}
		append(@new-stack, Obj.new: tag => 'Tup', vals => @tuple), depth-update($new-depth-affected, 0, 1)
	} }
	
	method func-expr($match) { $match.make: sub (@stack, $depth-affected, @scopes) {
		append(@stack, Func.new: val => $match<func>), depth-update($depth-affected, 0, 1)
	} }
	
	method match($/) { make $<func>.made }
}

#`(
my $prelude = "
	dup := \{a-> 'a 'a} ;
	drop := \{_->} ;
	do := \{fn-> fn} ;
	swap := \{a b-> 'a 'b} ;
	id := \{} ;
";
)

my $prelude = "";

say Calc2.parse($prelude ~ get, actions => Calc2er).made()([], 0, []) while True;
# say Calc2.parse: get while True;