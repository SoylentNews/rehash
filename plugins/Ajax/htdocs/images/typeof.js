;(function( renames, context ){

context || (context=window);

var	name_for	= renames ? function(s){ var n=renames[s]; return n!==undefined ? n : s; } : function(s){ return s; },
	canonical_type	= {
		'array':	'array',
		'boolean':	'boolean',
		'document':	'document',
		'element':	'object',
		'function':	'function',
		'jquery':	'object',
		'list':		'list',
		'node':		'object',
		'null':		'null',
		'number':	'number',
		'object':	'object',
		'string':	'string',
		'undefined':	'undefined',
		'window':	'window'
	},
	type_categories	= {
		'scalar':	{ 'boolean':true, 'null':true, 'number':true, 'string':true, 'undefined':true },
		'ordered':	{ 'array':true, 'jquery':true, 'list':true, 'string':true },

		'array':	{ 'array':true },
		'boolean':	{ 'boolean':true },
		// defined
		'function':	{ 'function':true },
		'number':	{ 'number':true },
		'null':		{ 'null':true },
		'object':	{ 'document':true, 'element':true, 'jquery':true, 'node':true, 'object':true, 'window':true },	// perhaps you prefer !is_scalar(o)
		'string':	{ 'string':true },
		// undefined

		// jquery

		'document':	{ 'document':true },
		'domobject':	{ 'document':true, 'element':true, 'node':true },
		// element
		// node
		'window':	{ 'window':true }
	},
	toString	= Object.prototype.toString,
	toString_types	= {
		'[object Array]':	'array',
		'[object Boolean]':	'boolean',
		'[object Function]':	'function',
		'[object Number]':	'number',
		'[object Object]':	'object',
		'[object String]':	'string'
	},
	object_types	= {};

object_types[null]	= 'null';
object_types[undefined]	= 'undefined';
name_for('is_document')	&& (object_types[document] = 'document');
name_for('is_window')	&& (object_types[window] = 'window');

var _is_element, _is_node;
try {
	if ( name_for('is_element') && Element !== undefined ) {
		_is_element = function( o ){ return o instanceof Element; }
		canonical_type['element'] = 'element';
		type_categories['element'] = { 'element':true };
	}
	try {
		if ( name_for('is_node') && Node !== undefined ) {
			_is_node = function( o ){ return o instanceof Node; }
			canonical_type['node'] = 'node';
			type_categories['node'] = { 'element':true, 'node':true };
		}
	} catch ( e2 ) {
	}
} catch ( e1 ) {
}

var _is_jquery;
try {
	if ( name_for('is_jquery') && jQuery !== undefined ) {
		_is_jquery = function( o ){ return o instanceof jQuery; }
		canonical_type['jquery'] = 'jquery';
		type_categories['jquery'] = { 'jquery':true };
	}
} catch ( e0 ) {
}


function _typeof( o ){
	var tn = object_types[o] || toString_types[toString.call(o)];
	if ( tn === 'object' ) {
		if ( _is_jquery && _is_jquery(o) ) {
			tn = 'jquery';
		} else if ( o.length!==undefined && !o.propertyIsEnumerable('length') ) {
			tn = 'list';
		}
	} else if ( !tn ) {
		if ( _is_element && _is_element(o) ) {
			tn = 'element';
		} else if ( _is_node && _is_node(o) ) {
			tn = 'node';
		} else {
			tn = 'object';
		}
	}
	return canonical_type[tn];
}


function _bind( n, fn ){ var N=name_for(n); N && (context[N]=fn); }

for ( var category in type_categories ){
	(function(n, S){
		_bind(n, function( o, from_typename ){
			return S[ from_typename ? o : _typeof(o)] || false;
		});
	})('is_'+category, type_categories[category]);
}

_bind('_typeof',		_typeof);
_bind('raw_typeof',		function( o ){ var s=toString.call(o); return s.substr(8, s.length-9); });
_bind('is_undefined',		function( o ){ return o === undefined; });
_bind('is_defined',		function( o ){ return o !== undefined; });
_bind('inherits_property',	function( o, n ){ return n && n in o && !o.propertyIsEnumerable(n); });
_bind('inherits_function',	function( o, n ){ return n && _typeof(o[n])==='function' && !o.propertyIsEnumerable(n); });
_bind('sign',			function( o ){ return !o ? 0 : (o<0 && typeof(o)==='number' ? -1 : 1); });
_bind('is_nonempty', function( o ){
	var tn = _typeof(o);
	if ( tn in type_categories.ordered ) {
		return o.length > 0;
	}
	if ( !(tn in type_categories.scalar) ) {
		for ( var k in o ){
			return true;
		}
	}
	return false;
});

})({	// _typeof
	// raw_typeof

	'is_defined':		'is_def',
	'is_undefined':		'is_undef',

	// is_scalar
	'is_ordered':		'is_list',

	// is_array
	'is_boolean':		'is_bool',
	'is_function':		'is_fn',
	'is_number':		'is_num',
	// is_null
	'is_object':		'is_obj',
	'is_string':		'is_str',

	// is_jquery

	// is_document
	'is_domobject':		'is_dom',
	'is_element':		'is_elem',
	// is_node
	// is_window

	// inherits_property
	// inherits_function

	'is_nonempty':		'non_empty'
	// sign
});
