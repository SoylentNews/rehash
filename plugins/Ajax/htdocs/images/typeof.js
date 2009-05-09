/* TypeOf(o), ...

Stand-alone.  Does not need jQuery (or anything else, for that matter).

Fixes some failures in the builtin typeof operator:

	TypeOf(null) => 'null'		typeof(null) => 'object'	Object.prototype.toString.call(null) => '[object Window]'
	TypeOf([]) => 'array'		typeof([]) => 'object'
	TypeOf(0/0) => 'NaN'		typeof(0/0) => 'number'

	Never uses instanceof, which fails across contexts.


Recognizes lists:

	TypeOf(arguments) => 'list'
	TypeOf(document.childNodes) => 'list'
	TypeOf(jQuery('span')) => 'list'
	TypeOf([]) => 'array'


Qualified calls, e.g., TypeOf.list(o), return a typename just as TypeOf(o) would, if o qualifies
(in this case, if o is a list) or else a result!=true.

	TypeOf.list("Hello, World") => 'string'
	TypeOf.list(7) => false
	TypeOf.list([]) => 'array'
	TypeOf.list(document.childNodes) => 'list'

	TypeOf.scalar("Hello, World!") => 'string'
	TypeOf.scalar([]) => false
	TypeOf.scalar(false) => 'boolean'
	TypeOf.scalar(0/0) => 'NaN'

	TypeOf.number("Hello, World!") => false
	TypeOf.number(Infinity) => 'Infinity'
	TypeOf.number(0/0) => 'NaN'
	TypeOf.number(1729) => 'number'

		TypeOf(o)==='number'		=> exclude NaN (i.e., typeof(o)==='number' && !isNaN(o))
		TypeOf.number(o)==='number'	=> exclude NaN and +/- Infinity (i.e., typeof(o)==='number' && isFinite(o))
		TypeOf.number(o)			=> include NaN, +/- Infinity (i.e., typeof(o)==='number')


Recognizes nodes:

	TypeOf(o) can return 'element', 'document', or 'node'
	TypeOf.element(o) will return the actual element kind, e.g., 'h1'
	TypeOf.node(o), similarly


Recognizes events:

	TypeOf(o) returns 'event'
	TypeOf.event(o) returns the actual event kind, e.g., 'click'

		You can write a function that can be used directly or as a click-handler:

		function close_widget( what ){
			switch ( TypeOf(what) ) {
				case 'event':	what=event.target;
				case 'element':	what=$(what).closest('.widget');
								what.hide();
			}
		}

Recognizes some "almost builtin" types:

	'date', 'regexp', 'error', 'window'


Does not, itself, modify any system objects... but if you want to, you can hang a __typeOf function
(returning a string) almost anywhere you like.  TypeOf considers this an "intrusive" type.

*/

var TypeOf;
(function(){
var U=void(0), N=null, W=window,
	NUM_T='number', LIST_T='list', EL_T='element', DOC_T='document', EVENT_T='event',
	KNOWN_TYPE={}, SCALAR_TYPE={}, LIST_TYPE={}, NODE_TYPE=[];


function TK( o ){
	var tk;
	return o===U && '[type undefined]'
		|| o===N && '[type null]'
		|| (tk=Object.prototype.toString.call(o))==='[object Number]' && isNaN(o) && '[type NaN]'
		|| tk;
}

function is_fn( o ){
	return TK(o)==='[object Function]';
}


function scalar_type( o ){
	return SCALAR_TYPE[ TK(o) ];
}
function qualify_number( o ){
	var t=typeof(o);
	return t===NUM_T && (isFinite(o) ? t : o.toString());
}


function maybe_list( o ){
	try { return !!o && qualify_number(n=o.length)===NUM_T && (!n || n-1 in o) && LIST_T; } catch ( e ) {}
}
function list_type( o ){
	var tk=TK(o);
	return tk in LIST_TYPE ? LIST_TYPE[ tk ] : maybe_list(o);
}


function maybe_node( o ){
	try { return !!o && o.nodeName && NODE_TYPE[ o.nodeType ]; } catch ( e ) {}
}
function qualify_node( o ){
	var t;
	return (t=maybe_node(o))===DOC_T && t
		|| t===EL_T && o.nodeName.toLowerCase()
		|| t && o.nodeName
		|| t;
}
function qualify_element( o ){
	return maybe_node(o)===EL_T && qualify_node(o);
}


function maybe_event( o ){
	return !!o && is_fn(o.preventDefault) && is_fn(o.stopPropagation) && EVENT_T;
}
function qualify_event( o ){
	return maybe_event(o) && o.type;
}


TypeOf = function( o ){
	return KNOWN_TYPE[ TK(o) ]
		|| is_fn(o.__typeOf) && o.__typeOf()
		|| o===W && 'window'
		|| maybe_node(o)
		|| maybe_event(o)
		|| maybe_list(o)
		|| 'object';
}
TypeOf.scalar	= scalar_type;
TypeOf.number	= qualify_number;
TypeOf.fn		= function( o ){ return is_fn(o) && 'function'; };
TypeOf.list		= list_type;
TypeOf.node		= qualify_node;
TypeOf.element	= qualify_element;
TypeOf.event	= qualify_event;

(function(){
	var i;

	for ( i=document.ELEMENT_NODE; i<=document.NOTATION_NODE; ++i ) {
		NODE_TYPE[ i ] = 'node';
	}
	NODE_TYPE[ document.ELEMENT_NODE ] = EL_T;
	NODE_TYPE[ document.DOCUMENT_NODE ] = DOC_T;


	function define( o, scalar, list, tn ){
		var tk=TK(o), unique=(tk!==TK({}));
		if ( unique ) {
			tn || (tn = tk.replace(/^\[.+ |\]$/g, '').toLowerCase());

			KNOWN_TYPE[ tk ] = tn;
			scalar!==U	&& (SCALAR_TYPE[ tk ] = tn);
			list!==U	&& (LIST_TYPE[ tk ] = list && tn);
		}
		return unique;
	}

	define(void(0),			true, false);
	define(null,			true, false);
	define(false,			true, false);
	define(0,				true, false);
	define(0/0,				true, false, 'NaN');
	define('',				true, true);

	define(function(){},	false, false);
	define([],				false, true);
	define(/./,				false, false);
	define(new Date(),		false, false);
	define(new Error(),		false, false);

	define(document,		false, false, DOC_T);
	define(window,			false, false, 'window');

	define(document.childNodes, false, true, LIST_T);
	define(arguments,		false, true, LIST_T);

	define(document.createEvent('UIEvents'),		false, false, EVENT_T);
	define(document.createEvent('MouseEvents'),		false, false, EVENT_T);
	define(document.createEvent('MutationEvents'),	false, false, EVENT_T);
	define(document.createEvent('HTMLEvents'),		false, false, EVENT_T);
})();

})();

