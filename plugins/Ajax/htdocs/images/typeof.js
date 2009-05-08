var  TypeOf;
(function(){
var U=void(0), N=null, W=window,
	OBJECT, FUNCTION, NUMBER,
	TYPEOF={}, TYPEOF_NODE=[], TYPEOF_SCALAR={}, TYPEOF_LIST={};

function otype( o, compare ){
	var ot;
	return o!==U
		&& o!==N
		&& (ot=Object.prototype.toString.call(o))
		&& (!compare || compare===ot)
		&& ot

		|| U;
}

function typeof_fn( o ){
	return otype(o, FUNCTION);
}

function typeof_node( o ){
	try {
		if ( o && o.nodeName ) {
			return TYPEOF_NODE[o.nodeType];
		}
	} catch ( e ) {
	}
}

function qualify_element( o ){
	var t = typeof_node(o);
	if ( t !== 'node' ) {
		return t==='element' && o.nodeName.toLowerCase()
			|| t;
	}
}

function qualify_node( o ){
	return qualify_element(o)
		|| typeof_node(o);
}

function intrusive_typeof( o ){
	// UNSAFE!! |o| must be defined and non-null
	return typeof_fn(o.__typeOf) && o.__typeOf();
}

function typeof_list( o ){
	var len;
	try {
		if ( o && !isNaN(len=o.length) && (!len || len-1 in o) ) {
			return 'list';
		}
	} catch ( e ) {
	}
}

TypeOf = function( o ){
	return TYPEOF[ typeof(o) ]
		|| o===N && 'null'
		|| TYPEOF[ otype(o) ]
		|| intrusive_typeof(o)
		|| typeof_node(o)
		|| o===W && 'window'
		|| typeof_list(o)
		|| 'object';
};
TypeOf.fn		= typeof_fn;
TypeOf.element	= qualify_element;
TypeOf.node		= qualify_node;
TypeOf.list		= function( o ){ return TYPEOF_LIST[ TypeOf(o) ]; };

TypeOf.number = function( o, all ){
	if ( otype(o, NUMBER) ) {
		return isFinite(o) && 'number'
			|| all && o.toString()
			|| U;
	}
};

TypeOf.scalar = function( o ){
	return TYPEOF_SCALAR[ typeof(o) ]
		|| o===N && 'null'
		|| U;
}

TypeOf.debug	= function(){ return TYPEOF; };


(function(){
	OBJECT		= otype({});
	FUNCTION	= otype(function(){});
	NUMBER		= otype(1);

	var ELEMENT_NODE=1, DOCUMENT_NODE=9, BROKEN=[ 'object', OBJECT ];
	for ( var i=0; i<=12; ++i ){
		TYPEOF_NODE[i] = 'node';
	}
	TYPEOF_NODE[ELEMENT_NODE] = 'element';
	TYPEOF_NODE[DOCUMENT_NODE] = 'document';

	var INIT = [
		{ o:undefined,												scalar:true,	list:false },
		{ o:false,													scalar:true,	list:false },
		{ o:0,														scalar:true,	list:false },
		{ o:'',														scalar:true,	list:true },
		{ o:function(){},															list:false },
		{ o:{} },
		{ o:[],									want:'array',						list:true },
		{ o:/./,			expect:'object',	want:'regexp',						list:false },
		{ o:new Date(),		expect:'object',	want:'date',						list:false },
		{ o:new Error(),	expect:'object',	want:'error',						list:false },
		{ o:document,							want:'document',					list:false },
		{ o:W,									want:'window',						list:false }
	];

	while ( INIT.length ){
		var	entry			= INIT.pop(),
			actual			= typeof(entry.o),
			actual_otype	= otype(entry.o),
			want			= entry.want||entry.expect||actual;

		entry.expect && actual!==entry.expect && BROKEN.push(actual);
		actual!=='object'		&& (TYPEOF[ actual ] = want);
		actual_otype!==OBJECT	&& (TYPEOF[ actual_otype ] = want);
		entry.scalar!==U		&& (TYPEOF_SCALAR[want] = want);
		entry.list!==U			&& (TYPEOF_LIST[want] = entry.list && want || U);
	}
	TYPEOF_LIST.list = 'list';

	while ( BROKEN.length ){
		delete TYPEOF[ BROKEN.pop() ];
	}
})();

})();
