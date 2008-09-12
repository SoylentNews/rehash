// SourceForge specific JS.  Hostile environment assumed.

Slash.Util.ensure_namespace('SFX');
SFX.jQuery = jQuery /* .noConflict(true) */;

function $dom( id ) {
	return document.getElementById(id);
}



(function($){

function sfnet_canonical_project_url( url ){
	url = url || '' + window.location;
	var project_name, url = url.split(/\/+/);
	if ( ! url[0] ) { url.shift(); }
	if ( /:$/.test(url[0]) ) { url.shift(); }
	if ( /\.net$/.test(url[0]) ) { url.shift(); }
	if ( url[0] === 'projects' ) {
		return "http://sourceforge.net/projects/" + url[1];
	}
}

var re_key = /sd-key-(.*)/;

function get_sd_key( elem ){
	var key = {}, $key = $(elem).find('[class*=sd-key-]:first');
	if ( $key.length ) {
		key.key = $key.text();
		$.each(Slash.Util.qw($key.attr('class')), function( cn ){
			var M = re_key.exec(cn);
			if ( M ) {
				key.key_type = M[1];
				return false;
			}
		});
	} else if ( (key.key = sfnet_canonical_project_url()) ) {
		key.key_type = "url";
	}

	return key;
}

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
				return get_sd_key(s_elem).key;
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
	$.ajaxSetup({
		url:	'/ajax.pl',
		type:	'POST',
		contentType: 'application/x-www-form-urlencoded'
	});

	for ( var i=0; i<arguments.length; ++i ) {
		switch ( arguments[i] ) {
			case 'd2':
				var d2 = $('#sd-d2-root');
				var key = get_sd_key(d2);
				if ( key.key_type === 'url' ) {
					var inner_url = key.key;
					d2.load('//sourceforge.net/slashdot/slashdot-it.pl?op=discuss&div=1&url='+encodeURI(inner_url));
				}
				break;
			case 'tags':
				install_tagui('.sd-tagui-root', 'sfnet');
				break;
		}
	}
};

})(SFX.jQuery);
