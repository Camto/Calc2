grammar Calc2 {
	rule TOP { <ws> <func> }
	
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
	token complicated { [\d+ ['.' \d+]? ['+' || '-']]? \d+ ['.' \d+]? 'i' }
	token decimal { \d+ '.' \d+ }
	token integer { \d+ }
	token obj-destr { <obj> '?' }
	token obj-make { '`'* <obj> }
	token obj { '()' || <:Lu> \w* }
	token ident { [<:Ll> || '_'] \w* '?'? }
	token op {
		| '+' | '~' | ['-' [<![>]> | $]] | '*' | '/'
		| '^' | '%' | '%%'
		| '=' | '/=' | '<' | '>' | '<=' | '>='
		
		| '<<' | '>>' | '<>'
		
		| '&'
		
		| '=?' | '/=?' | '<?' | '>?' | '<=?' | '>=?'
		| '<<?' | '>>?'
	}
	token string { '"' ['\\' . || <-["]>]* '"' }
	rule quote { "'" <expr-unit> }
	rule infix-tuple { '(' <expr>? [',' <expr>]* ')' }
	rule func-expr { '{' <func> '}' }
	rule match { ':' <![=]> <func> }
	
	rule var-decls { <decl>+ }
	rule decl { <var-decl> || <pipe-decl> }
	rule var-decl { <patt> ':=' <expr> ';' }
	rule pipe-decl { <ident> '|=' <func-expr> ';' }
	
	rule patt { <patt-unit>* }
	rule patt-unit { <patt-bind> || <patt-ident> || <expr-unit> }
	token patt-bind { [<:Ll> || '_'] \w* '?'? }
	token patt-ident { '@' <ident> }
}

sub append(@list, $elem) {
	(|@list, $elem).Array
}

sub prepend(@list, $elem) {
	($elem, |@list).Array
}

sub init(@list) {
	@list.head: *-1
}

sub concat(@list1, @list2) {
	(|@list1, |@list2).Array
}

sub depth-update(@depth-affected, $popped, $pushed) {
	@depth-affected.map: { max(0, $^depth - $popped) + $pushed }
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
	Func-Node Expr-Node Patts-Node Var-Decls-Node Var-Decl-Node Pipe-Decl-Node Run-It-Node
	Obj-Make-Node Obj-Destr-Node Tuple-Node
	Ident-Node Quote-Var-Node Bind-Node Func-Expr-Node
	Complicated-Node Decimal-Node Integer-Node String-Node
>;

class AST {
	has Node-Type $.type;
	has $.val;
}

class Case-Data {
	has $.patts;
	has $.var-decls;
	has $.expr;
}

class Obj-Make-Data {
	has Str $.tag;
	has Int $.len;
}

class Decl-Data {
	has $.name;
	has $.def;
}

class Calc2er {
	method TOP($/) { make $<func>.made }
	
	method func($match) {
		$match.make: AST.new: type => Func-Node, val => (for $match<case> {
			Case-Data.new:
				patts => $_<patts> ?? $_<patts>.made !! AST.new(type => Patts-Node, val => []),
				var-decls => $_<var-decls> ?? $_<var-decls>.made !! AST.new(type => Var-Decls-Node, val => []),
				expr => $_<expr>.made
		})
	}
	
	method patts($match) {
		$match.make: AST.new: type => Patts-Node, val => (for $match<patt> { $_.made })
	}
	
	method patt($match) {
		$match.make: AST.new: type => Expr-Node, val => (for $match<patt-unit> { $_.made })
	}
	
	method patt-unit($match) {
		return $match.make: AST.new: type => Bind-Node, val => $match.Str.trim if $match<patt-bind>;
		return $match.make: AST.new: type => Ident-Node, val => $match.Str.substr(1).trim if $match<patt-ident>;
		return $match.make: $match<expr-unit>.made;
	}
	
	method var-decls($match) {
		$match.make: AST.new: type => Var-Decls-Node, val => (for $match<decl> { $_.made })
	}
	
	method decl($/) { make $/.values[0].made }
	
	method var-decl($match) {
		$match.make: AST.new: type => Var-Decl-Node, val =>
			Decl-Data.new:
				name => $match<patt>.made,
				def => $match<expr>.made
	}
	
	method pipe-decl($match) {
		$match.make: AST.new: type => Pipe-Decl-Node, val =>
			Decl-Data.new:
				name => $match<ident>.Str.trim,
				def => $match<func-expr>.made.val
	}
	
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
		$match.make: AST.new: type => Obj-Destr-Node, val => $match<obj>.Str.trim
	}
	
	method obj-make($match) {
		$match.make: AST.new: type => Obj-Make-Node, val => Obj-Make-Data.new: tag => $match<obj>.Str.trim, len => ($match ~~ /'`'*/).chars
	}
	
	method ident($match) {
		$match.make: AST.new: type => Ident-Node, val => $match.Str.trim
	}
	
	method op($match) {
		$match.make: AST.new: type => Ident-Node, val => {
			'+' => 'add', '~' => 'neg', '-' => 'sub', '*' => 'mul', '/' => 'div',
			'^' => 'pow', '%' => 'mod', '%%' => 'divtst',
			'=' => 'eq', '/=' => 'neq', '<' => 'lt', '>' => 'gt', '<=' => 'lte', '>=' => 'gte',
			
			'<<' => 'snoc', '>>' => 'cons', '<>' => 'cat',
			
			'&' => 'safe',
			
			'=?' => 'eq?', '/=?' => 'neq?', '<?' => 'lt?', '>?' => 'gt?', '<=?' => 'lte?', '>=?' => 'gte?',
			'<<?' => 'snoc?', '>>?' => 'cons?'
		}{$match.Str}
	}
	
	method string($match) {
		my @string = [];
		my Bool $escaping = False;
		for $match.Str.trim.split('').head(*-2).tail(*-2) {
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
		$match.make: AST.new: type => String-Node, val => @string.join
	}
	
	method quote($match) {
		return $match.make: AST.new: type => Func-Expr-Node, val => $match<expr-unit>.made if $match<expr-unit>.made.type ne Ident-Node;
		return $match.make: AST.new: type => Quote-Var-Node, val => $match<expr-unit>.made;
	}
	
	method infix-tuple($match) {
		$match.make: AST.new: type => Tuple-Node, val => (for $match<expr> { $_.made })
	}
	
	method func-expr($match) {
		$match.make: AST.new: type => Func-Expr-Node, val => $match<func>.made
	}
	
	method match($/) { make $<func>.made }
}

sub max-num-type(Type $t1, Type $t2) {
	if $t1 == Complicated-Val || $t2 == Complicated-Val {
		Complicated-Val
	} elsif $t1 == Decimal-Val || $t2 == Decimal-Val {
		Decimal-Val
	} else {
		Integer-Val
	}
}

sub is-num-type(Type $t) { $t == Complicated-Val || $t == Decimal-Val || $t == Integer-Val }

sub is-real-type(Type $t) { $t == Decimal-Val || $t == Integer-Val }

sub bool-to-val(Bool $b) { Val.new(type => Obj-Val, val => Obj-Data.new: tag => $b ?? 'True' !! 'False', vals => []) }

sub val-eq(Val $x, Val $y) {
	return False if $x.type != $y.type && not (is-num-type($x.type) && is-num-type($y.type));
	given $x.type {
		when Obj-Val {
			return False if $x.val.tag ne $y.val.tag || $x.val.vals.elems != $y.val.vals.elems;
			for $x.val.vals Z $y.val.vals {
				return False if not val-eq($_[0], $_[1]);
			}
			True
		}
		
		when Complicated-Val {
			$x.val == $y.val
		}
		when Decimal-Val {
			$x.val == $y.val
		}
		when Integer-Val {
			$x.val == $y.val
		}
		
		when String-Val {
			$x.val eq $y.val
		}
		
		default {
			False
		}
	}
}

my %built-ins = {
	add => sub (@stack, @depth-affected) {
		die if @stack.elems < 2;
		my $y = @stack[*-1];
		my $x = @stack[*-2];
		die if not is-num-type($x.type) && is-num-type($y.type);
		append(@stack.head(*-2), Val.new(type => max-num-type($x.type, $y.type), val => $x.val + $y.val)), depth-update(@depth-affected, 2, 1)
	},
	
	neg => sub (@stack, @depth-affected) {
		die if @stack.elems < 1;
		my $x = @stack[*-1];
		die if not is-num-type($x.type);
		append(init(@stack), Val.new(type => $x.type, val => -$x.val)), depth-update(@depth-affected, 1, 1)
	},
	
	sub => sub (@stack, @depth-affected) {
		die if @stack.elems < 2;
		my $y = @stack[*-1];
		my $x = @stack[*-2];
		die if not is-num-type($x.type) && is-num-type($y.type);
		append(@stack.head(*-2), Val.new(type => max-num-type($x.type, $y.type), val => $x.val - $y.val)), depth-update(@depth-affected, 2, 1)
	},
	
	mul => sub (@stack, @depth-affected) {
		die if @stack.elems < 2;
		my $y = @stack[*-1];
		my $x = @stack[*-2];
		die if not is-num-type($x.type) && is-num-type($y.type);
		append(@stack.head(*-2), Val.new(type => max-num-type($x.type, $y.type), val => $x.val * $y.val)), depth-update(@depth-affected, 2, 1)
	},

	div => sub (@stack, @depth-affected) {
		die if @stack.elems < 2;
		my $y = @stack[*-1];
		my $x = @stack[*-2];
		die if not is-num-type($x.type) && is-num-type($y.type);
		die if $y.val == 0;
		append(@stack.head(*-2), Val.new(type => max-num-type(Decimal-Val, max-num-type($x.type, $y.type)), val => $x.val / $y.val)), depth-update(@depth-affected, 2, 1)
	},
	
	pow => sub (@stack, @depth-affected) {
		die if @stack.elems < 2;
		my $y = @stack[*-1];
		my $x = @stack[*-2];
		die if not is-num-type($x.type) && is-num-type($y.type);
		append(@stack.head(*-2), Val.new(type => max-num-type($x.type, $y.type), val => $x.val ** $y.val)), depth-update(@depth-affected, 2, 1)
	},
	
	mod => sub (@stack, @depth-affected) {
		die if @stack.elems < 2;
		my $y = @stack[*-1];
		my $x = @stack[*-2];
		die if not is-num-type($x.type) && is-num-type($y.type);
		die if $y.val == 0;
		append(@stack.head(*-2), Val.new(type => max-num-type($x.type, $y.type), val => $x.val % $y.val)), depth-update(@depth-affected, 2, 1)
	},
	
	divtst => sub (@stack, @depth-affected) {
		die if @stack.elems < 2;
		my $y = @stack[*-1];
		my $x = @stack[*-2];
		die if not is-num-type($x.type) && is-num-type($y.type);
		die if $y.val == 0;
		append(@stack.head(*-2), bool-to-val($x.val %% $y.val)), depth-update(@depth-affected, 2, 1)
	},
	
	eq => sub (@stack, @depth-affected) {
		die if @stack.elems < 2;
		my $y = @stack[*-1];
		my $x = @stack[*-2];
		append(@stack.head(*-2), bool-to-val(val-eq($x, $y))), depth-update(@depth-affected, 2, 1)
	},
	
	neq => sub (@stack, @depth-affected) {
		die if @stack.elems < 2;
		my $y = @stack[*-1];
		my $x = @stack[*-2];
		append(@stack.head(*-2), bool-to-val(not val-eq($x, $y))), depth-update(@depth-affected, 2, 1)
	},
	
	lt => sub (@stack, @depth-affected) {
		die if @stack.elems < 2;
		my $y = @stack[*-1];
		my $x = @stack[*-2];
		die if not is-real-type($x.type) && is-real-type($y.type);
		append(@stack.head(*-2), bool-to-val($x.val < $y.val)), depth-update(@depth-affected, 2, 1)
	},
	
	gt => sub (@stack, @depth-affected) {
		die if @stack.elems < 2;
		my $y = @stack[*-1];
		my $x = @stack[*-2];
		die if not is-real-type($x.type) && is-real-type($y.type);
		append(@stack.head(*-2), bool-to-val($x.val > $y.val)), depth-update(@depth-affected, 2, 1)
	},
	
	lte => sub (@stack, @depth-affected) {
		die if @stack.elems < 2;
		my $y = @stack[*-1];
		my $x = @stack[*-2];
		die if not is-real-type($x.type) && is-real-type($y.type);
		append(@stack.head(*-2), bool-to-val($x.val <= $y.val)), depth-update(@depth-affected, 2, 1)
	},
	
	gte => sub (@stack, @depth-affected) {
		die if @stack.elems < 2;
		my $y = @stack[*-1];
		my $x = @stack[*-2];
		die if not is-real-type($x.type) && is-real-type($y.type);
		append(@stack.head(*-2), bool-to-val($x.val >= $y.val)), depth-update(@depth-affected, 2, 1)
	},
	
	snoc => sub (@stack, @depth-affected) {
		die if @stack.elems < 2;
		my $y = @stack[*-1];
		my $x = @stack[*-2];
		die if $x.type != Obj-Val || $x.val.tag ne 'Tup';
		append(@stack.head(*-2), Val.new: type => Obj-Val, val => Obj-Data.new: tag => 'Tup', vals => append($x.val.vals, $y)), depth-update(@depth-affected, 2, 1)
	},

	cons => sub (@stack, @depth-affected) {
		die if @stack.elems < 2;
		my $y = @stack[*-1];
		my $x = @stack[*-2];
		die if $x.type != Obj-Val || $x.val.tag ne 'Tup';
		append(@stack.head(*-2), Val.new: type => Obj-Val, val => Obj-Data.new: tag => 'Tup', vals => prepend($x.val.vals, $y)), depth-update(@depth-affected, 2, 1)
	},
	
	cat => sub (@stack, @depth-affected) {
		die if @stack.elems < 2;
		my $y = @stack[*-1];
		my $x = @stack[*-2];
		die if $x.type != Obj-Val || $x.val.tag ne 'Tup';
		die if $y.type != Obj-Val || $y.val.tag ne 'Tup';
		append(@stack.head(*-2), Val.new: type => Obj-Val, val => Obj-Data.new: tag => 'Tup', vals => concat($x.val.vals, $y.val.vals)), depth-update(@depth-affected, 2, 1)
	},
	
	safe => sub (@stack, @depth-affected) {
		die if @stack.elems < 1;
		my $x = @stack[*-1];
		die if $x.type != Func-Val;
		my @safe-res = [];
		try {
			my $dumb-tmp = $x.val()(init(@stack), [0]);
			@safe-res = $dumb-tmp[0].tail($dumb-tmp[1][0]);
		}
		append(init(@stack), Val.new: type => Obj-Val, val => Obj-Data.new: tag => 'Tup', vals => @safe-res), depth-update(@depth-affected, 1, 1)
	},
	
	'eq?' => sub (@stack, @depth-affected) {
		die if @stack.elems < 2;
		my $y = @stack[*-1];
		my $x = @stack[*-2];
		die if not val-eq($x, $y);
		@stack.head(*-2), depth-update(@depth-affected, 2, 0)
	},
	
	'neq?' => sub (@stack, @depth-affected) {
		die if @stack.elems < 2;
		my $y = @stack[*-1];
		my $x = @stack[*-2];
		die if val-eq($x, $y);
		init(@stack), depth-update(@depth-affected, 2, 1)
	},
	
	'lt?' => sub (@stack, @depth-affected) {
		die if @stack.elems < 2;
		my $y = @stack[*-1];
		my $x = @stack[*-2];
		die if not is-real-type($x.type) && is-real-type($y.type);
		die if not $x.val < $y.val;
		init(@stack), depth-update(@depth-affected, 2, 1)
	},
	
	'gt?' => sub (@stack, @depth-affected) {
		die if @stack.elems < 2;
		my $y = @stack[*-1];
		my $x = @stack[*-2];
		die if not is-real-type($x.type) && is-real-type($y.type);
		die if not $x.val > $y.val;
		init(@stack), depth-update(@depth-affected, 2, 1)
	},
	
	'lte?' => sub (@stack, @depth-affected) {
		die if @stack.elems < 2;
		my $y = @stack[*-1];
		my $x = @stack[*-2];
		die if not is-real-type($x.type) && is-real-type($y.type);
		die if not $x.val <= $y.val;
		init(@stack), depth-update(@depth-affected, 2, 1)
	},
	
	'gte?' => sub (@stack, @depth-affected) {
		die if @stack.elems < 2;
		my $y = @stack[*-1];
		my $x = @stack[*-2];
		die if not is-real-type($x.type) && is-real-type($y.type);
		die if not $x.val >= $y.val;
		init(@stack), depth-update(@depth-affected, 2, 1)
	},
	
	'snoc?' => sub (@stack, @depth-affected) {
		die if @stack.elems < 1;
		my $l = @stack[*-1];
		die if $l.type != Obj-Val || $l.val.tag ne 'Tup' || $l.val.vals.elems < 1;
		concat(init(@stack), [Val.new(type => Obj-Val, val => Obj-Data.new: tag => 'Tup', vals => init($l.val.vals)), $l.val.vals[*-1]]), depth-update(@depth-affected, 1, 2)
	},
	
	'cons?' =>  sub (@stack, @depth-affected) {
		die if @stack.elems < 1;
		my $l = @stack[*-1];
		die if $l.type != Obj-Val || $l.val.tag ne 'Tup' || $l.val.vals.elems < 1;
		concat(init(@stack), [Val.new(type => Obj-Val, val => Obj-Data.new: tag => 'Tup', vals => $l.val.vals.tail(*-1)), $l.val.vals[0]]), depth-update(@depth-affected, 1, 2)
	}
}>>.map: { Val.new: type => Func-Val, val => $^fn };

sub get-var(@scopes, $ident) {
	for @scopes.reverse {
		return $_{$ident} if $_{$ident}:exists
	}
	return %built-ins{$ident} if %built-ins{$ident}:exists;
	die
}

sub run($ast, @scopes) {
	sub (@stack, @depth-affected) {
		given $ast.type {
			when Run-It-Node {
				my @new-scopes = @scopes;
				my @new-stack = @stack;
				my @new-depth-affected = @depth-affected;
				my $dumb-tmp = $ast.val()(@new-stack, @new-depth-affected);
				@new-scopes = $dumb-tmp[0];
				@new-stack = $dumb-tmp[1];
				@new-depth-affected = $dumb-tmp[2];
				@new-scopes, @new-stack, @new-depth-affected
			}
			
			when Func-Node {
				my @new-scopes = append(@scopes, {});
				my @new-stack = @stack;
				my @new-depth-affected = @depth-affected;
				for $ast.val -> $case {
					try {
						my $dumb-tmp = run($case.patts, @new-scopes)(@new-stack, @new-depth-affected);
						@new-scopes = $dumb-tmp[0];
						@new-stack = $dumb-tmp[1];
						@new-depth-affected = $dumb-tmp[2];
					}
					
					if not $! {
						my $dumb-tmp = run($case.var-decls, @new-scopes)(@new-stack, @new-depth-affected);
						@new-scopes = $dumb-tmp[0];
						@new-stack = $dumb-tmp[1];
						@new-depth-affected = $dumb-tmp[2];
						$dumb-tmp = run($case.expr, @new-scopes)(@new-stack, @new-depth-affected);
						@new-stack = $dumb-tmp[1];
						@new-depth-affected = $dumb-tmp[2];
						return @new-stack, @new-depth-affected;
					}
				}
				die
			}
			
			when Expr-Node {
				my @new-scopes = @scopes;
				my @new-stack = @stack;
				my @new-depth-affected = @depth-affected;
				for $ast.val -> $expr-unit {
					if not $expr-unit.type == Bind-Node {
						my $dumb-tmp = run($expr-unit, @scopes)(@new-stack, @new-depth-affected);
						@new-stack = $dumb-tmp[0];
						@new-depth-affected = $dumb-tmp[1];
					} else {
						die if @new-stack.elems == 0;
						@new-scopes[*-1]{$expr-unit.val} = @new-stack[*-1];
						@new-stack = init(@new-stack);
						@new-depth-affected = depth-update(@new-depth-affected, 1, 0);
					}
				}
				@new-scopes, @new-stack, @new-depth-affected
			}
			
			when Patts-Node {
				my @new-scopes = @scopes;
				my @new-stack = @stack;
				my @new-depth-affected = @depth-affected;
				my @saved-vals = [];
				for $ast.val -> $patt {
					my $dumb-tmp = run($patt, @new-scopes)(@new-stack, append(@new-depth-affected, 0));
					@new-scopes = $dumb-tmp[0];
					my $save-num = $dumb-tmp[2][1];
					@new-stack = $dumb-tmp[1].head: *-$save-num;
					@saved-vals = concat($dumb-tmp[1].tail($save-num), @saved-vals);
					@new-depth-affected = depth-update([$dumb-tmp[2][0]], $save-num, 0);
				}
				@new-scopes, concat(@new-stack, @saved-vals), depth-update(@new-depth-affected, 0, @saved-vals.elems)
			}
			
			when Var-Decls-Node {
				my @new-scopes = @scopes;
				my @new-stack = @stack;
				my @new-depth-affected = @depth-affected;
				for $ast.val -> $decl {
					my $dumb-tmp = run($decl, @new-scopes)(@new-stack, @new-depth-affected);
					@new-scopes = $dumb-tmp[0];
					@new-stack = $dumb-tmp[1];
					@new-depth-affected = $dumb-tmp[2];
				}
				@new-scopes, @new-stack, @new-depth-affected
			}
			
			when Var-Decl-Node {
				my @new-scopes = @scopes;
				my @new-stack = @stack;
				my @new-depth-affected = @depth-affected;
				my $dumb-tmp = run($ast.val.def, @new-scopes)(@new-stack, @new-depth-affected);
				@new-stack = $dumb-tmp[1];
				@new-depth-affected = $dumb-tmp[2];
				$dumb-tmp = run($ast.val.name, @new-scopes)(@new-stack, @new-depth-affected);
				@new-scopes = $dumb-tmp[0];
				@new-stack = $dumb-tmp[1];
				@new-depth-affected = $dumb-tmp[2];
				@new-scopes, @new-stack, @new-depth-affected
			}
			
			when Pipe-Decl-Node {
				my @new-scopes = @scopes;
				@new-scopes[*-1]{$ast.val.name} = Val.new: type => Func-Val, val => run(AST.new(type => Func-Node, val => append($ast.val.def.val, Case-Data.new:
					patts => AST.new(type => Patts-Node, val => []),
					var-decls => AST.new(type => Var-Decls-Node, val => []),
					expr => AST.new(type => Expr-Node, val => [AST.new: type => Run-It-Node, val => @new-scopes[*-1]{$ast.val.name}.val]))), @new-scopes);
				@new-scopes, @stack, @depth-affected
			}
			
			when Complicated-Node {
				append(@stack, Val.new: type => Complicated-Val, val => $ast.val), depth-update(@depth-affected, 0, 1)
			}
			
			when Decimal-Node {
				append(@stack, Val.new: type => Decimal-Val, val => $ast.val), depth-update(@depth-affected, 0, 1)
			}
			
			when Integer-Node {
				append(@stack, Val.new: type => Integer-Val, val => $ast.val), depth-update(@depth-affected, 0, 1)
			}
			
			when Obj-Destr-Node {
				my $tag = $ast.val;
				$tag = 'Tup' if $tag eq '()';
				my $obj = @stack[*-1];
				given $obj.type {
					when Obj-Val {
						die if $obj.val.tag ne $tag;
						concat(init(@stack), $obj.val.vals.reverse), depth-update(@depth-affected, 1, $obj.val.vals.elems)
					}
					default { say 'NOT IMPLEMENTED YET AAA'; say $obj ; @stack, depth-update(@depth-affected, 1, 1) }
				}
			}
			
			when Obj-Make-Node {
				my $tag = $ast.val.tag;
				$tag = 'Tup' if $tag eq '()';
				my $obj-len = $ast.val.len;
				die if @stack.elems < $obj-len;
				given $tag {
					when 'Comp' {
						die if $obj-len != 2;
						my $y = @stack[*-1];
						my $x = @stack[*-2];
						die if not is-real-type($x.type) && is-real-type($y.type);
						CATCH { default { say 'Special object Comp can only take two items, which can be decimals or integers, for the real and imaginary components.'; die } }
						append(@stack.head(*-2), Val.new: type => Complicated-Val, val => $x.val + $y.val * i), depth-update(@depth-affected, 2, 1)
					}
					
					when 'Dec' {
						die if $obj-len != 2;
						my $y = @stack[*-1];
						my $x = @stack[*-2];
						die if $x.type != Integer-Val;
						die if $y.type != Decimal-Val || $y.val < 0 || $y.val >= 1;
						CATCH { default { say 'Special object Dec can only take two items, an integer and a decimal.'; die } }
						append(@stack.head(*-2), Val.new: type => Decimal-Val, val => $x.val + $y.val), depth-update(@depth-affected, 2, 1)
					}
					
					when 'Int' {
						die if $obj-len != 1;
						my $l = @stack[*-1];
						die if $l.type != Obj-Val;
						die if [||] $l.val.vals.map: { $_.type != Integer-Val };
						die if [||] $l.val.vals.map: { $_.val < 0 || $_.val > 9 };
						CATCH { default { say 'Special object Int can only take one item, and that is a list of digits.'; die } }
						append(init(@stack), Val.new: type => Integer-Val, val => $l.val.vals.map(*.val).join.Int), depth-update(@depth-affected, 1, 1);
					}
					
					when 'Str' {
						my @l = @stack.tail($obj-len).reverse;
						die if [||] @l.map: { $_.type != Integer-Val };
						CATCH { default { say 'Special object Str can only integers, which get turned into their unicode point.'; die } }
						append(@stack.head(*-$obj-len), Val.new: type => String-Val, val => @l.map(*.val).chrs), depth-update(@depth-affected, $obj-len, 1)
					}
					
					when 'Func' {
						say "Can\'t make Func objects sorry."; die
					}
					
					default {
						append(
							@stack.head(*-$obj-len),
							Val.new: type => Obj-Val, val => Obj-Data.new: tag => $tag, vals => @stack.tail($obj-len).reverse
						), depth-update(@depth-affected, $obj-len, 1)
					}
				}
			}
			
			when Ident-Node {
				get-var(@scopes, $ast.val).val()(@stack, @depth-affected)
			}
			
			when String-Node {
				append(@stack, Val.new: type => String-Val, val => $ast.val), depth-update(@depth-affected, 0, 1)
			}
			
			when Quote-Var-Node {
				append(@stack, get-var(@scopes, $ast.val.val)), depth-update(@depth-affected, 0, 1)
			}
			
			when Func-Expr-Node {
				append(@stack, Val.new: type => Func-Val, val => run($ast.val, @scopes)), depth-update(@depth-affected, 0, 1)
			}
			
			when Tuple-Node {
				my @tuple = [];
				my @new-stack = @stack;
				my @new-depth-affected = @depth-affected;
				for $ast.val -> $expr {
					my $dumb-tmp = run($expr, @scopes)(@new-stack, @new-depth-affected);
					@new-stack = $dumb-tmp[1];
					@new-depth-affected = $dumb-tmp[2];
					@tuple.push(@new-stack[*-1]);
					@new-stack = init(@new-stack);
					@new-depth-affected = depth-update(@new-depth-affected, 1, 0);
				}
				append(@new-stack, Val.new: type => Obj-Val, val => Obj-Data.new: tag => 'Tup', vals => @tuple), depth-update(@new-depth-affected, 0, 1)
			}
		}
	}
}

my $prelude = "
	do := \{fn-> fn} ;
	id := \{} ;
	
	dup := \{a-> 'a 'a} ;
	drop := \{_->} ;
	swap := \{a b-> 'a 'b} ;
	rot := \{a b c-> 'a 'c 'b} ;
	unrot := \{a b c-> 'b 'a 'c} ;
	dip := \{f-> swap f swap} ;
	
	map := \{_->} ;
	map |= \{f Some?-> f `Some} ;
	map |= \{f Right?-> f `Right} ;
	map |= \{f <<?-> f \{'f map} dip <<} ;
	
	foldr := \{k z-> go := \{>>?-> 'go dip k | _-> 'z} ; go} ;
	
	cat_maybes := \{() \{Some?-> >> | _->} foldr} ;
	map_maybe := \{map cat_maybes} ;
	
	either := \{f _ Left? -> f | _ g Right? -> g} ;
	lefts := \{\{Left? -> `Some | Right? _ -> None} map_maybe} ;
	rights := \{\{Right? -> `Some | Left? _ -> None} map_maybe} ;
	partition_eithers := \{
		left := \{l ()?-> ('l>>,)} ;
		right := \{r ()?-> (,'r>>)} ;
		((),()) \{'right 'left either} foldr} ;
	
	fib := \{2<? -> | dup 1 - fib swap 2 - fib +} ;
";

say run(Calc2.parse($prelude ~ get, actions => Calc2er).made, [])([], [0]) while True;
# say Calc2.parse($prelude ~ get, actions => Calc2er).made while True;
# say Calc2.parse: $prelude ~ get while True;