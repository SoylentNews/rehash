;(function($){

// global setup

$.ajaxSetup({
	url:	'/ajax.pl',
	type:	'POST',
	contentType: 'application/x-www-form-urlencoded'
});


var T=$.TypeOf;

// code to be exported

function each( o, fn ){
	var non_empty = T.nonEmpty(o);
	if ( T.list(o, non_empty) ) {
		for ( var i=0, N=o.length, v=o[i]; i<N && !T.defNo(fn.call(v, i, v)); v=o[++i] ) {  }
	} else if ( non_empty ) {
		for ( var k in o ) {
			if ( T.defNo(fn.call(o[k], k, o[k])) ) {
				break;
			}
		}
	}
}


function clone( o ){
	if ( o===undefined || o===null ) { return o; }

	var tn = T(o);
	if ( T.scalar(o, tn) ) { return o.valueOf(); };

	var o2;
	if ( tn==='function' ) {
		// if it's a function, I'll have to cheat...
		// extract the source code for the function
		var S = o.toString();
		// arguments first...
		var ctor_args = S.substring(S.indexOf('(')+1, S.indexOf(')')).split(/\s*,\s*/);
		// ...then the contents of the body
		ctor_args.push(S.substring(S.indexOf('{')+1, S.lastIndexOf('}')));
		// and compile a new function from that
		o2 = Function.constructor.apply(null, ctor_args);
	} else {
		// any other kind of object can reproduce
		o2 = new o.constructor();
	}

	if ( T.nonEmpty(o, tn) ) {
		// ...as long as we're willing to copy all the properties (even works on arrays)
		// and key that we do this for functions as well... they can have properties
		each(o, function(k, v){
			o2[k] = clone(v);
		});
	}
	return o2;
}

function accumulate( initial_value, accumulate_fn, collection /* [, collection]+ */ ){
	var others = Array.prototype.slice.call(arguments, 3);
	var if_others = others.length > 0;

	var o = initial_value;
	each(collection, function(k, v){
		var args = [k, v];
		if ( if_others ) {
			each(others, function(i, other){
				args.push(other[k]);
			});
		}
		accumulate_fn.apply(o, args);
	});
	return o;
}

function keys(obj){
	return accumulate([], function(k){ this.push(k); }, obj);
}

function values(obj){
	return accumulate([], function(k, v){ this.push(v); }, obj);
}

function qw_as_array( qw ){
	if ( ! qw ) { return []; }

	if ( T(qw, 'string') ) {
		qw = $.map(qw.split(/\s+/), function(w){if(w)return w;});
	}
	if ( T.not('list', qw) ) {
		qw = accumulate([], function(k, v){if(v){this.push(k);}}, qw);
	}
	// else: qw already _is_ an array

	return qw;
}

function qw_as_set( qw ){
	if ( ! qw ) { return {}; }

	if ( T(qw, 'jquery') || T(qw, 'string') ) {
		qw = qw_as_array(qw);
	}
	if ( T.list(qw) ) {
		qw = accumulate({}, function(k,v){this[v]=true;}, qw);
	}
	// else qw already _is_ a set

	return qw;
}

function qw_as_string( qw ){
	if ( !qw ) { return ''; }

	if ( T(qw, 'string') ) {
		return /\S/.test(qw) ? qw : '';
	}
	// else turn it _into_ a string
	return qw_as_array(qw).join(' ');
}

function qw_concat_strings(){
	return $.map(arguments, function(v){
		var s = qw_as_string(v);
		if ( s ) {
			return s;
		}
	}).join(' ');
}

function qw_each( qw, fn ){
	if ( ! qw ) { return; }

	if ( T(qw, 'jquery') || T(qw, 'string') ) {
		qw = qw_as_array(qw);
	}

	var use_key = T.not('list', qw);
	each(qw, function(k, v){
		if ( T.not('defNo', v) ) {
			return fn.call(use_key ? k : v);
		}
	});
}

function splice_string( s, offset, length, replacement ){
	if ( length || replacement ) {
		s = s.slice(0, offset) + (replacement||'') + s.slice(offset+(length||0));
	}
	return s;
}

function ensure_namespace( path ){
	if ( path.join ) {
		path = path.slice(0);
	} else {
		path = qw_as_array(path.replace(/\./g, ' '));
	}

	if ( path.length ) {
		var name_space = window;
		if ( path[0]==='window' ) {
			path.shift();
		}
		while ( path.length ) {
			var component_name = path.shift();
			if ( name_space[component_name] === undefined ) {
				name_space[component_name] = {};
			}
			name_space = name_space[component_name];
		}

		return name_space;
	}
}

ensure_namespace('Slash').jQuery = $;


function Package( o ){
	var root_name = qw_as_array((o.named||'').replace(/\.+/g, ' '));
	var stem_name = root_name.pop(); // root_name.length > 0 implies stem_name
	var estem_name = (root_name.length > 1 ? root_name.slice(-1) : []).
		concat(stem_name).
		join('_').
		replace(/([^A-Z_$])([A-Z])/g, '$1_$2').
		toLowerCase();

	var e_api = stem_name && o.element_api;
	// e_api implies stem_name

	function inject_free_api( stem_obj, extra ){
		if ( T.not('defNo', o.exports) ) {
			stem_obj.__api__ = stem_obj.__api__ && [].concat(stem_obj.__api__, o) || o;
		}
		// roll in the element_api first, so the free api can override same-named
		return $.extend(stem_obj, e_api||{}, o.api||{}, extra||{});
	}

	var defn_stem_fn =
		e_api && T.objIf('fn', o.element_constructor) || T.objIf('fn', o.stem_function);

	function e_ctor_fn( stem_name ){
		return function( e ){
			return $.extend(
				(e[stem_name] = inject_element_api(e, e_api, e[stem_name]||{})),
				defn_stem_fn ? defn_stem_fn.apply(e, arguments) : clone(arguments[1])
			);
		};
	}

	var root_obj = root_name.length && ensure_namespace(root_name);
	// therefore, root_obj implies stem_name

	var extant_stem_obj = root_obj && root_obj[stem_name];
	var e_ctor = e_api && e_ctor_fn(estem_name);
	var stem_obj = inject_free_api(e_ctor || defn_stem_fn || extant_stem_obj || {});

	if ( e_api ) {
		stem_obj[stem_name] = e_ctor_fn(estem_name);
	}

	var oj = o.jquery;
	if ( oj ) {
		var jstem_name = oj.named || estem_name;

		// $.jstem_name
		if ( T.not('defNo', oj.api) ) {
			$[jstem_name] = T.nonEmpty(oj.api) ?
				inject_free_api(e_api && e_ctor_fn(jstem_name) || {}, oj.api) :
				stem_obj;
		}
		// $(expr).jstem_name()
		var je_api = oj.element_api;
		var defn_jstem_fn = T.objIf('fn', oj.element_constructor) || T.objIf('fn', oj.stem_function);
		var je_ctor = T.objIf('fn', defn_jstem_fn) || e_ctor && jproxy_free_fn(e_ctor);
		if ( je_ctor ) {
			$.fn[jstem_name] = je_ctor;
		}
		// $(expr).jstem_name__fn_name()
		if ( T.not('defNo', je_api) ) {
			var j_prefix = jstem_name + '__';
			if ( T.nonEmpty(e_api) ) {
				each(e_api, function( fn_name, fn ){ if ( T.fn(fn) ) {
					$.fn[j_prefix + fn_name] = je_ctor ?
						function(){
							var args = arguments;
							return this.each(function(){
								var fn_proxy = this[jstem_name] && this[jstem_name][fn_name];
								if ( fn_proxy ) {
									fn_proxy.apply(this, args);
								}
							});
						} :
						jproxy_free_fn(fn);
				}});
			}
			if ( T.nonEmpty(je_api) ) {
				each(je_api, function( fn_name, fn ){ if ( T.fn(fn) ) {
					$.fn[j_prefix + fn_name] = fn;
				}});
			}
		}
	}

	if ( root_obj && (extant_stem_obj !== stem_obj) ) {
		if ( extant_stem_obj ) {
			stem_obj = $.extend(extant_stem_obj, stem_obj);
		} else {
			root_obj[stem_name] = stem_obj;
		}
	}

	return stem_obj;
}

// return a function, fn', such that a call fn'(a, b, c) really means fn(obj, a, b, c) { this===obj }
function proxy_fn( obj, fn ){
	return function(){
		return fn.apply(obj, [obj].concat($.makeArray(arguments)));
	};
}

// return a function, fn', such that a call $selection.fn'(a, b, c) really means
// fn(elem, a, b, c){ this===elem } for each elem in $selection
function jproxy_free_fn( fn ){
	return function(){
		var args = arguments;
		return this.each(function(){
			proxy_fn(this, fn).apply(this, args);
		});
	};
}


// attach any number of functions to obj such that, for each function, fn, in api_defn
//	elem.fn(a, b, c) ==> api_defn.fn(elem, a, b, c){ this===elem }
// e.g., elem.tag_server.ajax(a, b, c) ==> tag_server_api.ajax(elem, a, b, c){ this===elem }
function inject_element_api(elem, api_defn, obj){
	obj = obj || elem;
	each(api_defn, function(fn_name, fn){
		if ( T.fn(fn) ) {
			obj[fn_name] = proxy_fn(elem, fn);
		}
	});
	return obj;
}

function with_packages(){
	var result = '';
	for ( var i = 0; i < arguments.length; ++i ) {
		var api_instance_name = arguments[i];
		if ( typeof api_instance_name !== 'string' ) {
			continue;
		}
/*jslint evil: true */
		var exports = [], api_instance = eval(api_instance_name);
/*jslint evil: false */
		if ( api_instance && api_instance.__api__ && api_instance.__api__.exports ) {
			var allowed_exports = api_instance.__api__.exports.split(/\s+/);
			each(allowed_exports, function(i, member_name){
				if ( member_name in api_instance ) {
					exports.push(member_name);
				}
			});
		}

		if ( exports.length ) {
			result += 'var ' +
				$.map(exports, function(k, v){
					return k+'='+api_instance_name+'.'+k;
				}).join(',') +
				';';
		}
	}
	return result;
}

Package({ named: 'Slash.Util.Package',
	api: {
		with_packages:		with_packages
	},
	stem_function: Package
});

Package({ named: 'Slash.Util.qw',
	api: {
		as_array:		qw_as_array,
		as_set:			qw_as_set,
		as_string:		qw_as_string,
		concat_strings:		qw_concat_strings,
		each:			qw_each
	},
	stem_function: qw_as_array
});

Package({ named: 'Slash.Util',
	api: {
		clone:			clone,
		ensure_namespace:	ensure_namespace
	},
	exports: 'clone ' +
		 'Package qw'
});

Package({ named: 'Slash.Util.Algorithm',
	api: {
		each:			each,
		accumulate:		accumulate,
		keys:			keys,
		values:			values
	},
	exports: 'each accumulate keys values'
});

// Yes, I could phrase this as a Package; but I don't need to, here.

$.fn.extend({
	getClass: function(){ return this.attr('className'); },
	setClass: function( expr ){
		if ( !expr || !expr.call ) {
			return this.attr('className', expr);
		} else {
			return this.each(function(){
				this.className = qw_as_string(expr.call(this, qw_as_set(this.className)));
			});
		}
	}
});

})(jQuery);

