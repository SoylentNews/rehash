// Wolf

;(function( $ ){

// I guess you could say the algorithm is table-driven :-)
var	toString	= Object.prototype.toString,
	typeOfObject	= {
		'[object Date]':	'date',
		'[object Function]':	'function',
		'[object Number]':	'number',
		'[object RegExp]':	'regexp',
	},
	typeOfIndexedObject = {
		'[object Array]':	'array',
		'[object String]':	'string'
	},
	typeOfNode = [
		undefined,
		'node.element',
		'node.attribute',
		'node.text'
	],
	typeOfUnadorned = {
		'array.empty':		'array',
		'jquery.empty':		'jquery',
		'list.empty':		'list',
		'node.attribute':	'node',
		'node.document':	'document',
		'node.element':		'element',
		'node.text':		'node',
		'number.Infinity':	'number',
		'number.NaN':		'number',
		'object.empty':		'object',
		'string.char':		'string',
		'string.empty':		'string'
	},
	typeOfUnique	= {};

// 'singletons': the very first thing to check in _typeOf
typeOfUnique[document]	= 'node.document';
typeOfUnique[false]	= 'boolean';
typeOfUnique[Infinity]	= 'number.Infinity';
typeOfUnique[NaN]	= 'number.NaN';
typeOfUnique[null]	= 'null';
typeOfUnique[true]	= 'boolean';
typeOfUnique[undefined]	= 'undefined';
typeOfUnique[window]	= 'window';

function _inheritsProperty( o, expr ){
	return expr && expr in o && !o.propertyIsEnumerable(expr);
}

// Here's the core function.
function _typeOf( o, unadorned ){
	var cmp;
	if ( unadorned ) {
		if ( unadorned in _typeOf ) { return _typeOf[unadorned](o); }
		unadorned!==true && (cmp=unadorned) && (unadorned=false);
	}

	var otn, itn, utn, tn =
		typeOfUnique[ o ]
		|| typeOfObject[ otn=toString.call(o) ]
		|| !(itn=typeOfIndexedObject[otn]) && _inheritsProperty(o, 'nodeType') && (typeOfNode[o.nodeType] || 'node');

	if ( tn ) {
		utn = typeOfUnadorned[tn] || tn;
		return unadorned && utn || (!cmp || cmp===tn || cmp===utn) && tn;
	}

	utn = itn
		|| o instanceof $ && 'jquery'
		|| _inheritsProperty(o, 'length') && 'list';
	if ( unadorned ) { return utn || 'object'; }

	if ( utn ) {
		tn = !o.length && utn+'.empty'
			|| (o.length>1 || utn!=='string') && utn
			|| 'string.char';
	} else {
		utn = 'object';
		tn = 'object.empty';
		for ( k in o ){
			tn = 'object';
			break;
		}
	}
	return (!cmp || cmp===tn || cmp===utn) && tn;
};

function makeTest( fn ){
	return function( o, tn ){
		return !!fn(o, tn||(tn=_typeOf(o))) && tn;
	}
}
function makeCategoryTest( tlist ){
	var tdict = {};
	for ( var L=tlist.split(' '), i=L.length-1, k=L[i]; (tdict[k]=true) && i; k=L[--i]) {  }

	return makeTest(function( o, tn ){
		return tdict[ typeOfUnadorned[tn] || tn ];
	});
}

var _typeOfScalar, _typeOfInherited;

$['TypeOf'] = $.extend(_typeOf, {
	unadorned: function(o, tn){ return typeOfUnadorned[tn] || tn || _typeOf(o, true); },
	implementation: function(o){ return toString.call(o).match(/ (.+)]$/)[1]; },
	// Consider, e.g., var _typeOf = $.TypeOf.unadorned; if it otherwise feels too heavy.



	// Tests return a typename for success, false for failure.  Examples:
	//	"Hello, World!"	=> .scalar, .def, and .yes return 'string'; all others false
	//	0		=> .scalar, .def, .no, and .defNo return 'number'
	//	undefined	=> .scalar, .undef, and .no return 'undefined'
	//	{a:5, b:"bob"}	=> .nonScalar, .def, .yes, and .nonEmpty return 'object'
	//	$([])		=> .nonScalar, .def, .yes, and .list return 'jquery.empty'

	// type-tests
	scalar: _typeOfScalar=makeCategoryTest('boolean null number string undefined'),
	nonScalar: makeTest(function(o, tn){ return !_typeOfScalar(o, tn); }),
	list: makeCategoryTest('array jquery list'),
	node: makeCategoryTest('document element node'),
	fn: makeTest(function(o, tn){ return tn==='function'; }),

	// value-tests
	undef: makeTest(function(o){ return o===undefined; }),
	def: makeTest(function(o){ return o!==undefined; }),
	yes: makeTest(function(o){ return o; }),
	no: makeTest(function(o){ return !o; }),
	defNo: makeTest(function(o){ return o!==undefined && !o; }),
	nonEmpty: makeTest(function(o, tn){ return !_typeOfScalar(o, tn) && !(_typeOf(o) in typeOfUnadorned); }),

	// inheritance-tests
	// $.TypeOf.inherited(o, 'length') asks "Does o inherit the property 'length'?", returns the _typeOf o.length for success
	// $.TypeOf.inherited(o, Node) asks "Is o an instanceof Node?", returns the _typeOf o for success
	inherited: _typeOfInherited=function( o, expr ){
		return (typeof(expr)==='string'
			? (_inheritsProperty(o, expr) && (o=o[expr]))
			: o instanceof expr
		) && _typeOf(o);
	},
	inheritedFn: function(o, fname){ return _typeOfInherited(o, fname)==='function' && 'function'; },


	// All the tests above return the typename for success.
	// objIf returns the object for success, e.g., objIf('string', "Hello, World!") => "Hello, World!"
	objIf: function( tn, o ){
		if ( typeof(tn)==='string' && _typeOf(o, tn) ) {
			return o;
		}
	},

	// ...and now you can play along at home!
	makeTest: function( fn ){
		return function( o, tn ){
			var answer = fn(o, tn||(tn=_typeOf(o)));
			return !!answer && (typeof(answer)==='string' ? answer : tn);
		};
	}
});

})($);
