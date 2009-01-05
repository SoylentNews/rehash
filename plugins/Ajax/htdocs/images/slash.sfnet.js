; // SourceForge specific JS.  Hostile environment assumed.

Slash.Util.ensure_namespace('SFX');
SFX.jQuery = jQuery /* .noConflict(true) */;

function $dom( id ) {
	return document.getElementById(id);
}



(function($){

var kTesting = true;

var isAuthenticated = kTesting ? true : false;
var kAuthenticated=true, kNotAuthenticated=false;

var root_d2_selector = '#sd-d2-root';
var root_tag_ui_selector = '.sd-tag-ui-root';
var sfnet_prefix = 'sfnet';

function handle_tag_click( event ){
	var $target = $(event.target), command='', $menu;

	if ( $target.is('.tag') ) {
		command = $target.text();
	} else if ( ($menu = $target.nearest_parent('[class*=tag-menu]')).length ) {
		var op = $target.text();
		var $tag = $target.nearest_parent(':has(span.tag)').find('span.tag');
		var tag = $tag.text();
		command = normalize_tag_menu_command(tag, op);
	}

	if ( command ) {
		$target.nearest_parent('.tag-server').
			tag_ui_server__submit_tags(command);
		return false;
	}

	return true;
}

function handle_toggle_click( event ){
	this.blur();

	var	$target	= $(event.target).nearest_parent('a'),
		$twisty	= $target.children(),
		$form	= $target.next();

	$twisty.toggleClasses('collapse', 'expand');
	$form[ $twisty.is('.expand') ? 'show' : 'hide' ]();
	return false;
}



function make_tag_displays( prefix, displays ){
	return $.map(displays, function( k ){
		return '<span class="'+prefix+'tag-display-stub respond-'+k+'"></span>';
	}).join('');
}

function make_tag_editor( prefix ){
	return ['<a class="', 'tag-edit-toggle" href="#">' +
			'<span class="', 'button collapse"></span>' +
		'</a>' +
		'<form class="', 'tag-form" style="display:none">' +
			'<input class="', 'tag-input" type="text" size="10">' +
			'<span class="', 'tag-server-busy">' +
				'<img src="http://images.slashdot.org/spinner2.gif" alt="Loading ...">' +
			'</span>' +
		'</form>'].join(prefix);
}

function simple_tag_ui_markup( prefix, if_authenticated ){
	prefix = prefix ? prefix + '-' : '';

	var displays = ['top', 'system'], editor_if_any = '';
	if ( if_authenticated ) {
		displays.unshift('user');
		editor_if_any = make_tag_editor(prefix);
	}

	return	'<div class="'+prefix+'basic-tag-ui">' +
			editor_if_any +
			make_tag_displays(prefix, displays) +
		'</div>';
}

function install_tag_ui( $roots, if_authenticated ){
	/* do something different if ! authenticated? */

	var	Server	= Slash.TagUI.Server,
		Markup	= Slash.TagUI.Markup,
		Command	= Slash.TagUI.Command,
		qw	= Slash.Util.qw;

	Server.need_cross_domain();
	Markup.add_style_triggers(['nod', 'metanod'], 'y p');
	Markup.add_style_triggers(['nix', 'metanix'], 'x p');

	var tag_ui_markup = simple_tag_ui_markup(sfnet_prefix, if_authenticated);

	var allowed_ops = [];
	switch ( if_authenticated ) {
		case 3: allowed_ops = allowed_ops.concat('#');			// admin
		case 2: allowed_ops = allowed_ops.concat('_');			// owner
		case 1: case true: allowed_ops = allowed_ops.concat('!', 'x');	// logged-in
		default:							// anon
	}

	var command_pipeline = [ Command.allow_ops(allowed_ops) ];

	$roots.
		each(function(){
			var $this = $(this);
			if ( ! $this.find('.sd-tags-here').replaceWith(tag_ui_markup).length ) {
				$this.append(tag_ui_markup);
			}
		}).
		tag_ui__init({
			for_display: {
				for_display: {
					menu: qw.as_string(allowed_ops)
				}
			}
		}).
		tag_ui_markup__auto_refresh_styles().
		tag_ui_server().
		tag_ui_server__fetch_tags().
		each(function(){
			this.tag_ui_server.command_pipeline = command_pipeline;
		});

	if ( if_authenticated ) {
		$roots.
			click(handle_tag_click).
			find('[class*=tag-form]').
				submit(function(){
					var	$this = $(this),
						$input = $this.find(':input'),
						commands = $input.val();
					$input.val('');
					$this.
						nearest_parent('.tag-server').
							tag_ui_server__submit_tags(commands);
				}).
			end().
			find('[class*=tag-edit-toggle]').
				click(handle_toggle_click);
	}

	// simple_tag_ui_markup() doesn't produce legends, but we want them anyway.
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
	d2.each(function(){
		var key = Slash.ArticleInfo.key(this) || { key: window.location.href, key_type: 'url' };
		var inner_url = '';
		if ( key.key_type === 'url' ) {
			inner_url = key.key || '';
		}
		//$(this).load('/slashdot/slashdot-it.pl?op=discuss&div=1&url='+encodeURI(inner_url));
		$(this).load('/slashdot-it.pl?op=discuss&printdiv=1&url='+encodeURI(inner_url));
	});
	return d2;
}

function if_auth( fn ){
	if ( isAuthenticated ) {
		// previously authenticated
		fn(kAuthenticated);
	} else {
		auth_call(fn);
	}
	/* do not return a value: we can't promise a synchronous answer */
}

function auth_call( fn, params ) {
	if ( !params ) {
		params = {};
	}
	// XXX this at some point may need to be context-dependent
	params.group_id = $('span.sd-key-group-id').text();

	if (kTesting) {
		fn(kAuthenticated);
	}

	get_token(function( token_text ) {
		$.ajax({
			//url:     '/slashdot/auth.pl',
			url:     '/auth.pl',
			data:    { token : token_text },
			type:    'POST',
			error:   function(){
				// not authenticated, but you can still run "read-only"
				fn(kNotAuthenticated);
			},
			success: function( transport ){
				var response = eval_response(transport);
				if (response && response.success) {
					isAuthenticated = true;
					fn(kAuthenticated);
				} else {
					isAuthenticated = false;
					fn(kNotAuthenticated);
				}
			}
		});
	}, params );
}

function get_token( fn, params ) {
	// params.group_id is required, at a minimum
	if ( !fn || !params || !params.group_id ) {
		return;
	}

	if (kTesting) {
		fn();
		return;
	}

	$.ajax({
		url:      'XXX', // XXX!
		type:     'POST',
		data:     params,
		complete: function( token_text ){ fn(token_text); }
	});
}

SFX.install_slash_ui = function(){
	var $tag_ui_roots, $d2_roots;
	for ( var i=0; i<arguments.length; ++i ) {
		switch ( arguments[i] ) {
			case 'd2':	$d2_roots = $(root_d2_selector);		break;
			case 'tags':	$tag_ui_roots = $(root_tag_ui_selector);	break;
		}
	}

	if_auth(function( authenticated ){
		if ( $d2_roots && $d2_roots.length )		{ install_d2($d2_roots, authenticated); }
		if ( $tag_ui_roots && $tag_ui_roots.length )	{ install_tag_ui($tag_ui_roots, authenticated); }
	});
};

})(SFX.jQuery);
