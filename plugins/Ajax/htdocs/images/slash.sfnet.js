// SourceForge specific JS.  Hostile environment assumed.

Slash.Util.ensure_namespace('SFX');
SFX.jQuery = jQuery /* .noConflict(true) */;

function $dom( id ) {
	return document.getElementById(id);
}



(function($){

var kAuthenticated=true, kNotAuthenticated=false;

var root_d2_selector = '#sd-d2-root';
var root_tagui_selector = '.sd-tagui-root';
var sfnet_prefix = 'sfnet';



function simple_tagui_markup( prefix ){
	prefix = prefix ? prefix + '-' : '';
	return '<div class="' + prefix + 'basic-tagui">' +
		$.map(['user', 'top', 'system'], function( k ){
			return '<span class="' + prefix + 'tag-display-stub respond-' + k + '"></span>';
		}).join('') +
		'</div>';
}

function install_tagui( $roots, authenticated ){
	/* do something different if ! authenticated? */

	Slash.TagUI.Server.need_cross_domain();

	var tagui_markup = simple_tagui_markup(sfnet_prefix);

	$roots.
		each(function(){
			var $this = $(this);
			if ( ! $this.find('.sd-tags-here').replaceWith(tagui_markup).length ) {
				$this.append(tagui_markup);
			}
		}).
		tagui__init().
		tagui_markup__auto_refresh_styles().
		tagui_server().
		tagui_server__fetch_tags();

	if ( authenticated ) {
		$roots.click(Slash.TagUI.Command.simple_click);

		// install edit field
	}

	// simple_tagui_markup() doesn't produce legends, but we want them anyway.
	$.each({
		user:	'My Tags',
		top:	'Top Tags',
		system:	'System Tags'
	}, function( k, v ){
		$roots.
			find('[class*=tag-display].respond-'+k).
			prepend('<span class="legend">'+v+'</span>');
	});

	return $roots;
}

function install_d2( d2, authenticated ){
	/* do something different if ! authenticated? */
	d2.each(function(){
		var key = Slash.Util.find_reference_key(this);
		if ( key.key_type === 'url' ) {
			var inner_url = key.key;
			//$(this).load('/slashdot/slashdot-it.pl?op=discuss&div=1&url='+encodeURI(inner_url));
			$(this).load('/slashdot-it.pl?op=discuss&div=1&d=961785');
		}
	});
	return d2;
}

function if_auth( fn ){
	var authenticated = /* check cookie */ true;

	if ( authenticated ) {
		// previously authenticated
		fn(kAuthenticated);
	} else {
		$.ajax({
			//url:     '/slashdot/auth.pl',
			url:     '/auth.pl',
			type:    'POST',
			error:   function(){
				// not authenticated, but you can still run "read-only"
				fn(kNotAuthenticated);
			},
			success: function(){
				// fully authenticated
				fn(kAuthenticated);
			}
		});
	}
	/* do not return a value: we can't promise a synchronous answer */
}

SFX.install_slash_ui = function(){
	var $tagui_roots, $d2_roots;
	for ( var i=0; i<arguments.length; ++i ) {
		switch ( arguments[i] ) {
			case 'd2':	$d2_roots = $(root_d2_selector);	break;
			case 'tags':	$tagui_roots = $(root_tagui_selector);	break;
		}
	}

	if_auth(function( authenticated ){
		if ( $d2_roots && $d2_roots.length )		{ install_d2($d2_roots, authenticated); }
		if ( $tagui_roots && $tagui_roots.length )	{ install_tagui($tagui_roots, authenticated); }
	});
};

})(SFX.jQuery);
