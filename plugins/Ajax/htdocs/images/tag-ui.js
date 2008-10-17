; // tag-ui.js

var context_triggers, well_known_tags;

function animate_wiggle( $selector ){
	$selector.
		animate({left: '-=3px'}, 20).
		animate({left: '+=6px'}, 20).
		animate({left: '-=6px'}, 20).
		animate({left: '+=6px'}, 20).
		animate({left: '-=3px'}, 20).
		queue(function(){
			$(this).css({left: ''}).dequeue();
		});
}


var tag_server_fns = {

	broadcast_tag_lists: function( broadcasts, options ){
		var tuples = ('<notify>' + broadcasts).split(/\n?<([\w:]*)>/).slice(1);
		if ( tuples && tuples.length >= 2 ) {
			var $listeners = $('.ready[context]', this);

			// work backwards so 'notify' context is last
			while ( tuples.length >= 2 ) {
				var data = tuples.pop();
				var context = tuples.pop();
				var context_name = context.split(':')[0];

				$listeners.filter('[context*=' + context_name + ']').each(function(){
					if ( this.receive_broadcast ) {
						this.receive_broadcast(data, context, options);
					}
				});
			}
			recompute_css_classes(this, $listeners);
		}
		return this;
	},


	preprocess_commands: function( commands, options ){
		var server = this;
		$.each(this.command_pipeline, function(i, handler){
			commands = handler.apply(server, [ commands, options ]);
		});

		return commands;
	},


	_ajax_request: function( tag_cmds, options ){

		var feedback_options = $.extend(
			{},
			{ // default feedback
				order:		'append',
				classes:	'not-saved'
			},
			options );

		var key = Slash.ArticleInfo.key(this);

		var server_params = $.extend(
			{},
			{ // default params for the server-side handler
				op:		'tags_setget_combined',
				key:		key.key,
				key_type:	key.key_type,
				reskey:		reskey_static,
				limit_fetch:	''
			},
			options );

		server_params.tags = '';

		if ( tag_cmds ) {
			tag_cmds = normalize_tag_commands(
				this.preprocess_commands(list_as_array(tag_cmds), options),
				this );

			// if caller wanted to execute some commands,
			//	but they were all normalized away
			if ( !tag_cmds.length ) {
				// ...then there's no work to do (not even fetching)
				return this;
			}


			// 'harden' the new tags into the user tag-display, but styled 'not-saved'
			// tags in the response from the server will wipe-out 'not-saved'
			var $user_displays = $('.tag-display.ready[context*=user]', this);
			$user_displays.each(function(){
				this.update_tags(tag_cmds, feedback_options);
			});

			// Just for fun...
			if ( options && options.classes ) {
				animate_wiggle($user_displays.find('.'+options.classes + ':not(:contains("-"))'));
			}

			server_params.tags = list_as_string(tag_cmds);
			// console.log('SENDING: '+server_params.tags);
		}


		var tag_server = this.mark_busy(true);
		$.ajax($.extend(
			{},
			{
				url:		'/ajax.pl',
				type:		'POST',
				dataType:	'text',
				data:		server_params,
				success: 	function( server_response ){
							// console.log('RECEIVED: '+server_response);
							tag_server.broadcast_tag_lists(server_response, options);
						},
				complete: 	function(){
							tag_server.mark_busy(false);
						}
			},
			options && options.ajax ));
		return this;
	},


	fetch_tags: function( options ){
		return this._ajax_request('', options);
	},


	submit_tags: function( tag_cmds, options ){
		return this._ajax_request(tag_cmds, options);
	},


	mark_busy: function( if_busy ){
		var was_busy = this.busy_depth > 0;
		this.busy_depth += if_busy ? 1 : -1;
		var now_busy = this.busy_depth > 0;

		if ( now_busy != was_busy ) {
			var $busy = $('.tag-server-busy', this);
			if ( now_busy ) {
				$busy.show();
			} else {
				$busy.removeAttr('style');
			}
		}

		return this;
	}

};

