// SourceForge specific JS.  Hostile environment assumed.

Slash.Util.ensure_namespace('SFX');
SFX.jQuery = jQuery /* .noConflict(true) */;

(function($){

function simple_tagui_markup( prefix ){
	prefix = prefix ? prefix + '-' : '';
	return '<div class="' + prefix + 'basic-tagui">' +
		$.map(['user', 'top', 'system'], function( k ){
			return '<span class="' + prefix + 'tag-display-stub respond-' + k + '"></span>';
		}).join('') +
		'</div>';
}

function install_tagui( expr, prefix ){
	var tagui_markup = simple_tagui_markup(prefix);

	var $selection = $(expr).
		each(function(){
			var $this = $(this);
			if ( ! $this.find('.sd-tags-here').replaceWith(tagui_markup).length ) {
				$this.append(tagui_markup);
			}
		}).
		tagui__init().
		tagui_markup__auto_refresh_styles().
		tagui_server({
			id: function( s_elem ){
				return $(s_elem).find('[class*=sd-key]:first').text() || window.location;
			}
		}).
		tagui_server__fetch_tags().
		click(Slash.TagUI.Command.simple_click);

	// simple_tagui_markup() doesn't produce legends, but we want them anyway.
	$.each({
		user:	'My Tags',
		top:	'Top Tags',
		system:	'System Tags'
	}, function( k, v ){
		$selection.
			find('[class*=tag-display].respond-'+k).
			prepend('<span class="legend">'+v+'</span>');
	});

	return $selection;
}


SFX.install_slash_ui = function(){
	for ( var i=0; i<arguments.length; ++i ) {
		switch ( arguments[i] ) {
			case 'd2':
				var d2 = $('#sd-d2-root');
				var inner_url = d2.find('.sd-key-url').text() || window.location;
				d2.load('//sourceforge.net/slashdot/slashdot-it.pl?op=discuss&div=1&url='+encodeURI(inner_url));
				break;
			case 'tags':
				install_tagui('.sd-tagui-root', 'sfnet');
				break;
		}
	}
};

})(SFX.jQuery);
