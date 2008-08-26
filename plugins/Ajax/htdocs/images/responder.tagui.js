(function($){

if ( window.TagUI === undefined ) {
	window.TagUI = {};
}

window.TagUI.tag_responder = new API({
	name: 'tag_responder',
	element_api: {
		ready: function( r_elem, if_ready ){
			var $r_elem = $(r_elem), ready_class = 'ready';
			if ( if_ready === undefined ) {
				return $(r_elem).hasClass(ready_class);
			}
			$(r_elem).toggleClassTo(ready_class, if_ready);
			return r_elem;
		},
		bind: function( r_elem, fn, signals ){
			r_elem.tag_responder.handle_signal = fn;
			$(r_elem).attr('signal', list_as_string(signals));
			return r_elem;
		},
		handle: function( r_elem, signals, data, options ){
			var fn = r_elem.tag_responder && r_elem.tag_responder.handle_signal;
			if ( fn ) {
				fn.apply(r_elem, [signals, data, options]);
			}
			return r_elem;
		}
	},
	element_constructor: function( r_elem, fn, signals, if_ready ){
		r_elem.
			tag_responder.bind(fn, signals).
			tag_responder.ready(if_ready===undefined?true:if_ready);
	},
	extend_jquery_wrapper: true
});

})(jQuery);
