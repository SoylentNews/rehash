; // tagui.js

var tag_server_fns = {

	broadcast_tag_lists: function( broadcasts ){
		var tuples = ('<user>' + broadcasts).split(/\n?<(\w*)>/).slice(1);
		if ( tuples && tuples.length >= 2 ) {
			var $listeners = $('.ready[listen]', this);
			while ( tuples.length >= 2 ) {
				var broadcast_kind = tuples.shift();
				var broadcast = tuples.shift();

				if ( ! broadcast.length )
					continue;

				$listeners.filter('[listen*=' + broadcast_kind + ']').each(function(){
					if ( this.receive_broadcast )
						this.receive_broadcast(broadcast, broadcast_kind);
					//else
					//	console.log('broadcast --- "ready", but no handler: ', this);
				})
			}
			style_tags_globally(this, $listeners);
		}
		return this
	},

	_tags_via_ajax: function( tag_cmds ){
		var server = this;
		var $busy = $('.tag-server-busy', server).show();

		if ( tag_cmds ) {
			var command_feedback = normalize_no_nodnix(tag_cmds);
			tag_cmds = normalize_nodnix(tag_cmds);

			// 'harden' the new tags into the user tag-display, but styled 'local-only'
			// tags in the response from the server will wipe-out local-only
			$('.tag-display.ready[listen*=user]', this).each(function(){
				this.update_tags(command_feedback, 'prepend', 'local-only')
			});
		}

		$.post('/ajax.pl', {
			op:	'tags_setget_combined',
			id:	$(this).attr('tag-server'),
			tags:	tag_cmds || '',
			reskey:	reskey_static,
		}, function( server_response ){
			//console.log('server._tags_via_ajax --- server_response: ' + server_response);
			server.broadcast_tag_lists(server_response);
			$busy.removeAttr('style')
		}, 'text');
		return this
	},


	fetch_tags: function(){
		return this._tags_via_ajax()
	},


	submit_tags: function( tag_cmds ){
		return this._tags_via_ajax(tag_cmds)
	}

};

function install_tag_server( selector, item_id ) {
	return $(selector)
		.attr('tag-server', item_id)
		.each(function(){
			$.extend(this, tag_server_fns)
		})
}


function refresh_tags( selector ){
	return $(selector)
		.nearest_parent('[tag-server]')
			.each(function(){ this.fetch_tags() })
		.end()
}



function bare_tag( t ) {
	try {
		// XXX what are the real requirements for a tag?
		return /[a-z][a-z0-9]*/.exec(t.toLowerCase())[0]
	} catch (e) {
		// I can't do anything with it; I guess you must know what you're doing
		return t
	}
}


function set_context_from_tags( root, tags ) {
	var context = $.map(split_if_string(tags), function(k){
		if ( k in context_triggers )
			return k
	}).reverse()[0] || undefined;

	var is_nodnix_context = context=='nod' || context=='nix';

	$('.tag-widget', root)
		.each(function(){
			if ( this.set_context )
				this.set_context(
					($(this).hasClass('nod-nix-reasons') == is_nodnix_context)
						? context
						: undefined
				)
		})
}


function form_submit_tags( form ){
	var $form = $(form);
	var $input = $('.tag-entry:input', form);
	var $server = $form.nearest_parent('[tag-server]');

	$server.each(function(){
		var tag_cmds = $input.val();
		$input.val('');
		this.submit_tags(tag_cmds);
		set_context_from_tags(this, tag_cmds);
	})
}


function click_tag( event ) {
	var $this = $(this);

	var $tag_el = $this.find('.tag').andSelf().eq(0);
	var tag = $tag_el.text();
	var op	= $(event.target).text();

	var its_the_capsule = op==tag && (op=='+' || op=='-');
	if ( its_the_capsule ) {
		tag = { '+': 'nod', '-': 'nix' }[op];
		op = '';
	}

	// op differs from tag when the click was in a menu
	//	so, if in a menu, or right on the tag itself, do something
	if ( (event.target!==this || its_the_capsule) && (op!==tag || event.target===$tag_el[0]) ) {
		var command = normalize_tag_menu_command(tag, op);
		var $server = $this.nearest_parent('[tag-server]');

		if ( event.shiftKey ) {
			// if the shift key is down, append the tag to the edit field
			$server.find('.tag-entry:text:visible').each(function(){
				if ( this.value ) {
					var last_char = this.value[ this.value.length-1 ];
					if ( '-#!)_ '.indexOf(last_char) == -1 )
						this.value += ' ';
				}
				this.value += command;
				this.focus();
			});
		} else {
			// otherwise, send it the server to be processed
			$server.each(function(){
				this.submit_tags(command)
			});
		}

		set_context_from_tags($server, tag)
	}

}


