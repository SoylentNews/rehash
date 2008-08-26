/* API

Usage:
	var api = new API(api_definition);

api_definition is an object with the following properties, of which 'name' is
required and all others are optional (of course the whole thing is pointless if
you don't supply at least one of api, or element_api).

	name:			non-empty string
	api:			object with function and data members
	element_api:		object with function members whose first argument is an element
	element_constructor:	boolean or function
	extend_jquery:		boolean or string
	extend_jquery_wrapper:	boolean or function

Example:

	var greeter = new API({
		name: 'greeter',
		element_api: {
			say_hello: function( element, person ){
				$element.text("Hello, " + (person || "world") + "!");
			}
		},
		extend_jquery_wrapper: true
	});

	var elem = $('#world-greeting')[0];

	// you can now use the functions from your 'namespace'
	greeter.say_hello(elem);

	// or you can attach your api to an element...
	greeter(elem);

	// ...and then call your functions directly on the element
	elem.greeter.say_hello('Bob');

	// Because we asked to extend the jQuery wrapper, we can use our
	// functions from a selection even without attaching the api to the
	// selected elements
	$('[id*=greeting]').greeter__say_hello();

	// or we can use jQuery to attach the api to the selected elements
	$('[id*=greeting]').greeter();

When your element functions are called _from_ elements, 'this' will always be
set to the element.  If your function is called in the form where the elem is
supplied as a parameter at the call-site, 'this' is set to your global api
object.

	elem.greeter.say_hello('Bob')	// inside say_hello, 'this' is elem
	greeter.say_hello(elem, 'Bob')	// inside say_hello, 'this' is greeter

If you also supply an 'api' entry in the definition, those functions (and data
members) will be available on greeter, above, but _not_ on individual elements
no from a jQuery selection.

If you also elect to extend_jquery itself, then jQuery will have an member named
as your api name, or else as the string you supplied:

	$.greeter

...which has all the same powers as our greeter object, above.
 */

(function($){

/*global window jQuery */

// XXX move to Algorithm
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
