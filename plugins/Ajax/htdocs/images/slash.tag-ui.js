;(function($){
/*jslint evil:true */
// bring names from Slash.Util, etc., into scope, e.g., Package
eval(Slash.Util.Package.with_packages('Slash.Util', 'Slash.Util.Algorithm'));
/*jslint evil:false */

/* Note: If you're reading this in BBEdit or any other browser that supports "folds", you may want
   to start by collapsing all folds so you just see the eight top-level components.

   Requires: jquery, slash.util.js; non-Slashdot installations will want sfnet-tag-ui.css



   Description:

   This file implements the bulk of the _generic_ tag ui.  For Slashdot, specifics are to be found
   in firehose.tag-ui.js.  For anyone else, this file (and its prerequisites) should be enough to
   have a working tag ui (modulo, as of this writing, actually getting tags from a server).



   Design:

   The "element-based" components, Responder, Broadcaster, Server, Display, and Widget, are meant to
   be installed onto existing DOM elements.  Their individual functions can be called through the
   package, e.g.,

	Slash.TagUI.Broadcaster.broadcast(from_elem, signal, data, options)

   or, once installed, through the element itself, e.g.,

	from_elem.tag_ui_broadcaster.broadcast(signal, data, options)

   The package itself is the element constructor.  So installing onto from_elem usually looks like
   this:

	Slash.TagUI.Broadcaster(from_elem, options)

   The element-based components install their API into jQuery selections as well, so the previous
   examples could also be rendered as:

	var $broadcasters = $('.i-want-to-broadcast').tag_ui_broadcaster(construction_options);
	$broadcasters.tag_ui_broadcaster__broadcast(signal, data, broadcast_options);

   The element itself is extended only by a single member (per interface), e.g., a display element
   will have:

	elem.tag_ui_display
	elem.tag_ui_responder	// because displays are also responders

   Functions of the Display component hang from the tag_ui_display "stem", as well as any element
   specific data needed by Display.  Unfortunately, we can't play the same proxy games with jQuery,
   so the stem name is rolled into the function names:

	$(elem).tag_ui_display__set_tags(tags, options); // vs.
	elem.tag_ui_display.set_tags(tags, options);

   The jQuery versions of the functions apply to every selected element that has the interface
   installed, or to every element in the case of the constructors or a "free API" call, e.g.,

	$(expr).tag_ui__tags()

   ...is part of the free (non-element-bound) API, and so applies to every element in $(expr).

   In general, when a package declares an element_api, any function of that API will be available in
   several forms, e.g., for the 'bind' function of a responder:

	// via the package
	Slash.TagUI.Responder.bind(r_elem, fn, signals);	// TagUI.Responder.bind

	// via an (already "constructed") element
	r_elem.tag_ui_responder.bind(fn, signals);		// tag_ui_responder.bind

	// ...and for packages that, like Responder, enable jQuery
	// via the jQuery global
	$.tag_ui_responder.bind(r_elem, fn, signals);		// tag_ui_responder.bind

	// via a jQuery selection, for every eligible element it contains
	$(expr).tag_ui_responder__bind(fn, signals);		// tag_ui_responder__bind

	// constructor forms
	Slash.TagUI.Responder(r_elem, options);			// TagUI.Responder
	$.tag_ui_responder(r_elem, options);			// tag_ui_responder
	$(expr).tag_ui_responder(options);			// tag_ui_responder

   "Free" API calls are available:

	// via the package
	Slash.TagUI.Markup.add_style_triggers(tags, styles);	// TagUI.Markup.add_style_triggers

	// ...and for packages that, like Markup, enable jQuery
	// via the jQuery global
	$.tag_ui_markup.add_style_triggers(tags, styles);	// tag_ui_markup.add_style_triggers



   Now, onto the bigger picture.

   ............................................................Servers, Broadcasters, and Responders

   In a view listing a number of entries, e.g., a Firehose view of articles, where tags within an
   entry are connected to that entry --- here's how the tag ui is implemented: the entry itself
   becomes a tag_ui_server.  When it fetches or submits tags, it notifies components beneath it (DOM
   descendants) via the tag_ui_broadcaster methods.  Those descendants will include displays, which
   will update their contained tags at this notification, and other custom responders, e.g.,
   something to start and stop a "busy spinner", or, in the case of the Firehose, to update the vote
   displayed by the nod/nix "capsule".

   Any code can submit new tags or tag-commands by finding the tag_ui_server and calling its methods
   directly, e.g.,

	$(this).nearest_parent('.tag-server').tag_ui_server__submit_tags('slownewsday');

   Typically, you will do this from a custom click handler (see Slash.Firehose.TagUI.click_handler).
   You might also do it from a form or text input.

   ..............................................................Command, and the "command pipeline"

   Before actually submitting any commands across AJAX, the tag_ui_server first sends the commands
   through a pipeline of filters, which can add, remove, or alter those commands.  That pipeline is
   empty by default.  You fill it with whatever you want.  Some filters are provided (see Command).
   The Firehose uses this mechanism, for example, to notice commands masquerading as tags, e.g,
   'neverdisplay', act on them locally, and delete them from the stream of commands to be sent.

   ...................................................................................CSS and Markup

   Tags are marked-up (or more specifically, the li elements _containing_ tags are marked-up) in two
   ways.  First with "static styles", that is, css classes that can be determined soley by looking
   at the tag itself, e.g., 'apple' is a section name, so it gets the 's1' class.  Second, with
   "computed styles", that is, css classes determined by examining all the tags under an entry and
   in which displays they appear, e.g., if the tag 'democrat' appears in both the top tags display
   and the user tags display, then _every_ occurance of that tag anywhere within the entry will have
   the css classes 't u' (for top and user, respectively).

   Static styles are set up by calling Markup.add_style_triggers, and are applied automatically when
   tags are created or changed.  The default set of static styles is empty.  The Firehose installs a
   set of static styles (including 's1' for sections); you can do the same, or not, as needed.  The
   computed styles are computed and applied by the Markup call refresh_styles.  This function is not
   called automatically, so if you don't want computed styles, you don't have to have them.  The
   Firehose calls this via a Responder that listens for the ajaxSuccess signal.  It's the computed
   styles that let us do things in CSS such as: hide top tags if they already appear in the system
   tags display; hide user tags if they already appear in the system or top tags displays.

   .........................................................................................Displays

   Displays additionally support per-tag menus and supply some defaults.  You can disable the menus
   entirely; supply your own; and easily control them on a per-display basis or (less easily) on a
   tag-by-tag basis.  The "meaning" of the menus is up to your code.  The Firehose default (via its
   click handler) is to submit a command based on the menu label and the underlying tag, e.g., the
   'x' menu item on the tag 'apple' asks the corresponding tag_ui_server to submit_tags('-apple').
   This simple rule means the Firehose only needs a single click handler for the entire page ... at
   least for submitting tag-commands.  The appearance and behavior of the menus is entirely defined
   by CSS.

   In the near future, Displays will also support "drag and drop" of tags for ordering within a
   display or for moving tags between displays (and possibly new components).  As with menus, the
   "meaning" of a drag and drop action would be up to the client code.

   ..........................................................................................Widgets

   Finally, a Widget is a container that manages a "context" --- hiding, showing, positioning, and
   animating a designated display filled with context-specific tags.  Your custom machinery
   determines when and how contexts are set.  One way of doing that is by installing a handler in
   the command pipeline, and setting a context based on what tags were just submitted.  Your click
   handler is another likely place.  Essentially, a Widget is a control for a context sensitive menu
   in the form of a tag display.  For example, the Firehose uses this mechanism to bring up the
   secondary choices after a nod or a nix, that is (for nod) 'fresh funny insightful interesting
   maybe'.  Widgets support "timing out" the context sensitive display.

   .......................................................................applications of the tag ui

   The simplest scenario for the tag_ui is that you've set up the static styles to your liking, and
   then produce a single read-only display populated with tags at template time, and calling the
   tag_ui__init function, from jQuery, on the new entries as they are added to the window.  The next
   step up is adding a server to each entry, allowing the display to be filled dynamically, upon
   request.  Then adding a click handler to act on the tags and/or a text field to add new tags.
   Then widgets to supply additional context-sensitive commands; and command handlers to separate
   out and act on those that require local handling.

   Some Final Notes:

   The tag_ui components that are actually attached to elements automatically benefit from the loose
   coupling afforded by the DOM.  A single server serves only those elements beneath it.  Any
   element can just "look up" (with nearest_parent('.tag-server')) to find its server.  Responders
   (for instance, displays) can be added or removed at any time.  All such components support
   specifying most of their behavior right in the HTML.  Slash.Util.Package ensures that actual
   attachments have a minimal footprint, both in the namespace and code size---adapting a single
   element function to be called stand-alone, with the element as its first argument; as a method
   of an element; or as method of a jQuery selection, to be applied to every eligible element.
 */


var Responder, Broadcaster, Server, Markup, Display, Command, Fx, Widget;

function simple_host(){
	var M = /^.+:\/\/([^\/]+)\//.exec(window.location);
	if ( M ) {
		return M[1].
			toLowerCase().
			split('.').
			slice(-2).
			join('.');
	}
}

function map_classes( elem, fn ){
	elem.className = $.map(qw(elem.className), fn).join(' ');
}

function un_stub( stub_elem, needed ){
	var re_display = /((.*)tag-.*)-stub/, found, prefix;
	map_classes(stub_elem, function( cn ){
		var M = re_display.exec(cn);
		if ( M ) {
			prefix = M[2];
			return (found = M[1]);
		}
		return cn;
	});
	if ( needed && ! found ) {
		$(stub_elem).addClass(needed);
	}
	return prefix;
}


// Slash.TagUI.Util
(function(){ var TagUI =

// public API
new Package({ named: 'Slash.TagUI',
	api: {
		tags: function( selector ){
			return $(selector).tag_ui__tags();
		},
		cached_user_tags: function( selector ){
			return $(selector).tag_ui__cached_user_tags();
		},
		bare_tag: function( tag ){
			try {
				// XXX what are the real requirements for a tag?
				return /[a-z][a-z0-9]*/.exec(tag.toLowerCase())[0];
			} catch (e) {
				// I can't do anything with it; I guess you must know what you're doing
				return tag;
			}
		},
		init: function( $new_entries, options ){
			return $new_entries.tag_ui__init(options);
		}
	},
	jquery: {
		element_api: {
			tags: function(){
				var tags = {};
				this.find('span.tag').each(function(){
					tags[ $(this).text() ] = true;
				});
				return qw(tags);
			},
			cached_user_tags: function(){
				return this.find('[class*=tag-display].ready.respond-user').tag_ui__tags();
			},
			init: function( options ){
				options = options || {};
				this.find('[class*=tag-display-stub]').tag_ui_display(options.for_display);
				this.find('[class*=tag-widget-stub]').tag_ui_widget(options.for_widget);
				return this;
			}
		}
	},
	exports: 'tags cached_user_tags bare_tag'
});

})();
/*jslint evil:true */
eval(Package.with_packages('Slash.TagUI'));
/*jslint evil:false */

// Slash.TagUI.Responder: "observer"
(function(){ Responder =

// public API
new Package({ named: 'Slash.TagUI.Responder',
	api: {
	},
	element_api: {
		signals: signals,
		add_signals: add_signals,
		remove_signals: remove_signals,
		ready: function( r_elem, if_ready ){
			var $r_elem = $(r_elem), ready_class = 'ready';
			if ( if_ready === undefined ) {
				return $(r_elem).hasClass(ready_class);
			}
			$(r_elem).toggleClassTo(ready_class, if_ready);
			return r_elem;
		},
		bind: function( r_elem, fn, _signals ){
			r_elem.tag_ui_responder.handle_signal = fn;
			signals(r_elem, _signals);
			return r_elem;
		},
		handle: function( r_elem, signals, data, options ){
			var fn = r_elem.tag_ui_responder && r_elem.tag_ui_responder.handle_signal;
			if ( fn ) {
				fn.apply(r_elem, [signals, data, options]);
			}
			return r_elem;
		}
	},
	stem_function: function( r_elem, o ){
		r_elem.
			tag_ui_responder.bind(o.fn, o.signals).
			tag_ui_responder.ready(!if_defined_false(o.if_ready));
		return o.defaults ? { defaults: o.defaults } : undefined;
	},
	jquery: true
});

var re_signal = /^respond-(.+)/;

function signals_to_classes( signals ){
	var s=qw(signals), p='respond-';
	return s.length ? p + s.join(' '+p) : '';
}

function classes_to_signals( classes ){
	return $.map(qw(classes), function(cn){
		var M = re_signal.exec(cn);
		if ( M ) {
			return M[1];
		}
	}).join(' ');
}

function remove_signals( r_elem, signals ){
	var if_remove = function(){ return true; };
	if ( signals ) {
		signals = qw.as_set(signals);
		if_remove = function( signal ){
			return signal in signals;
		};
	}

	map_classes(r_elem, function(cn){
		var M = re_signal.exec(cn);
		if ( !M || !if_remove(M[1]) ) {
			return cn;
		}
	});
}

function add_signals( r_elem, signals ){
	if ( signals ) {
		$(r_elem).addClass(signals_to_classes(signals));
	}
}

function signals( r_elem ){
	var more_new_signals = Array.prototype.slice.call(arguments, 1);
	var new_signals = [], first_new_signal = more_new_signals.shift();
	if ( if_defined(first_new_signal) ) {
		new_signals = new_signals.concat(qw(first_new_signal)).concat(more_new_signals);
	}

	var old_signals = classes_to_signals(r_elem.className);

	if ( new_signals.length ) {
		remove_signals(r_elem);
		add_signals(r_elem, new_signals);
	}

	return old_signals;
}

})();

// Slash.TagUI.Broadcaster: "observable"
(function(){ Broadcaster =

// public API
new Package({ named: 'Slash.TagUI.Broadcaster',
	element_api: {
		broadcast: function( b_elem, signal, data, options ){
			var M = /^\<?((\w+)(?:\:\w+)?)\>?$/.exec(signal);
			if ( M ) {
				signal = M[1];
				var selector = '.ready.respond-'+M[2];
				var $r_list = arguments[4]; // list of responders
				$r_list = $r_list && $r_list.filter(selector) || $(selector, b_elem);
				$r_list.tag_ui_responder__handle(signal, data, options);
			}
			return b_elem;
		},
		broadcast_sequence: function( b_elem, sequence, options ){
			// slice to remove bogus empty before first "separator"
			var tuples = sequence.split(/\n?<([\w:]*)>/).slice(1);

			if ( tuples && tuples.length >= 2 ) {
				// XXX consider caching
				var $responders = $('.ready[class*=respond-]', b_elem);

				while ( tuples.length >= 2 ) {
					var data = tuples.pop();
					Broadcaster.broadcast(b_elem, tuples.pop(), data, options, $responders);
				}
			}
			return b_elem;
		}
	},
	jquery: true
});

})();

// Slash.TagUI.Server: ajax service and Broadcaster reporting results and events
(function(){ Server =

// public API
new Package({ named: 'Slash.TagUI.Server',
	api: {
		need_cross_domain: function(){
			Server.defaults.ajax = {
				url:		'http://slashdot.org/authtags.pl?callback=?',
				type:		'GET',
				dataType:	'jsonp'
			};
		},
		defaults: {
			command_feedback: {
				order:		'append',
				classes:	'not-saved'
			},
			success_feedback: {
				order:		'append'
			},
			request_data: {
				op:		'tags_setget_combined'
			},
			ajax: {
				url:		'/ajax.pl',
				type:		'POST',
				dataType:	'text'
			}
		}
	},
	element_api: {
		ajax: function( s_elem, options ){
			return ajax(s_elem, null, options);
		},
		fetch_tags: function( s_elem, options ){
			return ajax(s_elem, null, options);
		},
		submit_tags: function( s_elem, commands, options ){
			return ajax(s_elem, commands, options);
		}
	},
	element_constructor: function( s_elem, options ){
		options = options || {};
		Broadcaster(s_elem);

		var key_tuple = Slash.ArticleInfo.key(s_elem);

		$(s_elem).addClass('tag-server');
		var ext = {};
		if ( options.command_pipeline ) { ext.command_pipeline = options.command_pipeline; }
		if ( options.defaults ) { ext.defaults = options.defaults; }
		if ( if_defined(key_tuple) ) {
			if ( ! ext.defaults ) ext.defaults = { };
			if ( ! ext.defaults.request_data ) ext.defaults.request_data = { };
			ext.key = (ext.defaults.request_data.key = key_tuple.key);
			ext.key_type = (ext.defaults.request_data.key_type = key_tuple.key_type);
		}
		return ext;
	},
	jquery: {
		element_constructor: function( options ){
			options = options || {};
			return this.each(function(){
				var clean_options = {};

				if ( options.id !== undefined ) {
					clean_options.id = options.id;
				}
				if ( options.command_pipeline && options.command_pipeline.slice ) {
					clean_options.command_pipeline = options.command_pipeline.slice(0);
				}
				if ( options.defaults ) {
					clean_options.defaults = $.clone(options.defaults);
				}

				Server(this, clean_options);
			});
		}
	}
});

// Slash.TagUI.Server private implementation details
// this is the one function that handles all three of the public entry-points
function ajax( s_elem, commands, options ){
	var ts = s_elem.tag_ui_server;

	if ( (commands = qw(commands)).length > 0 &&
		ts.command_pipeline &&
		ts.command_pipeline.length > 0 ) {

		var no_more_commands = false;
		$.each(ts.command_pipeline, function(i, fn){
			commands = fn.apply(s_elem, [ commands, options ]);
			if ( ! commands.length ) {
				no_more_commands = true;
				return false;
			}
		});
		if ( no_more_commands ) {
			return s_elem;
		}
	}

	var settings = resolve_defaults(s_elem, options);
	settings.request_data.tags = qw.as_string(commands);


	function signal_event(s, o){
		Broadcaster.broadcast(s_elem, s, commands, o);
	}

	signal_event('<feedback>', settings.command_feedback);
	signal_event('<ajaxStart>');
	$.ajax($.extend(settings.ajax, {
		data: settings.request_data,
		success: function( data ){
			var sequence = '<ajaxSuccess>';
			if ( ! settings.ajax.dont_parse_response ) {
				switch ( typeof data ) {
					case 'text':
						sequence += data;
						break;
					case 'object':
						$.each(data, function(k, v){
							sequence += '<' + k + '>' + v;
						});
						break;
				}
			}
			Broadcaster.broadcast_sequence(s_elem, sequence, settings.success_feedback);
			var success_fn = resolve_callback(s_elem, options, 'success');
			if ( success_fn ) {
				success_fn(data);
			}
		},
		complete: function(){
			signal_event('<ajaxComplete>');
		}
	}));
	return s_elem;
}

// XXX move to utils
function resolve_defaults( s_elem, caller_opts ){
	var answer = {};
	var class_opts = Server.defaults;
	var this_opts = s_elem.tag_ui_server && s_elem.tag_ui_server.defaults || {};
	caller_opts = caller_opts || {};
	for ( var k in class_opts ) {
		answer[k] = $.extend({}, class_opts[k], this_opts[k]||{}, caller_opts[k]||{});
	}
	return answer;
}

function resolve_callback( s_elem, caller_opts, callback_name ){
	var elem_ajax = s_elem.tag_ui_server && s_elem.tag_ui_server.defaults && s_elem.tag_ui_server.defaults.ajax || {};
	var caller_ajax = caller_opts && caller_opts.ajax || {};

	return if_fn(caller_ajax[callback_name]) || if_fn(elem_ajax[callback_name]);
}

if ( simple_host() != 'slashdot.org' ) {
	Server.need_cross_domain();
}

})();

// Slash.TagUI.Markup: (mostly) managing CSS classes and marking up tags
(function(){ Markup =

// public API
new Package({ named: 'Slash.TagUI.Markup',
	api: {
		styles: static_styles_for_tag,
		add_style_triggers: function( trigger_tags, styles ){
			update_tag_styles(tag_styles, styles, trigger_tags);
		},
		refresh_styles: refresh_tag_styles_in_entry,
		auto_refresh_styles: function( server_elem ){
			$(server_elem).tag_ui_markup__auto_refresh_styles();
		},
		markup_tag: function( tag ){
			try {
				return tag.replace(/^([^a-zA-Z]+)/, '<span class="punct">$1</span>');
			} catch (e) {
				return tag;
			}
		},
		markup_tag_menu: function( op ){
			return '<li class="'+static_styles_for_menu(op)+'"><span>'+op+'</span></li>';
		}
	},
	jquery: {
		element_api: {
			auto_refresh_styles: function(){
				this.append('<span class="auto-refresh-styles" style="display: none"></span>').
					find('.auto-refresh-styles').
					tag_ui_responder({
						signals: 'ajaxSuccess',
						fn: function(){
							$(this).nearest_parent('.tag-server').tag_ui_markup__refresh_styles();
						}
					});
				return this;
			},
			refresh_styles: function(){
				return this.each(function(){
					refresh_tag_styles_in_entry(this);
				});
			}
		}
	}
});

// Slash.TagUI.Markup private implementation details

var signal_styles = {
	user:	'u',
	top:	't',
	system:	's'
};

var prefix_styles = {
	'!':	'bang',
	'#':	'pound',
	')':	'descriptive',
	'_':	'ignore',
	'-':	'minus'
};

/* Other css classes for tags:
	'w'	warning
	'd'	data type
	'e'	editor tag ('hold', 'back', etc)
	'f'	feedback tag ('error', 'dupe', etc)
	'p'	private tag
	't2'	topic
	's1'	section
	'y'	nod
	'x'	nix
 */

var tag_styles = {};

function static_styles_for_tag( tag, more ){
	return qw.concat_strings(
		tag_styles[ bare_tag(tag) ],
		prefix_styles[ tag[0] ],
		more
	);
}

function static_styles_for_menu( op ){
	return prefix_styles[op] || prefix_styles[op[0]] || op=='x' && prefix_styles['-'] || op;
}


function update_tag_styles( map, styles, tags ){
	qw.each(tags, function(){
		map[this] = qw.concat_strings(map[this], styles);
	});
}

function apply_tag_styles( $tags, styles, styles_fn ){
	// apply css classes to every element in $tags according to styles and/or styles_fn
	// if styles_fn is supplied, it will be called for any tags not mapped by styles
	// _and_ styles WILL BE MODIFIED

	if ( $.isFunction(styles) ) {
		styles_fn = styles;
		styles = {};
	}

	$tags.each(function(){
		var $tag=$(this), tag=$tag.text();
		if ( styles_fn && ! (tag in styles) ) {
			styles[tag] = styles_fn(tag);
		}
		$tag.parent().setClass(styles[tag]);
	});
}

function compute_tag_styles( $displays, signal_styles, static_styles_fn ){
	// return a dictionary mapping actual, non-bare, tags to css classes

	// "computed styles" is the set of css classes that tell in which displays a tag appears,
	// e.g., a tag that appears in both the user and system displays gets css classes 'u s'
	var signals_done={}, styles={}, signals_remaining=keys(signal_styles).length;
	$displays.filter('.ready[class*=respond-]:not(.no-tags)').each(function(){
		var $display=$(this), signal=$display.tag_ui_responder__signals();
		if ( (signal in signal_styles) && !(signal in signals_done) ) {
			update_tag_styles(styles, signal_styles[signal], $display.tag_ui__tags());
			signals_done[signal] = true;
			return --signals_remaining!==0;
		}
	});

	// "static styles" is the set of css classes based only on the tag itself
	// e.g., a tag that is a section name gets css class 's1'
	$.each(styles, function( tag ){
		styles[tag] = static_styles_fn(tag, styles[tag]);
	});

	return styles;
}

function refresh_tag_styles_in_entry( entry ){
	var $displays = $('[class*=tag-display]', entry);
	apply_tag_styles(
		$displays.find('span.tag'),
		compute_tag_styles($displays, signal_styles, static_styles_for_tag),
		static_styles_for_tag
	);

	$displays.filter('.respond-user').each(function(){
		var $this=$(this);
		$this.toggleClassTo('no-visible-tags', ! $this.is(':has(li.u:not(.t,.s,.p,.minus))'));
	});
}

})();

// Slash.TagUI.Display: an ordered, and usually visible, list of tags; Responder listens for particular categories of tags
(function(){ Display =

// public API
new Package({ named: 'Slash.TagUI.Display',
	api: {
		metadata: function( d_elem ){
			var $d_elem = $(d_elem);
			return {
				for_display: {
					tags:		$d_elem.text(),
					defaults:	$d_elem.metadata({type:'attr', name:'init'})
				},
				for_responder: {
					signals:	Responder.signals(d_elem)
				}
			};
		},
		defaults: {
			menu:	'x !'
		}
	},
	element_api: {
		// replace existing tags and/or add new tags; preserves order of existing tags
		//  optional string, options.order, tells where to add new tags { 'append', 'prepend' }
		//  optional string, options.classes, tells a css class to add to all touched tags
		update_tags: function( d_elem, tags, options ){
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
			var update_map = map_tags(d_elem, tags = qw(tags))[0];

			// update in-place the ones we can; build a list of the ones we can't ($.map returns a js array)
			var new_tags_seen = {};
			var new_tags = $.map(tags, function(t){
				var bt = bare_tag(t);
				var mt = Markup.markup_tag(t);
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
					append(d_elem.tag_ui_display._menu_template);

				d_elem.tag_ui_display._$list_el[options.order]($new_elems);

				// add in a list of the actual .tag elements we created from scratch
				$changed_tags = $changed_tags.add( $new_elems.find('span.tag') );

				$mark_empty(d_elem, false);
			}

			// for every .tag we added/changed, fix parent <li>'s css class(es)
			//   Use case for options.classes: the tag was modified locally, we mark it with "not-saved" until the server
			//   comes back with a complete list in response that will wipe out the "not-saved" class, essentially
			//   confirming the user's change has been recorded
			$changed_tags.each(function(){
				var $tag = $(this);
				$tag.parent().setClass(Markup.styles($tag.text(), options.classes));
			});
			return d_elem;
		},
		remove_tags: function( d_elem, tags, options ){
			var opts = $.extend({}, { fade_remove: 0 }, options);

			// invariant: before.count_tags() >= after.count_tags()
			// no other call removes tags (except by calling _me_)

			// when called without an argument, removes all tags, otherwise
			//   tags to remove may be specified by string, an array, or the result of a previous call to map_tags
			var if_remove_all;
			if ( !tags || tags.length ) {
				var mapped = map_tags(d_elem, tags);
				tags = mapped[0];
				if_remove_all = mapped[1];
			}

			var $remove_li = $(values(tags)).parent();

			if ( opts.fade_remove ) {
				$remove_li
					.fadeOut(opts.fade_remove)
					.queue(function(){
						$(this).remove().dequeue();
						if ( if_remove_all ) {
							$mark_empty(d_elem);
						}
					});
			} else {
				$remove_li.remove();
				$mark_empty(d_elem, if_remove_all);
			}

			return d_elem;
		},
		// like remove_tags() followed by update_tags(tags) except order preserving for existing tags
		set_tags: function( d_elem, tags, options ){
			var allowed_tags = qw.as_set(tags = qw(tags), bare_tag);
			var removed_tags = map_tags(d_elem, function(bt){
				return !(bt in allowed_tags);
			})[0];

			return d_elem.
				tag_ui_display.remove_tags(removed_tags, options).
				tag_ui_display.update_tags(tags, options);
		}
	},
	element_constructor: function( d_elem, o ){
		var md = Display.metadata(d_elem);
		o = o || {};

		var o_d = $.extend({}, md.for_display, o.for_display || {});
		var o_r = $.extend({}, md.for_responder, o.for_responder || {});

		Responder(d_elem, $.extend({
			fn: function( signal, tags, options ){
				return this.tag_ui_display.set_tags(tags, options);
			}
		}, o_r));

		var $d_elem = $(d_elem).html('<ul/>').
			addClass('no-tags').
			removeAttr('init');

		var prefix = un_stub(d_elem, 'tag-display');

		var menu = o_d.menu || Display.defaults.menu;
		var ext = {
			_$list_el: $d_elem.find('ul'),
			_menu_template: menu ? (
				'<div class="' + prefix + 'tag-menu"><ul>' +
				$.map(qw(menu), function( op ){
					return Markup.markup_tag_menu(op);
				}).join('') +
				'</ul></div>' ) : ''
		};
		if ( o_d.defaults ) {
			ext.defaults = o_d.defaults;
		}

		$.extend(d_elem.tag_ui_display, ext);

		if ( o_d.tags ) {
			d_elem.tag_ui_display.set_tags(o_d.tags);
		}
	},
	jquery: true
});

// Slash.TagUI.Display private implementation details

// return a dictionary mapping bare tags to the corresponding *.tag DOM element
function map_tags( d_elem, how ){
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
		var allowed_tags = qw.as_set(how, bare_tag);
		map_fn = function(bt){return bt in allowed_tags;};
	}

	// now that we know how, iterate over my actual tags to build the result set
	var if_mapped_all = true, map = {};
	$('span.tag', d_elem).each(function(){
		var bt = bare_tag($(this).text());
		if ( map_fn(bt) ) {
			map[bt] = this;
		} else {
			if_mapped_all = false;
		}
	});
	return [ map, if_mapped_all ];
}

function $mark_empty( d_elem, if_empty ){
	var $d_elem = $(d_elem);
	if ( if_empty === undefined ) {
		if_empty = ! $d_elem.is(':has(span.tag)');
	}
	return $d_elem.toggleClassTo('no-tags', if_empty);
}

function join_wrap( a, elem_prefix, elem_suffix, list_prefix, list_suffix ) {
	// always returns a string, even if it's the empty string, ''
	var result = '';
	a = qw(a);
	if ( a && a.length ) {
		var ep = elem_prefix || '';
		var es = elem_suffix || '';
							// Example:
		result = (list_prefix || '') + ep +	// '<ul><li>'
			a.join(es+ep) +			// .join('</li><li>')
			es + (list_suffix || '');	// '</li></ul>
	}
	return result;
}

})();

// Slash.TagUI.Command
(function(){ Command =

// public API
new Package({ named: 'Slash.TagUI.Command',
	api: {
		normalize_nodnix:		normalize_nodnix,
		normalize_tag_commands:		normalize_tag_commands,
		normalize_tag_menu_command:	normalize_tag_menu_command,
		allow_ops:			allow_ops
	}
});

// Slash.TagUI.Command private implementation details

re_op = /^([\A_]+)/;

function allow_ops( ops ){
	var allowed = qw.as_set(ops);
	return function( commands ){
		return $.map(commands, function( cmd ){
			var M = re_op.exec(cmd);
			if ( !M || (M[1] in allowed) ) {
				return cmd;
			}
		});
	}
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
	commands = qw(commands);
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
				excludes = qw.as_set(excludes);
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

})();

// Slash.TagUI.Fx
(function(){ Fx =

new Package({ named: 'Slash.TagUI.Fx'
});

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


function $position_context_display( $display ){
	if ( ! $related_trigger || ! $related_trigger.length ) {
		return;
	}

	var RIGHT_PADDING = 18;

	var $entry = $display.nearest_parent('.tag-server');
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

})();

// Slash.TagUI.Widget: a container for Displays that manages a current "context"
(function(){ Widget =

// public API
new Package({ named: 'Slash.TagUI.Widget',
	element_api: {
		set_context: set_widget_context
	},
	stem_function: function(){
	},
	jquery: true
});

// Slash.TagUI.Widget private implementation details

var $previous_context_trigger = $().filter();

function init(){
	$init_tag_displays($('[class*=tag-display-stub]', this));

	return this;
}


function set_widget_context( context, force, $related_trigger ){
	var w_elem = this, w = w_elem.tag_ui_widget;

	if ( context ) {
		if ( context == w._current_context &&
			(!$previous_context_trigger.length ||
				$related_trigger[0] === $previous_context_trigger[0]) && !force ) {
			context = '';
		} else {
			if ( !(context in suggestions_for_context) && context in context_triggers ) {
				context = (w._current_context != 'default') ? 'default' : '';
			}

		}
	}

	// cancel any existing timeout... the context to be hidden is going away
	if ( w._context_timeout ) {
		clearTimeout(w._context_timeout);
		w._context_timeout = null;
	}

	// only have to set_tags on the display if the context really is changing
	if ( context != w._current_context ) {
		var context_tags = [];
		if ( context && context in suggestions_for_context ) {
			context_tags = qw.as_array(suggestions_for_context[context]);
		}

		var has_tags = context_tags.length !== 0;

		$('.ready.respond-related', this)
			.each(function(){
				var d_elem = this, d = d_elem.tag_ui_display;
				var $display = $(d_elem);

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
					d.set_tags(context_tags, { classes: 'suggestion' });
					if ( has_tags && w.modify_context ) {
						w.modify_context(d_elem, context);
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

		w._current_context = context;
	} else if ( context &&
		$related_trigger.length &&
		$previous_context_trigger.length &&
		$previous_context_trigger[0] !== $related_trigger[0] ) {

		$position_context_display($('.ready.respond-related', this));
	}

	$previous_context_trigger = $related_trigger;

	// if there's a context to hide, and hiding on a timeout is requested...
	if ( context && w.defaults.context_timeout ) {
		w._context_timeout = setTimeout(function(){
			w.set_context();
		}, w.defaults.context_timeout);
	}

	return this;
}



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

			un_stub(this, 'tag-widget');
		});

	return $stubs;
}

})();

})(Slash.jQuery);
