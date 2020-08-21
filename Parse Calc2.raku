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

class Val {
	has Type $.type;
	has $.val;
}

class Obj-Data {
	has Str $.tag;
	has @.vals;
}

enum Node-Type <
	Func-Node Patt-Node Expr-Node
	Obj-Make-Node Obj-Destr-Node Tuple-Node
	Ident-Node Func-Expr-Node
	Complicated-Node Decimal-Node Integer-Node String-Node
>;

class AST {
	has Node-Type $.type;
	has $.val;
}

class Case-Data {
	has @.patts;
	has @.var-decls;
	has $.expr;
}

class Obj-Make-Data {
	has Str $.tag;
	has Int $.len;
}

class Calc2er {
	method TOP($/) { make $<func>.made }
	
	method func($match) {
		$match.make: AST.new: type => Func-Node, val => (for $match<case> {
			Case-Data.new:
				patts => $_<patts> ?? [] !! [],
				var-decls => $_<var-decls> ?? [] !! [],
				expr => $_<expr>.made
		})
	}
	
	method patts($match) { $match.make: sub (@stack, @scopes) {
		my %new-scope = {};
		
	} }
	
	method patt($match) { $match.make: sub (@stack, @scopes) {
		#
	} }
	
	method expr($match) {
		$match.make: AST.new: type => Expr-Node, val => (for $match<expr-unit> { $_.made })
	}
	
	method expr-unit($/) { make $/.values[0].made }
	
	method complicated($match) {
		$match.make: AST.new: type => Complicated-Node, val => $match.Complex
	}
	
	method decimal($match) {
		$match.make: AST.new: type => Decimal-Node, val => $match.Num
	}
	
	method integer($match) {
		$match.make: AST.new: type => Integer-Node, val => $match.Int
	}
	
	method obj-destr($match) {
		$match.make: AST.new: type => Obj-Destr-Node, val => $match<obj>.Str
	}
	
	method obj-make($match) {
		$match.make: AST.new: type => Obj-Make-Node, val => Obj-Make-Data.new: tag => $match<obj>.Str, len => ($match ~~ /'`'*/).chars
	}
	
	# For testing.
	method ident($match) {
		$match.make: AST.new: type => Ident-Node, val => $match.Str
	}
	
	method op($match) {
		$match.make: AST.new: type => Ident-Node, val => {
			'+' => 'add', '~' => 'neg', '-' => 'sub', '*' => 'mul', '/' => 'div',
			'^' => 'pow', '%' => 'mod', '%%' => 'divisible',
			'=' => 'eq', '/=' => 'neq', '<' => 'lt', '>' => 'gt', '<=' => 'leq', '>=' => 'geq',
			
			'<<' => 'snoc', '>>' => 'cons', '<>' => 'concat',
			
			'$' => 'safe',
			
			'=?' => 'eq?', '/=?' => 'neq?', '<?' => 'lt?', '>?' => 'gt?', '<=?' => 'leq?', '>=?' => 'geq?',
			'<<?' => 'snoc?', '>>?' => 'cons?'
		}{$match.Str}
	}
	
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
		append(@stack, Val.new: type => String-Val, val => @string.join), depth-update($depth-affected, 0, 1)
	} }
	
	method quote($match) {
		$match.make: AST.new: type => Func-Expr-Node, val => $match<expr-unit>.made
	}
	
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
		append(@new-stack, Val.new: type => Obj-Val, val => Obj-Data.new: tag => 'Tup', vals => @tuple), depth-update($new-depth-affected, 0, 1)
	} }
	
	method func-expr($match) {
		$match.make: AST.new: type => Func-Expr-Node, val => $match<func>.made
	}
	
	method match($/) { make $<func>.made }
}

sub run($ast, @scopes) {
	sub (@stack, $depth-affected) {
		given $ast.type {
			when Func-Node {
				my @new-stack = @stack;
				my $new-depth-affected = $depth-affected;
				my @new-scopes = @scopes;
				for $ast.val -> $case {
					try { if $case.patts {
						my $dumb-tmp = $case<patts>.made()(@new-stack, $new-depth-affected, @new-scopes);
						@new-stack = $dumb-tmp[0];
						$new-depth-affected = $dumb-tmp[1];
						@new-scopes = $dumb-tmp[2];
					} }
					
					if not $! {
						if $case.var-decls {
							my $dumb-tmp = $case<var-decls>.made()(@new-stack, $new-depth-affected, @new-scopes);
							@new-stack = $dumb-tmp[0];
							$new-depth-affected = $dumb-tmp[1];
							@new-scopes = $dumb-tmp[2];
						}
						return run($case.expr, @new-scopes)(@new-stack, $new-depth-affected);
					}
				}
				die
			}
			
			when Expr-Node {
				my @new-stack = @stack;
				my $new-depth-affected = $depth-affected;
				for $ast.val -> $expr-unit {
					my $dumb-tmp = run($expr-unit, @scopes)(@new-stack, $new-depth-affected);
					@new-stack = $dumb-tmp[0];
					$new-depth-affected = $dumb-tmp[1];
				}
				@new-stack, $new-depth-affected
			}
			
			when Complicated-Node {
				append(@stack, Val.new: type => Complicated-Val, val => $ast.val), depth-update($depth-affected, 0, 1)
			}
			
			when Decimal-Node {
				append(@stack, Val.new: type => Decimal-Val, val => $ast.val), depth-update($depth-affected, 0, 1)
			}
			
			when Integer-Node {
				append(@stack, Val.new: type => Integer-Val, val => $ast.val), depth-update($depth-affected, 0, 1)
			}
			
			when Obj-Destr-Node {
				my $tag = $ast.val;
				$tag = 'Tup' if $tag eq '()';
				my $obj = @stack[*-1];
				given $obj.type {
					when Obj-Val {
						die if $obj.val.tag ne $tag;
						concat(init(@stack), $obj.val.vals.reverse), depth-update($depth-affected, 1, $obj.val.vals.elems)
					}
					default { say 'NOT IMPLEMENTED YET AAA'; @stack }
				}
			}
			
			when Obj-Make-Node {
				my $tag = $ast.val.tag;
				$tag = 'Tup' if $tag eq '()';
				my $obj-len = $ast.val.len;
				die if @stack.elems < $obj-len;
				append(
					@stack.head(*-$obj-len),
					Val.new: type => Obj-Val, val => Obj-Data.new: tag => $tag, vals => @stack.tail($obj-len).reverse
				), depth-update($depth-affected, $obj-len, 1)
			}
			
			when Ident-Node {
				my $intermediate = run(@stack[*-1].val, @scopes)(init(@stack), $depth-affected);
				$intermediate[0], depth-update($intermediate[1], 1, 0)
			}
			
			when Func-Expr-Node {
				append(@stack, Val.new: type => Func-Val, val => $ast.val), depth-update($depth-affected, 0, 1)
			}
		}
	}
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

say run(Calc2.parse($prelude ~ get, actions => Calc2er).made, [])([], 0) while True;
# say Calc2.parse($prelude ~ get, actions => Calc2er).made while True;
# say Calc2.parse: get while True;