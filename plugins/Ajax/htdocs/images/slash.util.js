;(function($){

// global setup

$.ajaxSetup({
	url:	'/ajax.pl',
	type:	'POST',
	contentType: 'application/x-www-form-urlencoded'
});

ensure_namespace('Slash').jQuery = $;


// code to be exported

function if_defined( expr ){
	return expr !== undefined;
}

function if_undefined( expr ){
	return expr === undefined;
}

function if_defined_false( expr ){
	return !if_undefined(expr) && !expr;
}

function if_object( expr ){
	return (typeof expr === 'object') && expr;
}

function if_fn( expr ){
	return $.isFunction(expr) && expr;
}

function if_inherits_property(obj, property_name){
/*jslint evil: true */
	return if_defined(eval('obj.'+property_name)) &&
/*jslint evil: false */
		!obj.propertyIsEnumerable(property_name);
}

function if_inherits_method(obj, method_name){
	return if_inherits_property(obj, method_name) &&
		if_fn(obj[method_name]);
}

function if_inherits_jquery(obj){
	return if_inherits_property(obj, 'jquery');
}

function if_inherits_string_like(obj){
	return if_inherits_method(obj, 'split') && ! if_inherits_jquery(obj);
}

function if_inherits_array_iteration(obj){
	return if_inherits_property(obj, 'length');
}


function each( obj, fn ){
	var N = obj.length;
	if ( if_undefined(N) || if_fn(obj) ) {
		for ( var k in obj ) {
			if ( if_defined_false(fn.call(obj[k], k, obj[k])) ) {
				break;
			}
		}
	} else {
		var i = 0;
		for ( var value=obj[i]; i<N; value=obj[++i] ) {
			if ( if_defined_false(fn.call(value, i, value)) ) {
				break;
			}
		}
	}
}

function clone( o ){
	var is_fn, o2;
	if ( !o || !(if_object(o) || (is_fn = if_fn(o))) ) {
		return o;
	}

	if ( is_fn ) {
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

	// ...as long as we're willing to copy all the properties (even works on arrays)
	// and key that we do this for functions as well... they can have properties
	each(o, function(k, v){
		o2[k] = clone(v);
	});
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

function rotate_list(list, n){
	if ( list.length > 1 ) {
		var N = list.length;
		n = ((n===undefined ? 1 : n) % N + N) % N;
		var	prefix = Array.prototype.slice.call(list, n),
			suffix = Array.prototype.slice.call(list, 0, n);
		return prefix.concat(suffix);
	}
	return list;
}

function qw_as_array( qw ){
	if ( ! qw ) { return []; }

	if ( if_inherits_string_like(qw) ) {
		qw = (' '+qw+' ').split(/\s+/).slice(1, -1);
	}
	if ( ! if_inherits_array_iteration(qw) ) {
		qw = accumulate([], function(k, v){if(v){this.push(k);}}, qw);
	}
	// else: qw already _is_ an array

	return qw;
}

function qw_as_set( qw ){
	if ( ! qw ) { return {}; }

	if ( if_inherits_jquery(qw) || if_inherits_string_like(qw) ) {
		qw = qw_as_array(qw);
	}
	if ( if_inherits_array_iteration(qw) ) {
		qw = accumulate({}, function(k,v){this[v]=true;}, qw);
	}
	// else qw already _is_ a set

	return qw;
}

function qw_as_string( qw ){
	if ( !qw ) { return ''; }

	if ( if_inherits_string_like(qw) ) {
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

	if ( if_inherits_jquery(qw) || if_inherits_string_like(qw) ) {
		qw = qw_as_array(qw);
	}

	var use_key = ! if_inherits_array_iteration(qw);
	each(qw, function(k, v){
		if ( ! if_defined_false(v) ) {
			return fn.call(use_key ? k : v);
		}
	});
}

function map_toggle( list ){
	var keys = qw_as_array(list);
	if ( keys.length > 1 ) {
		return accumulate({}, function(i, k, v){ this[k]=v; }, keys, rotate_list(keys));
	}
}

function splice_string( s, offset, length, replacement ){
	if ( length || replacement ) {
		s = s.slice(0, offset) + (replacement||'') + s.slice(offset+(length||0));
	}
	return s;
}

var re_key_class = /sd-key-(.*)/;
var re_key_id = /^([^-]+)-.*(\d+)$/;

function find_reference_key( elem ){
	var M, key = {}, $key = $(elem).find('[class*=sd-key-]:first');
	if ( $key.length ) {
		key.key = $key.text();
		$.each(Slash.Util.qw($key.attr('className')), function( i, cn ){
			if ( (M = re_key_class.exec(cn)) ) {
				key.key_type = M[1];
				return false;
			}
		});
	} else if ( (M = re_key_id.exec($(elem).attr('id'))) ) {
		key.key_type = M[1];
		key.key = M[2];
	} else if ( (key.key = window.location.href) ) {
		key.key_type = "url";
	}

	return key;
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
		if ( ! if_defined_false(o.exports) ) {
			stem_obj.__api__ = stem_obj.__api__ && [].concat(stem_obj.__api__, o) || o;
		}
		// roll in the element_api first, so the free api can override same-named
		return $.extend(stem_obj, e_api||{}, o.api||{}, extra||{});
	}

	var defn_stem_fn = e_api && if_fn(o.element_constructor) || if_fn(o.stem_function);
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
		if ( ! if_defined_false(oj.api) ) {
			$[jstem_name] = if_object(oj.api) ?
				inject_free_api(e_api && e_ctor_fn(jstem_name) || {}, oj.api) :
				stem_obj;
		}
		// $(expr).jstem_name()
		var je_api = oj.element_api;
		var defn_jstem_fn = if_fn(oj.element_constructor) || if_fn(oj.stem_function);
		var je_ctor = if_fn(defn_jstem_fn) || e_ctor && jproxy_free_fn(e_ctor);
		if ( je_ctor ) {
			$.fn[jstem_name] = je_ctor;
		}
		// $(expr).jstem_name__fn_name()
		if ( ! if_defined_false(je_api) ) {
			var j_prefix = jstem_name + '__';
			if ( if_object(e_api) ) {
				each(e_api, function( fn_name, fn ){ if ( if_fn(fn) ) {
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
			if ( if_object(je_api) ) {
				each(je_api, function( fn_name, fn ){ if ( if_fn(fn) ) {
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
		if ( if_fn(fn) ) {
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

Package({ named: 'Slash.Util.if_inherits',
	api: {
		property:		if_inherits_property,
		method:			if_inherits_method,
		jquery:			if_inherits_jquery
	}
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
		if_defined:		if_defined,
		if_undefined:		if_undefined,
		if_defined_false:	if_defined_false,
		if_object:		if_object,
		if_fn:			if_fn,
		if_string_like:		if_inherits_string_like,
	     // if_array_like:		if_inherits_array_iteration,
		clone:			clone,
		splice_string:		splice_string,
		find_reference_key:	find_reference_key,
		ensure_namespace:	ensure_namespace
	},
	exports: 'if_defined if_undefined if_defined_false if_object if_fn ' +
		 'if_string_like ' +
		 'clone splice_string find_reference_key ' +
		 'Package if_inherits qw'
});

Package({ named: 'Slash.Util.Algorithm',
	api: {
		each:			each,
		accumulate:		accumulate,
		keys:			keys,
		values:			values,
		rotate_list:		rotate_list
	},
	exports: 'each accumulate keys values rotate_list'
});

// Yes, I could phrase this as a Package; but I don't need to, here.
$.fn.extend({
	find_nearest: function( selector ){
		var N = Math.min(3, arguments.length);
		var answer = this.map(function(){
			var $this = $(this);
			if ( $this.is(selector) ) {
				return this;
			}

			var match;
			for ( var i=1; i<N && !match; ++i ) {
				switch ( arguments[i] ) {
					case 'up':
						$this.parents().each(function(){
							if ( $(this).is(selector) ) {
								match = this;
								return false;
							}
						});
						break;
					case 'down':
						match = $this.find(selector)[0];
						break;
				}
			}
			return match;
		});

		return this.pushStack($.unique(answer))
	},
	nearest_parent: function( selector ){
		return this.find_nearest(selector, 'up');
	},
	setClass: function( cn ) {
		var fn = $.isFunction(cn) ? cn : function(){ return cn; };
		return this.each(function(){
			if ( ! (this.className = qw_as_string(fn.apply(this, [ qw_as_set(this.className) ]))) ) {
				this.removeAttribute('className');
			}
		});
	},
	toggleClassTo: function( cn, expr ){
		if ( ! cn ) { return this; }
		var fn = if_inherits_string_like(expr) ? function(e){ return $(e).is(expr); } : function(){ return expr; };
		return this.setClass(function(cn_set){ cn_set[cn] = fn.apply(this); return cn_set; });
	},
	mapClasses: function( map ){
		var Map = accumulate({}, function(k, v){ this[k]=qw_as_set(v); }, map);
		var for_unknown=Map['*'] || {}, for_all=Map['+'] || {}, for_missing=Map['?'] || {};
		return this.setClass(function(cn_set){
			var if_missing = true;
			var answer = accumulate(
				{},
				function(cn){
					if ( cn in Map ) {
						if_missing = false;
						$.extend(this, Map[cn]);
					} else if ( for_unknown ) {
						$.extend(this, for_unknown);
					} else {
						this[cn] = true;
					}
				},
				cn_set
			);
			return $.extend(answer, for_all, if_missing ? for_missing : {});
		});
	},
	toggleClasses: function( list ){
		return this.mapClasses( map_toggle(arguments.length==1 ? list : arguments) );
	}
});

})(jQuery);
