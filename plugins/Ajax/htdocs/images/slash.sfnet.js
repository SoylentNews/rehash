// SourceForge specific JS.  Hostile environment assumed.

Slash.Util.ensure_namespace('SFX');
SFX.jQuery = jQuery /* .noConflict(true) */;

(function($){

SFX.init_slash_ui = function(){
	for ( var i=0; i<arguments.length; ++i ) {
		switch ( arguments[i] ) {
			case 'd2':
				var d2 = $('#sd-d2-root');
				var inner_url = d2.find('.sd-key-url').text() || window.location;
				d2.load('//sourceforge.net/slashdot/slashdot-it.pl?op=discuss&div=1&url='+encodeURI(inner_url));
				break;
			case 'tags':
				$('.sd-tagui-root').tagui__build_sourceforge_ui('sfnet');
				break;
		}
	}
};

})(SFX.jQuery);
