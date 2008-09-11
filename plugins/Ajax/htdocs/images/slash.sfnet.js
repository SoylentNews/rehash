// SourceForge specific JS.  Hostile environment assumed.

Slash.Util.ensure_namespace('SFX');
SFX.jQuery = jQuery /* .noConflict(true) */;

(function($){

SFX.init_slash_ui = function(){
	for ( var i=0; i<arguments.length; ++i ) {
		switch ( arguments[i] ) {
			case 'd2':
				$('.sd-d2-root').each(function(){
					var $this = $(this);
					var inner_url = $this.find('.sd-key-url').text() || window.location;
					// pudge: more here
				});
				break;
			case 'tags':
				$('.sd-tagui-root').tagui__build_sourceforge_ui('sfnet');
				break;
		}
	}
};

})(SFX.jQuery);
