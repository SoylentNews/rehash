// slash.util.js

;(function( $ ){ // global setup
window.Slash || (window.Slash = {});
Slash.jQuery = $;

$.ajaxSetup({
	url:	'/ajax.pl',
	type:	'POST',
	contentType: 'application/x-www-form-urlencoded'
});

})(jQuery);

// non-evil eval().  If you don't want a result, call $.globalEval(script) directly instead.
// Note: the eval()'d script will NOT be executed in the context of your closure.
// ...and that's a GOOD thing!
window.evalExpr = function( json ){
	var key, results=window.evalExpr, result;
	if ( json && /\S/.test(json) ) {
		key = 'evalExpr_'+new Date().getTime();
		$.globalEval('window.evalExpr.'+key+' = '+json);

		if ( key in results ) {
			result = results[key];
			delete results[key];
		}
	}
	return result;
}


var Qw;
(function(){
var ANY_WS=/\s+/, OUTER_WS=/^\s+|\s+$/g;

function clean( qw ){
	if ( typeof(qw)==='string' && (qw=qw.replace(OUTER_WS, '')) ) {
		qw = qw.split(ANY_WS);
	}
	return qw;
}

function make_array( qw ){
	if ( !(qw=clean(qw)) ) { return []; }
	if ( !TypeOf.list(qw) ) {
		qw = core.reduce(qw, [], function( k, v ){
			v && this.push(k);
		});
	} // else qw already _is_ an array
	return qw;
}

function make_set( qw ){
	if ( !(qw=clean(qw)) ) { return {}; }
	if ( TypeOf.list(qw) ) {
		qw = core.reduce(qw, {}, function( i, v ){
			this[v] = true;
		});
	} // else qw already _is_ a set
	return qw;
}

function make_string( qw ){
	return typeof(qw)==='string'
		? qw.replace(OUTER_WS, '')
		: make_array(qw).join(' ');
}

Qw = $.extend(make_array, {
	as_array:	make_array,
	as_set:		make_set,
	as_string:	make_string
});
})();


var fhitem_info, fhitem_key;
(function( $ ){
var KEY_TYPE=/\bsd-key-([-a-z]+)/i;

fhitem_info = function( item, type ){
	return $('span.sd-info-block span.'+type, item).text();
}

fhitem_key = function( item ){
	var result;
	$('span.sd-info-block span[class^=sd-key-]', item).each(function(){
		result = {
			key:		this.textContent,
			key_type:	KEY_TYPE.exec(this.className)[1]
		};
		return false;
	});
	return result;
}
})(jQuery);


$.fn.extend({
	getClass: function(){ return this.attr('className'); },
	setClass: function( expr ){
		if ( !expr || !expr.call ) {
			return this.attr('className', expr);
		} else {
			return this.each(function(){
				this.className = Qw.as_string(expr.call(this, Qw.as_set(this.className)));
			});
		}
	}
});

// not exactly sure what to do with these yet

function sign( o ){ return TypeOf.number(o) && o<0 && -1 || (o ? 1 : 0); }

function between( lo, o, hi ){ if ( lo<=hi ) { return o<lo && -1 || o>hi && 1 || 0; } }
function pin_between( lo, o, hi ){
	var b = between(lo, o, hi);
	if ( b !== undefined ) {
		return arguments[ 1 + between(lo, o, hi) ];
	}
}

// Use in setClass, maybe elsewhere.
// map: name=>state, state<0 means toggle, !state means remove, otherwise add
// Loops over the map (not the existing names).  Preserves unmapped names.
function applyToggle( map ){
	return function( names ){
		$.each(map, function( k, v ){ names[k] = (v=sign(v))<0 ? !names[k] : v; });
		return names;
	};
}

// Use in setClass, maybe elsewhere.
// map: { oldName0:newName0, oldName1:newName1, ... }
// Loops over the existing names (not the map); only mappings for those names apply.
// If that seems wrong to you, you probably wanted applyToggle instead.
// applyMap( 'str0', 'str1', 'str2', ... 'strN' ) is equivalent to applyMap({'str0':'str1', 'str1':'str2', ... 'strN-1':'strN', 'strN':'str0'})
function applyMap(){

	// I expect a hash; but I can settle for a list of strings.
	var map={}, N=arguments.length;
	if ( N > 1 ) {
		for ( var i=0; i<N; ++i ){
			map[ arguments[i] ] = arguments[ (i+1)%N ];
		}
	} else {
		map = arguments[0];
	}

	return function( old_names ){
		var new_names={};
		$.each(old_names, function( k, v ){ new_names[ map[k]||k ] = v; });
		return new_names;
	};
}


// $any(expr) is a compatibility routine.  Use it where you need a jQuery selection, but
// you may have been called with a DOM element, an unadorned element id (string), or a
// a jQuery selection, e.g., where you're fixing an old function and adding new callers,
// but aren't yet ready to change all the old callers, too.

// A side benefit: $(document.getElementById(id)) is faster than $('#'+id) and always
// will be (at least while jQuery isn't actually built in to the browser).
function $any( expr ){
	var el;
	return !expr && $([]) || typeof(expr)==='string' && (el=document.getElementById(expr)) && $(el) || $(expr);
}
function elemAny( expr ){ return $any(expr)[0]; }
var $dom = elemAny;
