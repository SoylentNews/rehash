// tagui.js

function bare_tag( t ){
	try {
		// XXX what are the real requirements for a tag?
		return /[a-z][a-z0-9]*/.exec(t.toLowerCase())[0]
	} catch (e) {
		// I can't do anything with it; I guess you must know what you're doing
		return t
	}
}


function tag_style( t ){
	var tag_styles = {
		'!': 'mark_not',
		'#': 'mark_pound',
		')': 'mark_3',
		'_': 'mark_4'
	};

	var k = t[0];
	return (k in tag_styles) ? tag_styles[k] : '';
}


function tag_click( event ) {
	var $tag_el = $('.tag', this);
	var tag = $tag_el.text();
	var op	= $(event.target).text();

	// op differs from tag when the click was in a menu
	//	so, if in a menu, or right on the tag itself, do something
	if ( event.target!==this && (op!==tag || event.target===$tag_el[0]) )
		$(this).parents('.tbar')[0].click_tag(tag, op);
}


var tbar_fns = {

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
		var new_tags = $.map(tags, function(t){
			var bt = bare_tag(t);
			if ( bt in update_map )
				$(update_map[bt]).html(t);
			else
				return t;
		});

		// a $ list of the actual .tag elements we updated in-place
		var $changed_tags = $(values(update_map));

		if ( new_tags.length ) {
			// construct all the completely new tag entries and associated machinery
			var $new_elems = $(join_wrap(new_tags, '<li><span class="tag">', '</span></li>'))
				.click(tag_click) // one click-handler per tag, and it's on the <li>
				.append(this.tagbar_data.menu_template);

			// by default, insert the new tags at the front of the tagbar
			if ( how !== 'append' ) how = 'prepend';
			$(this.tagbar_data.list_el)[how]($new_elems);

			// add in a list of the actual .tag elements we created from scratch
			$changed_tags = $changed_tags.add( $new_elems.find('.tag') );
		}

		// for every .tag element we touched/created, fix the style to match the kind of tag and add annotate if supplied
		//   Use case for annotate: the tag was modified locally, we mark it with "local-only" until the server
		//   comes back with a complete list in response that will wipe out the "local-only" style, essentially
		//   confirming the user's change has been recorded
		var base_classes = 'tag ' + (annotate ? annotate+' ' : '');
		$changed_tags.each(function(){
			this.className = $.trim(base_classes + tag_style($(this).text()));
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


	fetch_tags: function(){
		var bar = this;
		$.post('/ajax.pl', {
			op:		this.tagbar_data.fetch_op,
			id:		this.tagbar_data.item_id,
			no_markup:	1
		}, function( response ) {
			bar.set_tags(response)
		});
		return this
	},


	click_tag: function( tag, op ){
		// alert(this.tagbar_data.item_id + ': ' + (op!==tag ? 'apply "'+op+'" to' : 'clicked on') + ' the tag "' + tag + '"');
		if ( op == "x" )
			this.remove_tags(tag);
		else if ( op.length == 1 && op == tag[0] )
			this.update_tags(tag.slice(1));
		else if ( op != tag )
			this.update_tags(op+tag);
		return this
	}

}; // tbar_fns


var twidget_fns = {

	init: function( firehose_id ){
		this.tagwidget_data = {
			item_id:	firehose_id
		}

		$(this).append(tag_bar(firehose_id, 'top'))
			.append(tag_bar(firehose_id, 'user'))
			.append(tag_bar(firehose_id, 'system'));
		return this
	},

	each_bar: function( fn ){
		$('.tbar', this).each(fn);
		return this
	},

	set_tags: function( tags ){
		var widget = this;

		$.each(tags.split('\n'), function(){
			var which_bar = 'user';
			var this_bars_tags = this;

			var match = /^<(\w+)>?(.*)$/.exec(this);
			if ( match ) {
				which_bar = match[1];
				this_bars_tags = match[2];
			}

			$('.tbars .tbar.'+which_bar, widget).each(function(){
				this.set_tags(this_bars_tags)
			})
		});
		return this
	},

	fetch_tags: function(){
		var widget = this;
		$.post('/ajax.pl', {
			op:		'tags_get_combined_firehose',
			id:		this.tagwidget_data.item_id,
			no_markup:	1
		}, function( response ){
			widget.set_tags(response)
		});
		return this
	},

	open: function(){
		$(this).show()
			.find(':text')
			.each(function(){
				this.focus()
			});
		return this
	},

	close: function(){
		$(this).hide();
		return this
	}

}; // twidget_fns

function open_tag_widget( event, selector ) {
	// Walk up to the dom element for this entire entry
	$(selector || this).parents('[id^=firehose-]').andSelf()

		// ...then back down to the tag-widget (if closed) within.
		.find('.tag-widget:hidden')

		// Initialize if it's only a stub...
		.filter('.stub').each(function(){
		       $.extend(this, twidget_fns);
		       this.init(firehose_id_of(this.id))
		}).removeClass('stub')

		// ...and now that it's ready, we can just tell it to open itself.
		.end().each(function(){
		       this.open();
		       this.fetch_tags();
		});
}

function close_tag_widget( event, selector ) {
	// Walk up to the dom element for this entire entry
       $(selector || this).parents('[id^=firehose-]').andSelf()

		// ...then back down to the tag-widget (if open) within.
               .find('.tag-widget:visible')

		// We can just tell it to close itself.
               .each(function(){
                       this.close()
               })
}


function tag_bar( item_id, bar_kind, tags ){
	bar_kind = bar_kind in tag_bar.bar_templates ? bar_kind : 'user';
	var tmpl = tag_bar.bar_templates[bar_kind];

	var new_bar = $.extend(
		$('<div class="'+bar_kind+' tbar"><ul></ul></div>')[0],
		tbar_fns,
		{ tagbar_data: {
			fetch_op:	tmpl.fetch_op,
			item_id:	item_id,
			menu_template:	join_wrap(tmpl.menu_cmds, '<li>', '</li>', '<ul class="tmenu">', '</ul>')
		}}
	);
	new_bar.tagbar_data.list_el = $('ul', new_bar)[0];
	if ( tags !== undefined )
		new_bar.update_tags(tags);
	return new_bar;
}

tag_bar.bar_templates = {
	user: {
		fetch_op:	'tags_get_user_firehose',
		menu_cmds:	'! x'
	},

	top: {
		fetch_op:	'tags_get_top_firehose',
		menu_cmds:	'_ # ! )'
	},

	system: {
		fetch_op:	'tags_get_system_firehose',
		menu_cmds:	null
	}
}