function install_tag_server( selector, item_id ) {
	if ( item_id === undefined ) {
		item_id = '*';
	}

	return $(selector).
		attr('tag-server', item_id).
		each(function(){
			$.extend(this, tag_server_fns);
			this.busy_depth = 0;
			this.command_pipeline = [ normalize_nodnix ];
		});
}



function bare_tag( t ) {
	try {
		// XXX what are the real requirements for a tag?
		return /[a-z][a-z0-9]*/.exec(t.toLowerCase())[0];
	} catch (e) {
		// I can't do anything with it; I guess you must know what you're doing
		return t;
	}
}

function markup_tag( t ) {
	try {
		return t.replace(/^([^a-zA-Z]+)/, '<span class="punct">$1</span>');
	} catch (e) {
		return t;
	}
}


function form_submit_tags( form, options ){
	var $input = $('.tag-entry:input', form);
	$related_trigger = $input;
	$(form).nearest_parent('[tag-server]').
		each(function(){
			var tag_cmds = $input.val();
			$input.val('');
			this.submit_tags(tag_cmds, options);
		});
}


var tag_display_fns = {

	// return a dictionary mapping bare tags to the corresponding *.tag DOM element
	map_tags: function( how ){
		// map_tags() does not add, remove, or alter any tags

		// we may limit the result, if the caller says how
		var map_fn;
		if ( !how ) {
			// no limit, return a set of all my tags
			map_fn = function(){return true;};
		} else if ( $.isFunction(how) ) {
			// the caller supplied a filter function
			//  return a set containing only tags for which how(bare_tag(t)) answers true
			map_fn = how;
		} else {
			// how must be a list
			//  return a set that is the intersection of how and the tags I actually have
			var allowed_tags = map_list_to_set(how, bare_tag);
			map_fn = function(bt){return bt in allowed_tags;};
		}

		// now that we know how, iterate over my actual tags to build the result set
		var if_mapped_all = true, map = {};
		$('.tag', this).each(function(){
			var bt = bare_tag($(this).text());
			if ( map_fn(bt) ) {
				map[bt] = this;
			} else {
				if_mapped_all = false;
			}
		});
		return [ map, if_mapped_all ];
	},


	// replace existing tags and/or add new tags; preserves order of existing tags
	//  optional string, options.order, tells where to add new tags { 'append', 'prepend' }
	//  optional string, options.classes, tells a css class to add to all touched tags
	update_tags: function( tags, options ){
		options = $.extend(
			{},
			{
				order:		'append',
				classes:	''
			},
			options );

		// invariant: before.count_tags() <= after.count_tags()
		// no other call adds tags (except by calling _me_)

		// the intersection of the requested vs. existing tags are the ones I can update in-place
		var update_map = this.map_tags(tags = list_as_array(tags))[0];

		// update in-place the ones we can; build a list of the ones we can't ($.map returns a js array)
		var new_tags_seen = {};
		var new_tags = $.map(tags, function(t){
			var bt = bare_tag(t);
			var mt = markup_tag(t);
			if ( bt in update_map ) {
				$(update_map[bt]).html(mt);
			} else if ( !(bt in new_tags_seen) ) {
				new_tags_seen[bt] = true;
				return mt;
			}
		});

		// a $ list of the actual .tag elements we updated in-place
		var $changed_tags = $(values(update_map));

		if ( new_tags.length ) {
			// construct all the completely new tag entries and associated machinery
			var $new_elems = $(join_wrap(
					new_tags,
					'<li class="p"><span class="tag">',
					'</span></li>')).
				append(this.tag_display_data.menu_template);

			this.tag_display_data.$list_el[options.order]($new_elems);

			// add in a list of the actual .tag elements we created from scratch
			$changed_tags = $changed_tags.add( $new_elems.find('.tag') );

			this.$mark_empty(false);
		}

		// for every .tag we added/changed, fix parent <li>'s css class(es)
		//   Use case for options.classes: the tag was modified locally, we mark it with "not-saved" until the server
		//   comes back with a complete list in response that will wipe out the "not-saved" class, essentially
		//   confirming the user's change has been recorded
		$changed_tags.each(function(){
			var $tag = $(this);
			$tag.parent().
				removeClass().
				addClass(static_css_classes_for($tag.text()) + ' ' + options.classes);
		});
		return this;
	},


	remove_tags: function( tags, options ){
		var opts = $.extend({}, { fade_remove: 0 }, options);

		// invariant: before.count_tags() >= after.count_tags()
		// no other call removes tags (except by calling _me_)

		// when called without an argument, removes all tags, otherwise
		//   tags to remove may be specified by string, an array, or the result of a previous call to map_tags
		var if_remove_all;
		if ( !tags || tags.length ) {
			var mapped = this.map_tags(tags);
			tags = mapped[0];
			if_remove_all = mapped[1];
		}

		var $remove_li = $(values(tags)).parent();

		var display = this;
		if ( opts.fade_remove ) {
			$remove_li
				.fadeOut(opts.fade_remove)
				.queue(function(){
					$(this).remove().dequeue();
					if ( if_remove_all ) {
						display.$mark_empty();
					}
				});
		} else {
			$remove_li.remove();
			this.$mark_empty(if_remove_all);
		}

		return this;
	},


	// like remove_tags() followed by update_tags(tags) except order preserving for existing tags
	set_tags: function( tags, options ){
		var allowed_tags = map_list_to_set(tags = list_as_array(tags), bare_tag);
		var removed_tags = this.map_tags(function(bt){
			return !(bt in allowed_tags);
		})[0];

		return this.
			remove_tags(removed_tags, options).
			update_tags(tags, options);
	},


	$mark_empty: function( if_empty ){
		var $this = $(this);
		if ( if_empty === undefined ) {
			if_empty = ! $this.is(':has(span.tag)');
		}
		return $this.toggleClassTo('no-tags', if_empty);
	},


	$mark_dirty: function( if_dirty ){
		return $(this).toggleClassTo('dirty', if_dirty);
	},


	receive_broadcast: function( tags, context, options ){
		return this.set_tags(tags, options);
	}

}; // tag_display_fns


