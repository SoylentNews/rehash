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
			recompute_css_classes(this, $listeners);
		}
		return this
	},

	_tags_via_ajax: function( tag_cmds ){
		if ( tag_cmds ) {
			tag_cmds = normalize_tag_commands(tag_cmds, /*excluding: user tags under */this);

			// if caller wanted to execute some commands,
			//	but they were all normalized away
			if ( !tag_cmds.length )
				// ...then there's no work to do (not even fetching)
				return this;


			// 'harden' the new tags into the user tag-display, but styled 'not-saved'
			// tags in the response from the server will wipe-out 'not-saved'
			var command_feedback = normalize_tag_commands(tag_cmds, /*excluding:*/nodnix_commands);
			$('.tag-display.ready[listen*=user]', this).each(function(){
				this.update_tags(command_feedback, 'prepend', 'not-saved')
			});
		}

		var server = this;
		var $busy = $('.tag-server-busy', server).show();
		$.post('/ajax.pl', {
			op:	'tags_setget_combined',
			id:	$(this).attr('tag-server'),
			tags:	list_as_string(tag_cmds),
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
	var context = $.map(list_as_array(tags), function(k){
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

	var $target = $(event.target);

	var command='';

	if ( $target.is('a.up') ) {
		command = 'nod';
	} else if ( $target.is('a.down') ) {
		command = 'nix';
	} else if ( $target.is('.tag') ) {
		command = $target.text();
	} else if ( $target.is('.tmenu li') ) {
		var op = $target.text();
		var tag = $target.nearest_parent(':has(span.tag)').find('.tag').text();
		command = normalize_tag_menu_command(tag, op);
	}

	if ( command ) {
		var $server = $this.nearest_parent('[tag-server]');

		if ( event.shiftKey ) {
			// if the shift key is down, append the tag to the edit field
			$server.find('.tag-entry:text:visible:first').each(function(){
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

		set_context_from_tags($server, command)
	}
}


var tag_display_fns = {

	// return a dictionary mapping bare tags to the corresponding *.tag DOM element
	map_tags: function( how ){
		// map_tags() does not add, remove, or alter any tags

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
		// invariant: before.count_tags() <= after.count_tags()
		// no other call adds tags (except by calling _me_)

		// the intersection of the requested vs. existing tags are the ones I can update in-place
		var update_map = this.map_tags(tags = list_as_array(tags));

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
			var $new_elems = $(join_wrap(new_tags, '<li class="p"><span class="tag">', '</span></li>'))
				.append(this.tag_display_data.menu_template);

			// by default, insert the new tags at the front of the list
			if ( how !== 'append' ) how = 'prepend';
			this.tag_display_data.$list_el[how]($new_elems);

			// add in a list of the actual .tag elements we created from scratch
			$changed_tags = $changed_tags.add( $new_elems.find('.tag') );

			this.mark_if_empty(false);
		}

		// for every .tag we added/changed, fix parent <li>'s css class(es)
		//   Use case for annotate: the tag was modified locally, we mark it with "not-saved" until the server
		//   comes back with a complete list in response that will wipe out the "not-saved" class, essentially
		//   confirming the user's change has been recorded
		$changed_tags.each(function(){
			var $tag = $(this);
			$tag.parent()
				.removeClass()
				.addClass(static_css_classes_for($tag.text()) + ' ' + (annotate||''));
		});
		return this
	},


	remove_tags: function( tags ){
		// invariant: before.count_tags() >= after.count_tags()
		// no other call removes tags (except by calling _me_)

		// when called without an argument, removes all tags, otherwise
		//   tags to remove may be specified by string, an array, or the result of a previous call to map_tags
		if ( !tags || tags.length )
			tags = this.map_tags(tags);

		$.each(tags, function(bt, entry){
			$(entry).parents('li:first').remove()
		});
		return this.mark_if_empty()
	},


	// like remove_tags() followed by update_tags(tags) except order preserving for existing tags
	set_tags: function( tags ){
		var allowed_tags = map_list_to_set(tags = list_as_array(tags), bare_tag);
		this.remove_tags(this.map_tags(function(bt){
			return !(bt in allowed_tags)
		}));
		return this.update_tags(tags, 'append')
	},


	mark_if_empty: function( if_empty ){
		var $this = $(this);
		if ( if_empty === undefined )
			if_empty = ! $this.is(':has(span.tag)');
		return $this.toggleClassTo('no-tags', if_empty)
	},


	mark_dirty: function( if_dirty ){
		return $(this).toggleClassTo('dirty', if_dirty)
	},


	receive_broadcast: function( tags ){
		return this.set_tags(tags)
	}

}; // tag_display_fns

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
			$this.removeAttr('menu');

			var t, legend = (t=$this.attr('label')) ? '<h1 class="legend">' + t + '</h1>' : '';
			$this.removeAttr('label');

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
			$this.addClass('tag-display ready no-tags dirty').removeClass('stub');

			if ( tags ) this.set_tags(tags);
		})
		.click(click_tag) // one click-handler per display

	return $tag_displays
}


function cached_user_tags( selector ){
	var $selector = $(selector);

	var tags = $selector
		.find('.tag-display.ready[listen=user] span.tag')
			.map(function(){
				return $(this).text()
			})
			.get();

	var vote = $selector.nearest_parent('[tag-server]').find('[id^=updown-]').attr('className');
	vote = { 'votedup':'nod', 'voteddown':'nix' }[vote];

	if ( vote )
		tags.push(vote);

	return tags
}

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



// Tags.pm doesn't automatically handle '!(nod|nix)'
//	and requires (some) hand-holding to prevent an item from being tagged both nod and nix at once
var nodnix_commands = {
	'nod':		['nod', '-nix'],
	'nix':		['nix', '-nod'],
	'!nod':		['nix', '-nod'],
	'!nix':		['nod', '-nix'],
	'-nod':		['-nod'],
	'-nix':		['-nix'],
	'-!nod':	['-nix'],
	'-!nix':	['-nod']
};

// filters commands, returning a list 'normalized' (as per comment at 'nodnix_commands', above)
// and omitting any "add" commands for tags in excludes, or "deactivate" commands for tags _not_ in excludes
// commands is a list (string or array)
// excludes is either a list or set of tags/commands to remove,
//	or else a jQuery selector (DOM element, string selector, or jQuery wrapped list) under which
//	exists a user tag list... we'll build the real exclusion list from that
function normalize_tag_commands( commands, excludes ){

	// want to iterate over commands, so ensure it is an array
	commands = list_as_array(commands);
	if ( !commands.length )
		return [];

	// beware, provide a complete list for excludes, or nothing at all,
	// else -tag commands can be dropped on the floor

	// want to repeatedly test for inclusion in excludes, so ensure excludes is a set
	if ( excludes )
		try {
			// if excludes looks like a string
			if ( excludes.split ) {
				// and that string works as a jQuery selector
				var $temp = $(excludes);
				if ( $temp.length )
					// treat it as such
					excludes = $temp;
				// otherwise a string is probably a space-separated command list
			}

			// if excludes is dom element or a jquery wrapped list...
			if ( excludes.nodeType !== undefined || excludes.jquery !== undefined )
				// ...caller means a list of the user tags within (returns an array)
				excludes = cached_user_tags(excludes);

			// if excludes is a list (string or array)...
			if ( excludes.length !== undefined )
				excludes = map_list_to_set(excludes);

			// excludes should already be a set, let's make sure it's not empty
			if ( !keys(excludes).length )
				excludes = null;
		} catch (e) {
			excludes = null;
		}

	var filter_minus = true;
	if ( !excludes ) {
		filter_minus = false;
		excludes = {};
	}

	function un( tag ){
		return tag[0]=='-' ? tag.substring(1) : '-'+tag
	}

	// .reverse(): process the commands from right to left
	// so only the _last_ occurance is kept in case of duplicates
	var already = {};
	return $.map(commands.reverse(), function( c ){
		var mapped = [];
		$.each(c in nodnix_commands ? nodnix_commands[c] : [c], function(i, cmd){
			if ( cmd
				&& !(cmd in already)
				&& !(cmd in excludes)
				&& ( !filter_minus
					|| cmd[0] != '-'
					|| un(cmd) in excludes ) ) {
				mapped.push(cmd);
				already[ cmd ] = true;
				already[ un(cmd) ] = true;
			}
		});

		return mapped
	}).reverse()
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
			})
	},


	open: function(){
		// $(this).nearest_parent('[tag-server]').addClass('tagging');
		$(this)	.filter(':hidden')
				.slideDown(100)
				.find(':text:visible:first')
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
		.append('<div class="tag-widget nod-nix-reasons stub">' +
				'<div class="tag-display stub" listen="context" />' +
				'<div class="firehose-listener" listen="vote" />' +
			'</div>');

	// add a special widget to show the nod/nix suggestions (right in the title bar)
	var $widgets = $parent.find('.nod-nix-reasons');
	open_tag_widget($init_tag_widgets($widgets));

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
	update_class_map(well_known_tags, 's1', YAHOO.slashdot.sectionTags);
	update_class_map(well_known_tags, 't2', YAHOO.slashdot.topicTags);
	update_class_map(well_known_tags, 'f', YAHOO.slashdot.feedbackTags);
	update_class_map(well_known_tags, 'e', YAHOO.slashdot.actionTags);
	update_class_map(well_known_tags, 'e', YAHOO.slashdot.fhitemOpts);
	update_class_map(well_known_tags, 'e', YAHOO.slashdot.storyOpts);
	update_class_map(well_known_tags, 'y p', ['nod']);
	update_class_map(well_known_tags, 'x p', ['nix']);
})