// not exactly sure what to do with these yet

function sign( o ){ return $.TypeOf(o, 'number') && o<0 && -1 || (o ? 1 : 0); }

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

function topLeftAny( expr ){
	var top, left;

	if ( expr ) {
		var $expr=$any(expr), offset;
		if ( $expr.length ) {
			if ( $expr[0] === window ) {
				top = $expr.scrollTop();
				left = $expr.scrollLeft();
			} else if ( $expr[0] === document ) {
				top = left = 0;
			} else if ( offset=$expr.offset() ) {
				return offset;
			}
		}
	}

	// always return a point, though the values for top/left may be undefined
	return { top:top, left:left };
}
function topAny( expr ){ return topLeftAny(expr).top; }
function leftAny( expr ){ return topLeftAny(expr).left; }

function boundsAny( expr ){
	var $expr=$any(expr), topLeft=topLeftAny($expr), t=topLeft.top, l=topLeft.l, h, w;
	if ( $expr.length ) {
		h = $expr.height();
		w = $expr.width();
	}
	return { top:t, left:l, bottom:h ? t+h : t, right:w ? l+w : l };
}

var topBottomAny=boundsAny;

function boundsOp( a, b ){
	var answer = {};
	$.each(this, function( k, v ){
		k in a && k in b && (answer[k] = Math[v](a[k], b[k]));
	});
	return answer;
}

function intersectBounds( a, b ){
	return boundsOp.apply( {top:'max', left:'max', bottom:'min', right:'min'}, arguments);
}


function inWindowAny( expr ){
	var	y	= $.TypeOf(expr)==='number' ? expr : topAny(expr),
		w	= topBottomAny(window);
	return sign(between(w.top, y, w.bottom)==0);
}

function vScrollToAny( expr, when ){
	var y = topAny(expr);
	if ( when=sign(when) ) {
		when += (inWindowAny(y)||-1);
	}
	when || scroll(leftAny(window), y);
}
vScrollToAny.IF_VISIBLE = -1;
vScrollToAny.ALWAYS = 0;
vScrollToAny.IF_NOT_VISIBLE = 1;
// ...are the opposites of (inWindowAny(expr)||-1)