function markup_menu( label ){
	var css_class;
	if ( label in css_classes_for_prefix ) {
		css_class = css_classes_for_prefix[label];
	} else if ( label[0] in css_classes_for_prefix ) {
		css_class = css_classes_for_prefix[ label[0] ];
	} else if ( label == 'x' ) {
		css_class = css_classes_for_prefix['-'];
	} else {
		css_class = label;
	}

	return '<li class="'+css_class+'"><span>'+label+'</span></li>';
}


function $init_tag_displays( $stubs, options ){
	options = options || {};

	$stubs.
		each(function(){
			var $this = $(this);

			var init_data = $this.metadata({type:'attr', name:'init'});
			$this.removeAttr('init');

			var menu_items = '';
			if ( init_data.menu === undefined || init_data.menu === true ) {
				menu_items = $init_tag_displays.default_menu;
			} else if ( init_data.menu ) {
				menu_items = init_data.menu;
			}

			var menu_template = menu_items ? (
					'<ul class="tmenu">' +
					$.map(list_as_array(menu_items), function(label){
						return markup_menu(label);
					}).join('') +
					'</ul>' ) : '';

			var legend = init_data.legend ? '<h1 class="legend">' + init_data.legend + '</h1>' : '';

			var tags = $this.text();
			$this.html(legend+'<ul></ul>');

			$.extend(
				this,
				tag_display_fns,
				{
					tag_display_data: {
						menu_template:	menu_template,
						$list_el:	$this.find('ul')
					}
				},
				options );

			$this.mapClass({
				'tag-display-stub': 'tag-display ready no-tags dirty'
			});

			if ( tags ) {
				this.set_tags(tags);
			}
		});

	return $stubs;
}