var tag_display_fns = {

	// return a dictionary mapping bare tags to the corresponding *.tag DOM element
	map_tags: function( how ){
		// we may limit the result, if the caller says how
		var map_fn;
		if ( !how )
			// no limit, return a set of all my tags
			map_fn = function(){return true}
		else if ( $.isFunction(how) )
			// the caller supplied a filter function
			//  return a set containing only tags for which how(bare_tag(t)) answers true
			map_fn = how;
		else {
			// how must be a list
			//  return a set that is the intersection of how and the tags I actually have
			var allowed_tags = map_list_to_set(how, bare_tag);
			map_fn = function(bt){return bt in allowed_tags}
		}

		// now that we know how, iterate over my actual tags to build the result set
		var m = {};
		$('.tag', this).each(function(){
			var bt = bare_tag($(this).text());
			if ( map_fn(bt) )
				m[bt] = this
		});
		return m
	},


	// replace existing tags and/or add new tags; preserves order of existing tags
	//  optional string, how, tells where to add new tags { 'append', 'prepend' }
	//  optional string, annotate, tells a css class to add to all touched tags
	update_tags: function( tags, how, annotate ){
		// the intersection of the requested vs. existing tags are the ones I can update in-place
		var update_map = this.map_tags(tags = split_if_string(tags));

		// update in-place the ones we can; build a list of the ones we can't ($.map returns a js array)
		var new_tags_seen = {};
		var new_tags = $.map(tags, function(t){
			var bt = bare_tag(t);
			if ( bt in update_map )
				$(update_map[bt]).html(t);
			else if ( !(bt in new_tags_seen) ) {
				new_tags_seen[bt] = true;
				return t
			}
		});

		// a $ list of the actual .tag elements we updated in-place
		var $changed_tags = $(values(update_map));

		if ( new_tags.length ) {
			// construct all the completely new tag entries and associated machinery
			var $new_elems = $(join_wrap(new_tags, '<li><span class="tag">', '</span></li>'))
				.click(click_tag) // one click-handler per tag, and it's on the <li>
				.append(this.tag_display_data.menu_template);

			// by default, insert the new tags at the front of the list
			if ( how !== 'append' ) how = 'prepend';
			this.tag_display_data.$list_el[how]($new_elems);

			// add in a list of the actual .tag elements we created from scratch
			$changed_tags = $changed_tags.add( $new_elems.find('.tag') );
		}

		// for every .tag element we touched/created, fix the style to match the kind of tag and add annotate if supplied
		//   Use case for annotate: the tag was modified locally, we mark it with "local-only" until the server
		//   comes back with a complete list in response that will wipe out the "local-only" style, essentially
		//   confirming the user's change has been recorded
		var base_classes = 'tag' + (annotate ? ' '+annotate : '');
		$changed_tags.each(function(){
			var style = local_style_for($(this).text());
			this.className = style ? base_classes + ' ' + style : base_classes
		});
		return this
	},


	remove_tags: function( tags ){
		// when called without an argument, removes all tags, otherwise
		//   tags to remove may be specified by string, an array, or the result of a previous call to map_tags
		if ( !tags || tags.length )
			tags = this.map_tags(tags);

		$.each(tags, function(bt, entry){
			$(entry).parents('li').eq(0).remove()
		});
		return this
	},


	// like remove_tags() followed by update_tags(tags) except order preserving for existing tags
	set_tags: function( tags ){
		var allowed_tags = map_list_to_set(tags = split_if_string(tags), bare_tag);
		this.remove_tags(this.map_tags(function(bt){
			return !(bt in allowed_tags)
		}));
		return this.update_tags(tags, 'append')
	},


	receive_broadcast: function( tags ){
		this.set_tags(tags)
	}

}; // tag_display_fns


// XXX temporarily handle some special cases myself.
// Jamie will want to know about this.
function normalize_nodnix( expr ){
	return expr.replace(_normalize_nodnix.pattern, _normalize_nodnix)
}

function normalize_no_nodnix( expr ){
	return expr.replace(_normalize_nodnix.pattern, '')
}

function _normalize_nodnix( cmd ){
	if ( cmd == 'nod' || cmd == '!nix' )
		return 'nod -nix';
	else if ( cmd == 'nix' || cmd == '!nod' )
		return 'nix -nod';
	else if ( cmd == '-!nix' )
		return '-nod';
	else if ( cmd == '-!nod' )
		return '-nix';
	else
		return cmd;
}
_normalize_nodnix.pattern = /-!(nod|nix)|-(nod|nix)|!(nod|nix)|nod|nix/g;

