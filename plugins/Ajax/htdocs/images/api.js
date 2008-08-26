(function($){

/*global window jQuery */

var clone = ($.clone = function( o ){
	if ( !o || typeof o !== 'object' ) {
		return o;
	}

	var o2 = new o.constructor();
	for ( var k in o ) {
		o2[k] = clone(o[k]);
	}
	return o2;
});

// return a function, fn', such that a call fn'(a, b, c) really means fn(obj, a, b, c) { this===obj }
function proxy_fn( obj, fn ){
	return function(){
		return fn.apply(obj, [obj].concat($.makeArray(arguments)));
	};
}

// attach any number of functions to obj such that, for each function, fn, in api_defn
//	obj.fn(a, b, c) ==> api_defn.fn(elem, a, b, c){ this===elem }
// e.g., elem.tag_server.ajax(a, b, c) ==> tag_server_api.ajax(elem, a, b, c){ this===elem }
function attach_element_api(api_defn, elem, obj){
	obj = obj || elem;
	$.each(api_defn, function(fn_name, fn){
		if ( $.isFunction(fn) ) {
			obj[fn_name] = proxy_fn(elem, fn);
		}
	});
	return obj;
}

var API = (window.API = function( o ){
	var api_object = function(){};

	var e_ctor = o.element_constructor;
	var e_ctor_is_fn = $.isFunction(e_ctor);

	var xe_ctor = undefined;

	if ( o.element_api && (e_ctor === undefined || e_ctor_is_fn) ) {
		xe_ctor = function( elem ){
			// two steps, so e_ctor may use api already bound to obj
			var obj = (elem[o.name] = attach_element_api(o.element_api, elem, elem[o.name]||{}));
			var extra = e_ctor ? e_ctor.apply(elem, arguments) : clone(arguments[1]);
			if ( extra ) {
				$.extend(obj, extra);
			}
			return obj;
		};
		api_object = xe_ctor;
	}

	// o.element_api first, so the general api can override same-named functions
	$.extend(api_object, o.element_api||{}, o.api||{});

	// extend $ if requested
	if ( o.extend_jquery ) {
		$[typeof o.extend_jquery === 'string' ? o.extend_jquery : o.name] = api_object;
	}

	// extend $.fn if requested and if we have an element api
	if ( o.element_api && o.extend_jquery_wrapper ) {
		var j_ctor = $.isFunction(o.extend_jquery_wrapper) ? o.extend_jquery_wrapper : undefined;

		// constructor
		// $().tag_server(opts) ==> n * tag_server_api.construct(elem, opts);
		$.fn[o.name] = j_ctor ? j_ctor : function(){
			var args = arguments;
			return this.each(function(){
				// must apply to unwrap args
				proxy_fn(this, xe_ctor).apply(this, args);
			});
		};

		// other member functions
		// $().tag_server__ajax(opts) ==> n * s_elem.tag_server.ajax(opts)
		$.each(o.element_api, function( fn_name, fn ){
			if ( $.isFunction(fn) ) {
				$.fn[o.name + '__' + fn_name] = xe_ctor && e_ctor_is_fn ?
					// if api has a e_ctor, we can expect elements to have been extended, e.g., elem.tag_server
					function(){
						var args = arguments;
						return this.each(function(){
							var fn_proxy = this[o.name] && this[o.name][fn_name];
							if ( fn_proxy ) {
								fn_proxy.apply(this, args);
							}
						});
					} :
					// ...otherwise, we expect we can run the function on _any_ element
					function(){
						var args = arguments;
						return this.each(function(){
							// must apply to unwrap args
							proxy_fn(this, fn).apply(this, args);
						});
					};
			}
		});
	}

	return api_object;
});

})(jQuery);