$init_tag_displays.default_menu = 'x !';

$(function(){
	if ( fh_is_admin ) {
		$init_tag_displays.default_menu = 'x ! # ## _ ^';
	}
});


function cached_user_tags( selector ){
	return $(selector).
		find('.tag-display.ready[context=user] span.tag').
			map(function(){
				return $(this).text();
			}).
			get();
}

function normalize_tag_menu_command( tag, op ){
	if ( op == "x" ) {
		return '-' + tag;
	} else if ( tag.length > 1 && op.length == 1 && op == tag[0] ) {
		return tag.slice(1);
	} else if ( op != tag ) {
		return op + tag;
	} else {
		return tag;
	}
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

function normalize_nodnix( commands ){
	return $.map(commands, function( cmd ){
		return (cmd in nodnix_commands) ? nodnix_commands[cmd] : cmd;
	});
}

// filters commands, returning a list 'normalized' (as per comment at 'nodnix_commands', above)
// and omitting any "add" commands for tags in excludes, or "deactivate" commands for tags _not_ in excludes
// commands is a list (string or array)
// excludes is either a list or set of tags/commands to remove,
//	or else a jQuery selector (DOM element, string selector, or jQuery wrapped list) under which
//	exists a user tag list... we'll build the real exclusion list from that
function normalize_tag_commands( commands, excludes ){

	// want to iterate over commands, so ensure it is an array
	commands = list_as_array(commands);
	if ( !commands.length ) {
		return [];
	}

	// beware, provide a complete list for excludes, or nothing at all,
	// else -tag commands can be dropped on the floor

	// want to repeatedly test for inclusion in excludes, so ensure excludes is a set
	if ( excludes ) {
		try {
			// if excludes looks like a string
			if ( excludes.split ) {
				// and that string works as a jQuery selector
				var $temp = $(excludes);
				if ( $temp.length ) {
					// treat it as such
					excludes = $temp;
				}
				// otherwise a string is probably a space-separated command list
			}

			// if excludes is dom element or a jquery wrapped list...
			if ( excludes.nodeType !== undefined || excludes.jquery !== undefined ) {
				// ...caller means a list of the user tags within (returns an array)
				excludes = cached_user_tags(excludes);
			}

			// if excludes is a list (string or array)...
			if ( excludes.length !== undefined ) {
				excludes = map_list_to_set(excludes);
			}

			// excludes should already be a set, let's make sure it's not empty
			if ( !keys(excludes).length ) {
				excludes = null;
			}
		} catch (e) {
			excludes = null;
		}
	}

	var filter_minus = true;
	if ( !excludes ) {
		filter_minus = false;
		excludes = {};
	}

	function un( tag ){
		return tag[0]=='-' ? tag.substring(1) : '-'+tag;
	}

	// .reverse(): process the commands from right to left
	// so only the _last_ occurance is kept in case of duplicates
	var already = {};
	return $.map(commands.reverse(), function( cmd ){
		if ( cmd &&
			!(cmd in already) &&
			!(cmd in excludes) &&
			( !filter_minus ||
				cmd[0] != '-' ||
				un(cmd) in excludes ) ) {

			already[ cmd ] = true;
			already[ un(cmd) ] = true;
			return cmd;
		}
	}).reverse();
}


function $position_context_display( $display ){
	if ( ! $related_trigger || ! $related_trigger.length ) {
		return;
	}

	var RIGHT_PADDING = 18;

	var $entry = $display.nearest_parent('[tag-server]');
	var left_edge = $entry.offset().left;
	var right_edge = left_edge + $entry.width() - RIGHT_PADDING;

	var global_align = $related_trigger.offset().left;
	global_align = Math.max(left_edge, global_align);

	var need_minimal_fix = true;
	if ( $display.nearest_parent(':hidden').length===0 ) {
		try {
			var display_width = $display.children('ul:first').width();
			$display.css({
				right: '',
				width: display_width
			});

			global_align = Math.max(
				left_edge,
				Math.min(right_edge-display_width, global_align) );
			var distance = global_align - $display.offset().left;
			if ( distance ) {
				$display.animate({left: '+='+distance});
			}

			need_minimal_fix = false;
		} catch (e0) {
		}
	}

	if ( need_minimal_fix ) {
		try {
			var BROKEN_NEGATIVE_MARGIN_CALCULATION = -10;

			// we may not be visible, so can't trust offsetParent() on ourself
			// better get it from our parent
			var x_adjust = -$display.parent().offsetParent().offset().left;
			$display.css({
				left: global_align + x_adjust + BROKEN_NEGATIVE_MARGIN_CALCULATION,
				right: right_edge + x_adjust
			});
		} catch (e1) {
		}
	}

	return $display;
}

function $queue_reposition( $display, if_only_width ){
	return $display.queue(function(){
		$position_context_display($display, if_only_width).dequeue();
	});
}

var gFocusedText;
var $previous_context_trigger = $().filter();

var tag_widget_fns = {

	init: function(){
		$init_tag_displays($('.tag-display-stub', this));

		$(this).find('.tag-entry').
				focus(function(event){
					gFocusedText = this;
				}).
				blur(function(event){
					if ( gFocusedText === this ) {
						gFocusedText = null;
					}
				}).
				keypress(function(event){
					var ESC=27, SPACE=32;

					var $this = $(this);
					switch ( event.which || event.keyCode ) {
						case ESC:
							$this.val('');
							return false;
						case SPACE:
							var $form = $this.parent();
							setTimeout(function(){
								$form.trigger("onsubmit");
							}, 0);
							return true;
						default:
							return true;
					}
				}).
				autocomplete('/ajax.pl', {
					loadingClass:		'working',
					minChars:		3,
					autoFill:		true,
					max:			25,
					extraParams: {
						op:		'tags_list_tagnames'
					}
				}).
				result(function(){
					$(this).parent().trigger("onsubmit");
				});
		return this;
	},


	set_context: function( context, force ){
		var widget = this;
		if ( context ) {
			if ( context == this._current_context &&
				(!$previous_context_trigger.length ||
					$related_trigger[0] === $previous_context_trigger[0]) && !force ) {
				context = '';
			} else {
				if ( !(context in suggestions_for_context) && context in context_triggers ) {
					context = (this._current_context != 'default') ? 'default' : '';
				}

			}
		}

		// cancel any existing timeout... the context to be hidden is going away
		if ( this._context_timeout ) {
			clearTimeout(this._context_timeout);
			this._context_timeout = null;
		}

		// only have to set_tags on the display if the context really is changing
		if ( context != this._current_context ) {
			var context_tags = [];
			if ( context && context in suggestions_for_context ) {
				context_tags = list_as_array(suggestions_for_context[context]);
			}

			var has_tags = context_tags.length !== 0;

			$('.ready[context=related]', this)
				.each(function(){
					var display = this;
					var $display = $(display);

					var had_tags = $display.find('span.tag').length !== 0;

					// animations are automatically queued...
					if ( had_tags < has_tags ) {
						$display.css('display', 'none');
					} else if ( had_tags > has_tags ) {
						$display.slideUp(400);
					}
					// ...when regular code needs to synchronize with animation
					$display.queue(function(){
						// I have to queue that code up myself
						display.set_tags(context_tags, { classes: 'suggestion' });
						if ( has_tags && widget.modify_context ) {
							widget.modify_context(display, context);
						}
						$display.dequeue();
					});
					if ( has_tags ) {
						$queue_reposition($display);
						if ( !had_tags ) {
							$queue_reposition($display.slideDown(400));
						}
					}
				});

			this._current_context = context;
		} else if ( context &&
			$related_trigger.length &&
			$previous_context_trigger.length &&
			$previous_context_trigger[0] !== $related_trigger[0] ) {

			$position_context_display($('.ready[context=related]', this));
		}

		$previous_context_trigger = $related_trigger;

		// if there's a context to hide, and hiding on a timeout is requested...
		if ( context && this.tag_widget_data.context_timeout ) {
			this._context_timeout = setTimeout(function(){
				widget.set_context();
			}, this.tag_widget_data.context_timeout);
		}

		return this;
	},
	toggle_widget: function( twisty ){
		var $tag_widget = $(twisty).
			find('.button').
				toggleClasses('expand', 'collapse').
				nearest_parent('.tag-widget').
					toggleClass('expanded');

		if ( $tag_widget.is('.expanded') ) {
			$tag_widget.
				nearest_parent('[tag-server]').
					each(function(){
						this.fetch_tags();
					});
		}
	}

}; // tag_widget_fns

function $init_tag_widgets( $stubs, options ){
	options = options || {};

	$stubs
		.each(function(){
			var $this = $(this);

			var init_data = $this.metadata({type:'attr', name:'init'});
			$this.removeAttr('init');

			var local_state = { tag_widget_data: {} };
			if ( init_data.context_timeout ) {
				local_state.tag_widget_data.context_timeout = init_data.context_timeout;
			}

			$.extend(
				this,
				tag_widget_fns,
				local_state,
				options ).
				init();
		}).
		mapClass({'tag-widget-stub': 'tag-widget'});

	return $stubs;
}










/*
	'w'	warning
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


function update_class_map( css_class_map, css_class, tags ){
	var sp_css_class = ' ' + css_class;

	function update( tag ){
		if ( tag in css_class_map ) {
			css_class_map[tag] += sp_css_class;
		} else {
			css_class_map[tag] = css_class;
		}
	}

	function update_from_set( key, value ){ update(key); }
	function update_from_list(){ update(this); }

	$.each(tags, (tags.length === undefined) ? update_from_set : update_from_list);
}

$(function(){

YAHOO.slashdot.sectionTags = [ "apache",
"apple",
"askslashdot",
"awards",
"backslash",
"books",
"bsd",
"developers",
"entertainment",
"features",
"games",
"hardware",
"interviews",
"it",
"linux",
"mainpage",
"news",
"politics",
"polls",
"radio",
"science",
"search",
"tacohell",
"technology",
"vendors",
"vendor_amd",
"yro" ];

YAHOO.slashdot.topicTags = ["keyword",
"mainpage",
"apache",
"apple",
"askslashdot",
"awards",
"books",
"bsd",
"developers",
"features",
"games",
"interviews",
"polls",
"radio",
"science",
"search",
"tacohell",
"yro",
"be",
"caldera",
"comdex",
"debian",
"digital",
"gimp",
"encryption",
"gnustep",
"internet",
"links",
"movies",
"money",
"pilot",
"starwars",
"sun",
"usa",
"x",
"xmas",
"linux",
"java",
"microsoft",
"redhat",
"spam",
"quake",
"ie",
"netscape",
"enlightenment",
"cda",
"gnu",
"intel",
"eplus",
"aol",
"kde",
"doj",
"slashdot",
"wine",
"tech",
"bug",
"tv",
"unix",
"gnome",
"corel",
"humor",
"ibm",
"hardware",
"amiga",
"sgi",
"compaq",
"music",
"amd",
"suse",
"quickies",
"perl",
"ed",
"mandrake",
"media",
"va",
"linuxcare",
"graphics",
"censorship",
"mozilla",
"patents",
"programming",
"privacy",
"toys",
"space",
"transmeta",
"announce",
"linuxbiz",
"upgrades",
"turbolinux",
"editorial",
"slashback",
"anime",
"php",
"ximian",
"journal",
"security",
"hp",
"desktops",
"imac",
"media",
"networking",
"osnine",
"osx",
"portables",
"utilities",
"wireless",
"portables",
"software",
"ent",
"biz",
"media",
"gui",
"os",
"biotech",
"books",
"wireless",
"printers",
"displays",
"storage",
"lotr",
"matrix",
"windows",
"classic",
"emulation",
"fps",
"nes",
"pcgames",
"portablegames",
"puzzlegames",
"rpg",
"rts",
"xbox",
"ps2",
"gamecube",
"wii",
"scifi",
"communications",
"robotics",
"google",
"it",
"politics",
"military",
"worms",
"databases",
"hardhack",
"novell",
"republicans",
"democrats",
"mars",
"inputdev",
"math",
"moon",
"networking",
"supercomputing",
"power",
"sony",
"nintendo",
"e3",
"nasa",
"yahoo",
"vendors",
"vendor_amd",
"vendor_amd_64chip",
"vendor_amd_announce",
"vendor_amd_ask",
"vendor_amd_64fx",
"vendor_amd_laptops",
"vendor_amd_multicore",
"vendor_amd_ostg",
"backslash" ];


	var data_types = [
		'submission',
		'journal',
		'bookmark',
		'feed',
		'story',
		'vendor',
		'misc',
		'comment',
		'discussion',
		'project'
	];

	context_triggers = map_list_to_set(data_types);


	well_known_tags = {};
	update_class_map(well_known_tags, 's1', YAHOO.slashdot.sectionTags);
	update_class_map(well_known_tags, 't2', YAHOO.slashdot.topicTags);
	update_class_map(well_known_tags, 'y p', ['nod', 'metanod']);
	update_class_map(well_known_tags, 'x p', ['nix', 'metanix']);
	update_class_map(well_known_tags, 'd', data_types);

	if ( fh_is_admin ) {
		update_class_map(well_known_tags, 'w p', ['signed', 'unsigned', 'signoff']);
	}
});

var css_classes_for_prefix = {
	'!': 'bang',
	'#': 'pound',
	')': 'descriptive',
	'_': 'ignore',
	'-': 'minus'
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

	return css_class;
}

var css_class_for_context = { user: 'u', top: 't', system: 's' };

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
	$displays.
		filter('.ready[context]:not(.no-tags)').
			each(function(){
				var display = $(this).attr('context');
				var css_class = css_class_for_context[display];

				// css_class true for a display that exclusively gets one of the big three
				// so: if it's one of the big three that we haven't yet seen...
				if ( css_class && !already[display] ) {
					update_class_map(
						computed_css_classes_for,
						css_class,

						// build an array of all the tag names in this display
						$('span.tag', this).map(function(){
							return $(this).text();
						}) );
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
		if ( static_css_classes ) {
			computed_css_classes_for[k] += ' ' + static_css_classes;
		}
	});

	// Step 3: find every tag span and apply the css classes we've calculated
	$displays.
		find('span.tag').
			each(function(){ // for each tag
				var $tag = $(this);
				var tag = $tag.text();

				var class_list = '';
				if ( tag in computed_css_classes_for ) {
					// we saw this tag, and know all the classes
					class_list = computed_css_classes_for[tag];
				} else {
					// didn't see this tag on the global phase, so it has
					// no 'computed' classes, but it _might_ still have static classes
					// which we'll cache in case we see this tag again
					var static_css_classes = (computed_css_classes_for[tag] = static_css_classes_for(tag));
					if ( static_css_classes ) {
						class_list = static_css_classes;
					}
				}

				$tag.parent().setClass(class_list);
			}).
		end().
		filter('[context=user]').
			each(function(){ // for each display of user tags
				var $this = $(this);
				$this.toggleClassTo(
					'no-visible-tags',
					! $this.is(':has(li.u:not(.t,.s,.p,.minus))') );
			});
}

function init_tag_ui_styles( $entries ){
	return $entries.each(function(){
		recompute_css_classes(this);
	});
}

;