function update_class_map( css_class_map, css_class, tags ){
	var sp_css_class = ' ' + css_class;

	function update( tag ){
		if ( tag in css_class_map )
			css_class_map[tag] += sp_css_class
		else
			css_class_map[tag] = css_class
	}

	function update_from_set( key, value ){ update(key) }
	function update_from_list(){ update(this) }

	$.each(tags, (tags.length === undefined) ? update_from_set : update_from_list);
}

var css_classes_for_prefix = {
	'!': 'bang',
	'#': 'pound',
	')': 'descriptive',
	'_': 'ignore'
};

function static_css_classes_for( tag ){

	var css_class = '';
	var sep = '';

	function include( expr ){
		if ( expr ){
			css_class += sep + expr;
			sep = ' ';
		}
	}

	include(well_known_tags[bare_tag(tag)]);
	include(css_classes_for_prefix[ tag[0] ]);

	return css_class
}

var css_class_for_listen = { user: 'u', top: 't', system: 's' };

function recompute_css_classes( root ){
	var already = {};
	var computed_css_classes_for = {};

	var $displays = $('.tag-display', root);

	// Step 1: build one big dictionary mapping tag names to 'computed' css classes
	// that is, classes we deduce from where a tag appears.  If a tag appears
	// in the user tag-display, then every occurance of that tag will be styled
	// to indicate that.

	// So, for each of the big three (user, top, system) tag-displays; extract
	// their tags, and update our css class map for that display
	$displays
		.filter('.ready[listen]:not(.no-tags)')
			.each(function(){
				var display = $(this).attr('listen');
				var css_class = css_class_for_listen[display];

				// css_class true for a display that exclusively gets one of the big three
				// so: if it's one of the big three that we haven't yet seen...
				if ( css_class && !already[display] ){
					update_class_map(
						computed_css_classes_for,
						css_class,

						// build an array of all the tag names in this display
						$('span.tag', this).map(function(){
							return $(this).text()
						})
					);
					already[display] = true;
				}
			});

	// computed_css_classes_for now contains every tag in the user, top, and system displays
	// (i.e., all tags that globally influence each other) and maps those
	// tag names to strings containing a css class for each display in which
	// the tag appeared, e.g., if 'hello' is in both the user and top tag
	// displays, then computed_css_classes_for['hello'] == 'u t' (mod order)

	// Step 2: for tags that are sections, topics, etc., add corresponding classes
	$.each(computed_css_classes_for, function(k, v){
		var static_css_classes = static_css_classes_for(k);
		if ( static_css_classes )
			computed_css_classes_for[k] += ' ' + static_css_classes;
	});

	// Step 3: find every tag span and apply the css classes we've calculated
	$displays
		.find('span.tag')
			.each(function(){ // for each tag
				var $tag = $(this);
				var tag = $tag.text();

				var class_list = '';
				if ( tag in computed_css_classes_for )
					// we saw this tag, and know all the classes
					class_list = computed_css_classes_for[tag];
				else {
					// didn't see this tag on the global phase, so it has
					// no 'computed' classes, but it _might_ still have static classes
					// which we'll cache in case we see this tag again
					var static_css_classes = computed_css_classes_for[tag] = static_css_classes_for(tag);
					if ( static_css_classes ) {
						class_list = static_css_classes;
					}
				}

				$tag.parent().setClass(class_list);
			})
		.end()
		.filter('[listen=user]')
			.each(function(){ // for each display of user tags
				var $this = $(this);
				$this.toggleClassTo(
					'no-visible-tags',
					! $this.is(':has(li.u:not(.t,.s,.p))')
				)
			})
}