function normalize_tag_menu_command( tag, op ){
	if ( op == "x" )
		return '-' + tag;
	else if ( tag.length > 1 && op.length == 1 && op == tag[0] )
		return tag.slice(1);
	else if ( op != tag )
		return op + tag;
	else
		return tag;
}


var tag_widget_fns = {

	init: function(){
		$init_tag_displays($('.tag-display.stub, [listen]:not([class])', this));

		// XXX testing autocomplete
		$(this).find('.tag-entry').autocomplete('/ajax.pl', {
			loadingClass:		'working',
			minChars:		3,
			multiple:		true,
			multipleSeparator:	' ',
			autoFill:		true,
			max:			25,
			extraParams: {
				op:		'tags_list_tagnames'
			},
			formatItem: function(row /*, i, N, query*/){
				return row.split(/\s+/)[0]
			}
		});
		return this
	},


	set_context: function( context ){
		var suggestions = suggestions_for_context[context]
				|| ( (context in context_triggers)
						? suggestions_for_context['default']
						: '' );
		$('.ready[listen=context]', this)
			.each(function(){
				this.set_tags(suggestions)
			})[context && suggestions ? 'show' : 'hide']()
	},


	open: function(){
		// $(this).nearest_parent('[tag-server]').addClass('tagging');
		$(this)
			.filter(':hidden')
			.slideDown(100)
			.find(':text').eq(0)
				.each(function(){
					this.focus()
				});
		return this
	},


	close: function(){
		// $(this).nearest_parent('[tag-server]').removeClass('tagging');
		$(this)
			.filter(':visible')
			.slideUp(100);
		return this
	}

}; // tag_widget_fns


function open_tag_widget( selector, fetch ){
	var $widgets = $init_tag_widgets($(selector).filter(':hidden'));

	if ( fetch ) {
		$widgets.nearest_parent('[tag-server]')
			.each(function(){
				this.fetch_tags()
			})
	}

	return $widgets.each(function(){this.open()})
}

function close_tag_widget( selector ){
	return $(selector).filter(':visible').each(function(){this.close()})
}

function close_tag_widget_event( event ){
	close_tag_widget($(this).nearest_parent('.tag-widget'))
}



function $init_tag_displays( selector, options ){
	options = options || {};

	var $tag_displays = $(selector);

	// <div listen="user" label="My Tags">tag1 tag2 tag3</div>
	$tag_displays
		.each(function(){
			var $this = $(this);

			var menu_template = join_wrap(
				$this.attr('menu') || $init_tag_displays.menu_templates[$this.attr('listen')] || '',
				'<li>', '</li>',
				'<ul class="tmenu">', '</ul>'
			);

			var t, legend = (t=$this.attr('label')) ? '<h1 class="legend">' + t + '</h1>' : '';

			var tags = $this.text();
			$this.html(legend+'<ul></ul>');

			$.extend(
				this,
				tag_display_fns,
				{ tag_display_data: {
					menu_template:	menu_template,
					$list_el:	$this.find('ul')
				} },
				options
			);

			if ( tags ) this.set_tags(tags);
		})
		.addClass('tag-display ready')
		.removeClass('stub')
		.removeAttr('menu')
		.removeAttr('label');

	return $tag_displays
}

function $init_tag_widgets( selector, options ){
	options = options || {};

	var $tag_widgets = $(selector);

	$tag_widgets
		.filter('.stub')
			.each(function(){
				$.extend(
					this,
					tag_widget_fns,
					options
				).init()
			})
			.removeClass('stub');

	return $tag_widgets
}

$init_tag_displays.menu_templates = {
	user:	'! x',
	top:	'_ # ! )'
}




// when the tag-widget is used in the firehose:
function add_firehose_nodnix_glue( parent ){

	// XXX do this in a template, and change this to an 'init' type function
	var $parent = $(parent)
		.append('<div class="tag-widget nod-nix-reasons stub" style="display:none">' +
				'<div class="tag-display stub" listen="context" />' +
				'<div class="firehose-listener" listen="vote" style="display:none" />' +
			'</div>');

	// add a special widget to show the nod/nix suggestions (right in the title bar)
	var $widgets = $parent.find('.nod-nix-reasons');
	$init_tag_widgets(
		$widgets,

		// override tag_widget_fns.set_context so this widget can hide/show based on context
		{
			set_context: function( context ){
				var widget = this;
				if ( context == 'nod' || context == 'nix' ) {
					// for nod or nix, show the associated suggestions
					var suggestions = suggestions_for_context[context];
					$('.ready[listen=context]', this)
						.each(function(){
							this.set_tags(suggestions)
						})
						// and depart that context with the very first selection
						.one("click", function(){
							widget.set_context(/*no context*/)
						});
					widget.open()
				} else {
					// for any other context (including no context), be hidden
					widget.close()
				}
			}
		}
	);

	// add a 'listener' to fix the up/down vote
	$widgets.find('.firehose-listener[listen=vote]')
		.each(function(){
			$.extend(
				this,
				{
					receive_broadcast: function( tags ){
						firehose_fix_up_down(
							$(this).nearest_parent('[tag-server]').attr('tag-server'),
							{ nod: 'votedup', nix: 'voteddown' }[tags] || 'vote'
						)
					}
				}
			)
		})
		.addClass('ready');

}



