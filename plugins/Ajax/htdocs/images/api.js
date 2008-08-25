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
function attach_api(api_defn, elem, obj){
	obj = obj || elem;
	$.each(api_defn, function(fn_name, fn){
		if ( $.isFunction(fn) ) {
			obj[fn_name] = proxy_fn(elem, fn);
		}
	});
	return obj;
}

var API = (window.API = function( name, api_defn, ctor ){
	this.name = function(){ return name; };
	this.api_defn = api_defn;

	if ( ctor === undefined || $.isFunction(ctor) ) {
		if ( ! ctor ) {
			this.no_inner_ctor = true;
		}

		this.ctor = function( elem ){
			// two steps, so ctor may use api already bound to obj
			var obj = (elem[name] = attach_api(api_defn, elem, elem[name]||{}));
			var ctor_ext = ctor ? ctor.apply(elem, arguments) : clone(arguments[1]);
			if ( ctor_ext ) {
				$.extend(obj, ctor_ext);
			}
			return obj;
		};
		$.extend(this.ctor, api_defn||{});
	}
});

API.prototype = {
	api: function(){
		return this.ctor || this.api_defn;
	},
	construct: function( elem /*, a, b, c */ ){
		if ( this.ctor ) {
			this.ctor.apply(this, arguments);
		}
		return elem;
	},
	extend_jquery: function( j_ctor ){
		var api = this;
		var api_name = this.name();

		// constructor
		// $().tag_server(opts) ==> n * tag_server_api.construct(elem, opts);
		if ( api.ctor && (j_ctor === undefined || $.isFunction(j_ctor)) ) {
			$.fn[api_name] = j_ctor ? j_ctor : function(){
				var args = arguments;
				return this.each(function(){
					// must apply to unwrap args
					proxy_fn(this, api.ctor).apply(this, args);
				});
			};
		}
		// other member functions
		// $().tag_server__ajax(opts) ==> n * s_elem.tag_server.ajax(opts)
		$.each(api.api_defn, function( fn_name, fn ){
			if ( $.isFunction(fn) ) {
				$.fn[api_name + '__' + fn_name] = api.ctor && !api.no_inner_ctor ?
					// if api has a ctor, we can expect elements to have been extended, e.g., elem.tag_server
					function(){
						var args = arguments;
						return this.each(function(){
							var fn_proxy = this[api_name] && this[api_name][fn_name];
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
};

})(jQuery);
