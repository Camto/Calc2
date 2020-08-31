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
		|| <comment>
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
	token comment { '#' <-[\n]>* }
	
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
	
	method comment($match) {
		$match.make: AST.new: type => Func-Node, val => [
			Case-Data.new:
				patts => AST.new(type => Patts-Node, val => []),
				var-decls => AST.new(type => Var-Decls-Node, val => []),
				expr => AST.new(type => Expr-Node, val => [])
		]
	}
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

sub print-val(Val $val) {
	given $val.type {
		when Obj-Val {
			if $val.val.tag eq 'Tup' {
				"({$val.val.vals.map(&print-val).join: ', '})"
			} elsif $val.val.vals.elems > 0 {
				"{$val.val.vals.map(&print-val).reverse.join: ' '} {'`' x $val.val.vals.elems}{$val.val.tag}"
			} else {
				$val.val.tag
			}
		}
		when Complicated-Val { $val.val.Str }
		when Decimal-Val { $val.val.Str }
		when Integer-Val { $val.val.Str }
		when String-Val { $val.val }
		when Func-Val { '{ <function body> }' }
	}
}

my %built-ins = {
	
	# All the operators.
	
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
		die if $x.type != Obj-Val;
		append(@stack.head(*-2), Val.new: type => Obj-Val, val => Obj-Data.new: tag => $x.val.tag, vals => append($x.val.vals, $y)), depth-update(@depth-affected, 2, 1)
	},

	cons => sub (@stack, @depth-affected) {
		die if @stack.elems < 2;
		my $y = @stack[*-1];
		my $x = @stack[*-2];
		die if $x.type != Obj-Val;
		append(@stack.head(*-2), Val.new: type => Obj-Val, val => Obj-Data.new: tag => $x.val.tag, vals => prepend($x.val.vals, $y)), depth-update(@depth-affected, 2, 1)
	},
	
	cat => sub (@stack, @depth-affected) {
		die if @stack.elems < 2;
		my $y = @stack[*-1];
		my $x = @stack[*-2];
		die if $x.type != Obj-Val;
		die if $y.type != Obj-Val;
		die if $x.val.tag ne $y.val.tag;
		append(@stack.head(*-2), Val.new: type => Obj-Val, val => Obj-Data.new: tag => $x.val.tag, vals => concat($x.val.vals, $y.val.vals)), depth-update(@depth-affected, 2, 1)
	},
	
	safe => sub (@stack, @depth-affected) {
		die if @stack.elems < 1;
		my $x = @stack[*-1];
		die if $x.type != Func-Val;
		my $safe-res = Val.new: type => Obj-Val, val => Obj-Data.new: tag => 'None', vals => [];
		try {
			my $dumb-tmp = $x.val()(init(@stack), [0]);
			my $some-val = Val.new: type => Obj-Val, val => Obj-Data.new: tag => 'Tup', vals => $dumb-tmp[0].tail($dumb-tmp[1][0]).reverse;
			$safe-res = Val.new: type => Obj-Val, val => Obj-Data.new: tag => 'Some', vals => [$some-val];
		}
		append(init(@stack), $safe-res), depth-update(@depth-affected, 1, 1)
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
		die if $l.type != Obj-Val || $l.val.vals.elems < 1;
		concat(init(@stack), [Val.new(type => Obj-Val, val => Obj-Data.new: tag => $l.val.tag, vals => init($l.val.vals)), $l.val.vals[*-1]]), depth-update(@depth-affected, 1, 2)
	},
	
	'cons?' => sub (@stack, @depth-affected) {
		die if @stack.elems < 1;
		my $l = @stack[*-1];
		die if $l.type != Obj-Val || $l.val.vals.elems < 1;
		concat(init(@stack), [Val.new(type => Obj-Val, val => Obj-Data.new: tag => $l.val.tag, vals => $l.val.vals.tail(*-1)), $l.val.vals[0]]), depth-update(@depth-affected, 1, 2)
	},
	
	# End of operators, here are normal builtins.
	
	# THE ALMIGHTY EVAL!
	eval => sub (@stack, @depth-affected) {
		die if @stack.elems < 1;
		my $prog = @stack[*-1];
		die if $prog.type != String-Val;
		my @eval-res = run(Calc2.parse($prog.val, actions => Calc2er).made, [])([], [0])[0];
		die if @eval-res[0] eqv False;
		append(init(@stack), Val.new: type => Obj-Val, val => Obj-Data.new: tag => 'Tup', vals => @eval-res.reverse), depth-update(@depth-affected, 1, 1)
	},
	
	# Generic object functions.
	
	'any?' => sub (@stack, @depth-affected) {
		die if @stack.elems < 1;
		my $obj = @stack[*-1];
		die if $obj.type != Obj-Val;
		concat(init(@stack), $obj.val.vals.reverse), depth-update(@depth-affected, 1, $obj.val.vals.elems)
	},
	
	tag => sub (@stack, @depth-affected) {
		die if @stack.elems < 1;
		my $obj = @stack[*-1];
		die if $obj.type != Obj-Val;
		append(init(@stack), Val.new: type => String-Val, val => $obj.val.tag), depth-update(@depth-affected, 1, 1)
	},
	
	len => sub (@stack, @depth-affected) {
		die if @stack.elems < 1;
		my $obj = @stack[*-1];
		die if $obj.type != Obj-Val;
		append(init(@stack), Val.new: type => Integer-Val, val => $obj.val.vals.elems), depth-update(@depth-affected, 1, 1)
	},
	
	make_obj => sub (@stack, @depth-affected) {
		die if @stack.elems < 2;
		my $tag = @stack[*-1];
		my $len = @stack[*-2];
		die if $tag.type != String-Val || $len.type != Integer-Val;
		die if @stack.elems < 2 + $len.val;
		my $obj = Val.new: type => Obj-Val, val => Obj-Data.new: tag => $tag.val, vals => @stack.head(*-2).tail($len.val).reverse;
		append(@stack.head(*-(2 + $len.val)), $obj), depth-update(@depth-affected, 2 + $len.val, 1)
	},
	
	# Math functions.
	
	re => sub (@stack, @depth-affected) {
		die if @stack.elems < 1;
		my $x = @stack[*-1];
		die if not is-num-type($x.type);
		append(init(@stack), Val.new(type => Decimal-Val, val => $x.val.Complex.re)), depth-update(@depth-affected, 1, 1)
	},
	
	im => sub (@stack, @depth-affected) {
		die if @stack.elems < 1;
		my $x = @stack[*-1];
		die if not is-num-type($x.type);
		append(init(@stack), Val.new(type => Decimal-Val, val => $x.val.Complex.im)), depth-update(@depth-affected, 1, 1)
	},
	
	round => sub (@stack, @depth-affected) {
		die if @stack.elems < 1;
		my $x = @stack[*-1];
		die if not is-real-type($x.type);
		append(init(@stack), Val.new(type => Integer-Val, val => $x.val.round)), depth-update(@depth-affected, 1, 1)
	},
	
	ceil => sub (@stack, @depth-affected) {
		die if @stack.elems < 1;
		my $x = @stack[*-1];
		die if not is-real-type($x.type);
		append(init(@stack), Val.new(type => Integer-Val, val => $x.val.ceiling)), depth-update(@depth-affected, 1, 1)
	},
	
	floor => sub (@stack, @depth-affected) {
		die if @stack.elems < 1;
		my $x = @stack[*-1];
		die if not is-real-type($x.type);
		append(init(@stack), Val.new(type => Integer-Val, val => $x.val.floor)), depth-update(@depth-affected, 1, 1)
	},
	
	rand => sub (@stack, @depth-affected) {
		die if @stack.elems < 1;
		my $x = @stack[*-1];
		die if not is-real-type($x.type);
		append(init(@stack), Val.new(type => Decimal-Val, val => $x.val.rand)), depth-update(@depth-affected, 1, 1)
	},
	
	cos => sub (@stack, @depth-affected) {
		die if @stack.elems < 1;
		my $x = @stack[*-1];
		die if not is-num-type($x.type);
		append(init(@stack), Val.new(type => $x.type, val => $x.val.cos)), depth-update(@depth-affected, 1, 1)
	},
	
	sin => sub (@stack, @depth-affected) {
		die if @stack.elems < 1;
		my $x = @stack[*-1];
		die if not is-num-type($x.type);
		append(init(@stack), Val.new(type => $x.type, val => $x.val.sin)), depth-update(@depth-affected, 1, 1)
	},
	
	tan => sub (@stack, @depth-affected) {
		die if @stack.elems < 1;
		my $x = @stack[*-1];
		die if not is-num-type($x.type);
		append(init(@stack), Val.new(type => $x.type, val => $x.val.tan)), depth-update(@depth-affected, 1, 1)
	},
	
	sec => sub (@stack, @depth-affected) {
		die if @stack.elems < 1;
		my $x = @stack[*-1];
		die if not is-num-type($x.type);
		append(init(@stack), Val.new(type => $x.type, val => $x.val.sec)), depth-update(@depth-affected, 1, 1)
	},
	
	csc => sub (@stack, @depth-affected) {
		die if @stack.elems < 1;
		my $x = @stack[*-1];
		die if not is-num-type($x.type);
		append(init(@stack), Val.new(type => $x.type, val => $x.val.cosec)), depth-update(@depth-affected, 1, 1)
	},
	
	cot => sub (@stack, @depth-affected) {
		die if @stack.elems < 1;
		my $x = @stack[*-1];
		die if not is-num-type($x.type);
		append(init(@stack), Val.new(type => $x.type, val => $x.val.cotan)), depth-update(@depth-affected, 1, 1)
	},
	
	log => sub (@stack, @depth-affected) {
		die if @stack.elems < 2;
		my $y = @stack[*-1];
		my $x = @stack[*-2];
		die if not is-num-type($x.type) && is-num-type($y.type);
		append(@stack.head(*-2), Val.new(type => max-num-type(Decimal-Val, max-num-type($x.type, $y.type)), val => $x.val.log($y.val))), depth-update(@depth-affected, 2, 1)
	},
	
	ln => sub (@stack, @depth-affected) {
		die if @stack.elems < 1;
		my $x = @stack[*-1];
		die if not is-num-type($x.type);
		append(init(@stack), Val.new(type => max-num-type(Decimal-Val, $x.type), val => $x.val.log)), depth-update(@depth-affected, 1, 1)
	},
	
	# List and string functions.
	
	nth => sub (@stack, @depth-affected) {
		die if @stack.elems < 2;
		my $idx = @stack[*-1];
		my $ls = @stack[*-2];
		die if $idx.type != Integer-Val;
		die if $ls.type != Obj-Val;
		die if $idx.val < 0 || $idx.val >= $ls.val.vals.elems;
		append(@stack.head(*-2), $ls.val.vals[$idx.val]), depth-update(@depth-affected, 2, 1)
	},
	
	slice => sub (@stack, @depth-affected) {
		die if @stack.elems < 3;
		my $t = @stack[*-1];
		my $f = @stack[*-2];
		my $ls = @stack[*-3];
		die if $f.type != Integer-Val || $t.type != Integer-Val || $ls.type != Obj-Val;
		die if $f.val < 0 || $t.val < 0;
		die if $t.val > $ls.val.vals.elems;
		die if $f.val > $t.val;
		append(@stack.head(*-3), Val.new: type => Obj-Val, val => Obj-Data.new: tag => $ls.val.tag, vals => $ls.val.vals[$f.val ..^ $t.val]), depth-update(@depth-affected, 3, 1)
	},
	
	join => sub (@stack, @depth-affected) {
		die if @stack.elems < 2;
		my $joiner = @stack[*-1];
		my $ls = @stack[*-2];
		die if $joiner.type != String-Val;
		die if $ls.type != Obj-Val;
		die if [||] $ls.val.vals.map: { $_.type != String-Val };
		append(@stack.head(*-2), Val.new: type => String-Val, val => $ls.val.vals.map({ $_.val }).join($joiner.val)), depth-update(@depth-affected, 2, 1)
	},
	
	split => sub (@stack, @depth-affected) {
		die if @stack.elems < 2;
		my $splitter = @stack[*-1];
		my $s = @stack[*-2];
		die if $splitter.type != String-Val || $s.type != String-Val;
		my $split = $s.val.split($splitter.val);
		$split = init($split).tail(*-1) if $splitter.val eq "";
		my $ls = Val.new: type => Obj-Val, val => Obj-Data.new: tag => 'Tup', vals => $split.map: { Val.new: type => String-Val, val => $_ };
		append(@stack.head(*-2), $ls), depth-update(@depth-affected, 2, 1)
	},
	
	num_to_str => sub (@stack, @depth-affected) {
		die if @stack.elems < 1;
		my $n = @stack[*-1];
		die if not is-num-type($n.type);
		append(init(@stack), Val.new: type => String-Val, val => $n.val.Str), depth-update(@depth-affected, 1, 1)
	},
	
	str_to_num => sub (@stack, @depth-affected) {
		die if @stack.elems < 1;
		my $s = @stack[*-1];
		die if $s.type != String-Val;
		my $n;
		given $s.val {
			when / ^ [\d+ ['.' \d+]? ['+' || '-']]? \d+ ['.' \d+]? 'i' $ / {
				$n = Val.new: type => Complicated-Val, val => $s.val.Complex;
			}
			when / ^ \d+ '.' \d+ $ / {
				$n = Val.new: type => Decimal-Val, val => $s.val.Num;
			}
			when / ^ \d+ $ / {
				$n = Val.new: type => Integer-Val, val => $s.val.Int;
			}
			default { die; }
		}
		append(init(@stack), $n), depth-update(@depth-affected, 1, 1)
	},
	
	# I/O functions.
	
	input => sub (@stack, @depth-affected) {
		append(@stack, Val.new: type => String-Val, val => get), depth-update(@depth-affected, 0, 1)
	},
	
	print => sub (@stack, @depth-affected) {
		die if @stack.elems < 1;
		my $val = @stack[*-1];
		say print-val($val);
		init(@stack), depth-update(@depth-affected, 1, 0)
	},
	
	print_no_nl => sub (@stack, @depth-affected) {
		die if @stack.elems < 1;
		my $val = @stack[*-1];
		print print-val($val);
		init(@stack), depth-update(@depth-affected, 1, 0)
	},
	
	read => sub (@stack, @depth-affected) {
		die if @stack.elems < 1;
		my $name = @stack[*-1];
		die if $name.type != String-Val;
		append(init(@stack), Val.new: type => String-Val, val => slurp $name.val), depth-update(@depth-affected, 1, 1)
	},
	
	write => sub (@stack, @depth-affected) {
		die if @stack.elems < 2;
		my $name = @stack[*-1];
		my $contents = @stack[*-2];
		die if $name.type != String-Val || $contents.type != String-Val;
		spurt $name.val, $contents.val;
		@stack.head(*-2), depth-update(@depth-affected, 2, 0)
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
					my $save-num = $dumb-tmp[2].tail;
					@new-stack = $dumb-tmp[1].head: *-$save-num;
					@saved-vals = concat($dumb-tmp[1].tail($save-num), @saved-vals);
					@new-depth-affected = depth-update(init($dumb-tmp[2]), $save-num, 0);
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
					expr => AST.new(type => Expr-Node, val => [AST.new: type => Run-It-Node, val => get-var(@new-scopes, $ast.val.name).val]))), @new-scopes);
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
				die if @stack.elems < 1;
				my $tag = $ast.val;
				$tag = 'Tup' if $tag eq '()';
				my $obj = @stack[*-1];
				die if $obj.type != Obj-Val || $obj.val.tag ne $tag;
				concat(init(@stack), $obj.val.vals.reverse), depth-update(@depth-affected, 1, $obj.val.vals.elems)
			}
			
			when Obj-Make-Node {
				my $tag = $ast.val.tag;
				$tag = 'Tup' if $tag eq '()';
				my $obj-len = $ast.val.len;
				die if @stack.elems < $obj-len;
				append(
					@stack.head(*-$obj-len),
					Val.new: type => Obj-Val, val => Obj-Data.new: tag => $tag, vals => @stack.tail($obj-len).reverse
				), depth-update(@depth-affected, $obj-len, 1)
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

run(Calc2.parse(slurp('Prelude.c2') ~ slurp('Repl.c2'), actions => Calc2er).made, [])([], [0])[0];
# say Calc2.parse(get, actions => Calc2er).made while True;
# say Calc2.parse: get while True;