/*
	'u'	user tag
	't'	top tag
	's'	system tag
	'd'	data type
	'e'	editor tag ('hold', 'back', etc)
	'f'	feedback tag ('error', 'dupe', etc)
	'p'	private tag
	't2'	topic
	's1'	section
	'y'	nod
	'x'	nix
	'bang'
	'pound'
	'paren'
	'underscore'
 */

var context_triggers = map_list_to_set(['nod', 'nix', 'submission','journal','bookmark','feed','story','vendor','misc','comment','discussion']);

var well_known_tags = {};

$(function(){
	update_style_map(well_known_tags, 's1', YAHOO.slashdot.sectionTags);
	update_style_map(well_known_tags, 't2', YAHOO.slashdot.topicTags);
	update_style_map(well_known_tags, 'f', YAHOO.slashdot.feedbackTags);
	update_style_map(well_known_tags, 'e', YAHOO.slashdot.actionTags);
	update_style_map(well_known_tags, 'e', YAHOO.slashdot.fhitemOpts);
	update_style_map(well_known_tags, 'e', YAHOO.slashdot.storyOpts);
	update_style_map(well_known_tags, 'y p', ['nod']);
	update_style_map(well_known_tags, 'x p', ['nix']);
})

function update_style_map( style_map, style, tags ){
	var sp_style = ' ' + style;

	function update( tag ){
		if ( tag in style_map )
			style_map[tag] += sp_style
		else
			style_map[tag] = style
	}

	function update_from_set( key, value ){ update(key) }
	function update_from_list(){ update(this) }

	$.each(tags, (tags.length === undefined) ? update_from_set : update_from_list);
}

var tag_prefix_styles = {
	'!': 'bang',
	'#': 'pound',
	')': 'descriptive',
	'_': 'ignore'
};

function local_style_for( tag ){

	var style = '';
	var sep = '';

	function include( expr ){
		if ( expr ){
			style += sep + expr;
			sep = ' ';
		}
	}

	include(well_known_tags[bare_tag(tag)]);
	include(tag_prefix_styles[ tag[0] ]);

	return style;
}

var style_for_bar = { user: 'u', top: 't', system: 's' };

function style_tags_globally( widget ){
	var done = {};
	var style_map = {};

	// Step 1: build one big dictionary mapping tag names to 'global' styles
	// that is, styles we deduce from where a tag appears.  If a tag appears
	// in the user tag-display, then every occurance of that tag will be styled
	// to indicate that.

	// So, for each of the big three (user, top, system) tag-displays; extract
	// their tags, and update our style map with a class for that display
	$('.tag-display.ready[listen]', widget).each(function(){
		var display = $(this).attr('listen');
		var style = style_for_bar[display];

		// style true for a display that exclusively gets one of the big three
		// so: if it's one of the big three that we haven't yet seen...
		if ( style && !done[display] ){
			update_style_map(
				style_map,
				style,

				// build an array of all the tag names in this display
				$('span.tag', this).map(function(){
					return $(this).text()
				})
			);
			done[display] = true;
		}
	});

	// style_map now contains every tag in the user, top, and system displays
	// (i.e., all tags that globally influence each other) and maps those
	// tag names to strings containing a style class for each display in which
	// the tag appeared, e.g., if 'hello' is in both the user and top tag
	// displays, then style_map['hello'] == 'u t' (mod order)

	// Step 2: for tags that are sections, topics, etc., add corresponding styles
	$.each(style_map, function(k, v){
		var local_styles = local_style_for(k);
		if ( local_styles )
			style_map[k] += ' ' + local_styles;
	});

	// Step 3: find every tag span and apply the styles we've calculated
        $('.tag-display span.tag', widget).each(function(){
		var $this = $(this);
		var tag = $this.text();

		var class_list = '';
		if ( tag in style_map )
			// we saw this tag, and know all the styles
			class_list = style_map[tag];
		else {
			// didn't see this tag on the global phase, so it has
			// no global styles, but it _might_ still have local
			// which we'll cache in case we see this tag again
			var local_styles = style_map[tag] = local_style_for(tag);
			if ( local_styles ) {
				class_list = local_styles;
			}
		}

		$this.parent().setClass(class_list);
		this.className = class_list ? 'tag '+class_list : 'tag';
        })
}
