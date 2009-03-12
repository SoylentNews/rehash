// Wolf

;(function( $ ){

// I guess you could say the algorithm is table-driven :-)
var	objToString = Object.prototype.toString,
	objectTypes = {
		'[object Date]':	'date',
		'[object Function]':	'function',
		'[object Number]':	'number',
		'[object RegExp]':	'regexp'
	},
	orderedObjectTypes = {
		'[object Array]':	'array',
		'[object String]':	'string'
	},
	nodeTypes = [
		undefined,
		'node.element',
		'node.attribute',
		'node.text'
	],
	unqualifyTypes = {
		'array.empty':		'array',
		'array':		'array',
		'boolean':		'boolean',
		'document':		'document',
		'element':		'element',
		'jquery.empty':		'jquery',
		'jquery':		'jquery',
		'list.empty':		'list',
		'list':			'list',
		'node.attribute':	'node',
		'node.document':	'document',
		'node.element':		'element',
		'node.text':		'node',
		'node':			'node',
		'null':			'null',
		'number.-Infinity':	'number',
		'number.Infinity':	'number',
		'number.NaN':		'number',
		'number':		'number',
		'object.empty':		'object',
		'object':		'object',
		'screen':		'screen',
		'string.char':		'string',
		'string.empty':		'string',
		'string':		'string',
		'undefined':		'undefined',
		'window':		'window'
	},
	singletonTypes = {};

// 'singletons': the very first thing to check in _typeOf
singletonTypes[document]	= 'node.document';
singletonTypes[false]		= 'boolean';
singletonTypes[Infinity]	= 'number.Infinity';
singletonTypes[-Infinity]	= 'number.-Infinity';
singletonTypes[NaN]		= 'number.NaN';
singletonTypes[null]		= 'null';
singletonTypes[true]		= 'boolean';
singletonTypes[undefined]	= 'undefined';
singletonTypes[window]		= 'window';

window.screen && (singletonTypes[window.screen] = 'screen');

function _inheritsProperty( o, expr ){
	return expr && o && expr in o && !o.propertyIsEnumerable(expr);
}

// Here's the core function.
function _typeOf( o, unq ){
	var cmp;
	if ( unq ) {
		unq in _typeOf && (unq=_typeOf[unq]);
		if ( typeof(unq)==='function' ) { return unq.call(_typeOf, o, arguments[2]); }
		unq!==true && (cmp=unq) && (unq=false);
	}

	var ots, oot, ut, t =
		singletonTypes[ o ]
		|| objectTypes[ ots=objToString.call(o) ]
		|| typeof(o.__typeOf)==='function' && o.__typeOf(unq)
		|| !(oot=orderedObjectTypes[ots]) && _inheritsProperty(o, 'nodeType') && (nodeTypes[o.nodeType] || 'node');

	if ( t ) {
		ut = unqualifyTypes[t] || t;
		return unq && ut || (!cmp || cmp===t || cmp===ut) && t;
	}

	ut = oot
		|| o instanceof $ && 'jquery'
		|| _inheritsProperty(o, 'length') && 'list';
	if ( unq ) { return ut || 'object'; }

	if ( ut ) {
		t = !o.length && ut+'.empty'
			|| (o.length>1 || ut!=='string') && ut
			|| 'string.char';
	} else {
		ut = 'object';
		t = 'object.empty';
		for ( k in o ){
			t = 'object';
			break;
		}
	}
	return (!cmp || cmp===t || cmp===ut) && t;
};

function makeTest( test ){
	var type_list = test;
	switch ( typeof(test) ) {
		case 'function':
			return function( o, t, unq ){
				var success = test.call(_typeOf, o, t||(t=_typeOf(o)), unq);
				return !!success && (typeof(success)==='string' ? success : t);
			};
		case 'string':
			type_list = test.split(/[ ,|]/);
		case 'array':
			test={};
			for ( var i=type_list.length-1, k=type_list[i]; (test[k]=true) && i; k=type_list[--i]) {  }
		case 'object':
			return function( o, t, unq ){
				t || (t=_typeOf(o, unq));
				return !!test[ unqualifyTypes[t] || t ] && t;
			};
	}
}

var objToString_pattern = / (.+)]$/;

$.TypeOf = $.extend(_typeOf, {
	qualified: function( o ){ return _typeOf(o, false); },
	unqualified: function( o ){ return _typeOf(o, true); },
	object: function( o ){ return objToString.call(o).match(objToString_pattern)[1] || false; },
	// Consider, e.g., var _typeOf = $.TypeOf.unqualified; if it otherwise feels too heavy.

	unqualify: function( t ){ return unqualifyTypes[t] || arguments.length>1 && _typeOf(arguments[1], true) || t; },



	// Tests return a typename for success, false for failure.  Examples:
	//	"Hello, World!"	=> .scalar, .def, and .yes return 'string'; all others false
	//	0		=> .scalar, .def, .no, and .defNo return 'number'
	//	undefined	=> .scalar, .undef, and .no return 'undefined'
	//	{a:5, b:"bob"}	=> .def, .yes, and .nonEmpty return 'object'
	//	$([])		=> .def, .yes, and .list return 'jquery.empty'

	// type-tests
	scalar: makeTest('boolean|null|number|string|undefined'),
	list: makeTest('array|jquery|list'),
	node: makeTest('document|element|node'),
	fn: makeTest(function( o, t ){ return t==='function'; }),

	// value-tests
	undef: makeTest(function( o ){ return o===undefined; }),
	def: makeTest(function( o ){ return o!==undefined; }),
	yes: makeTest(function( o ){ return !!o; }),
	no: makeTest(function( o ){ return !o; }),
	defNo: makeTest(function( o ){ return o!==undefined && !o; }),
	nonEmpty: makeTest(function( o, t ){ return !_typeOf.scalar(o, t) && (t=_typeOf(o))===unqualifyTypes[t]; }),

	// inheritance-tests
	// $.TypeOf.inherited(o, 'length') asks "Does o inherit the property 'length'?", returns the _typeOf o.length for success
	// $.TypeOf.inherited(o, Node) asks "Is o an instanceof Node?", returns the _typeOf o for success
	inherited: function( o, expr ){
		return (typeof(expr)==='string'
			? (_inheritsProperty(o, expr) && (o=o[expr]))
			: o instanceof expr
		) && _typeOf(o);
	},
	inheritedFn: function( o, fname ){ return _typeOf.inherited(o, fname)==='function' && 'function'; },


	// meta-tests, N.B.: typename is _first_, e.g., $.TypeOf.not('scalar', o)
	// is: function( t, o, unq ){ return _typeOf(o, t, unq); },
	not: function( t, o, unq ){ return !_typeOf(o, t) && _typeOf(o, unq); },

	// All the tests above return the typename for success.
	// objIf returns the object for success, e.g., objIf('string', "Hello, World!") => "Hello, World!"
	objIf: function( t, o ){
		if ( typeof(t)==='string' && _typeOf(o, t) ) {
			return o;
		}
	},

	// ...and now you can play along at home!
	makeTest: makeTest
});

})($);
