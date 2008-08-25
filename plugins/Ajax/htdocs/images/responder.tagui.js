(function($){

if ( ! window.TagUI ) {
	window.TagUI = {};
}
var tag_responder = new API('tag_responder', {
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
	// constructor
	function( r_elem, fn, signals, if_ready ){
		r_elem.
			tag_responder.bind(fn, signals).
			tag_responder.ready(if_ready===undefined?true:if_ready);
	}
);

TagUI.tag_responder = tag_responder.api();
tag_responder.extend_jquery();

})(jQuery);
