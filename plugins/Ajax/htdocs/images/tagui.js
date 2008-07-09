; // tagui.js

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


function form_submit_tags( form, widget ){
	var $input = $('.tag-entry:input', form);
	var $widget = widget ? $(widget) : $(form).parents('.tag-widget').eq(0);
	$widget.each(function(){
		var tag_cmds = $input.val();
		$input.val('');
		this.submit_tags(tag_cmds);
	})
}


function click_tag( event ) {
	var $tag_el = $('.tag', this);
	var tag = $tag_el.text();
	var op	= $(event.target).text();

	// op differs from tag when the click was in a menu
	//	so, if in a menu, or right on the tag itself, do something
	if ( event.target!==this && (op!==tag || event.target===$tag_el[0]) ) {
		var command = normalize_tag_menu_command(tag, op);
		var $widget = $(this).parents('.tag-widget').eq(0);

		if ( event.shiftKey ) {
			// if the shift key is down, append the tag to the edit field
			$widget.find('.tag-entry:text').each(function(){
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
			$widget.each(function(){
				this.submit_tags(command)
			});
		}
	}
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
				.click(click_tag) // one click-handler per tag, and it's on the <li>
				.append(this.tagbar_data.menu_template);

			// by default, insert the new tags at the front of the tagbar
			if ( how !== 'append' ) how = 'prepend';
			this.tagbar_data.$list_el[how]($new_elems);

			// add in a list of the actual .tag elements we created from scratch
			$changed_tags = $changed_tags.add( $new_elems.find('.tag') );
		}

		// for every .tag element we touched/created, fix the style to match the kind of tag and add annotate if supplied
		//   Use case for annotate: the tag was modified locally, we mark it with "local-only" until the server
		//   comes back with a complete list in response that will wipe out the "local-only" style, essentially
		//   confirming the user's change has been recorded
		var base_classes = 'tag ' + (annotate ? annotate+' ' : '');
		$changed_tags.each(function(){
			this.className = $.trim(base_classes + tag_style($(this).text()))
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

}; // tbar_fns


// XXX temporarily handle some special cases myself.
// Jamie will want to know about this.
function normalize_nodnix( expr ){
	return expr.replace(normalize_nodnix.pattern, _normalize_nodnix);
}
normalize_nodnix.pattern = /-!(nod|nix)|-(nod|nix)|!(nod|nix)|nod|nix/g;

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


var twidget_fns = {

	init: function( item_id, $parent_entry ){
		this.tagwidget_data = {
			item_id:	item_id,
			$parent_entry:	$parent_entry
		}

		$init_tag_bars('.tbar.stub, [get]:not([class])', this);

		// XXX testing autocomplete
		$(this).find('.tag-entry').autocomplete('/ajax.pl', {
			loadingClass:		'working',
			minChars:		3,
			multiple:		true,
			multipleSeparator:	' ',
			autoFill:		true,
			max:			25,
			extraParams: {
				op:		'tags_list_tagnames',
			},
		});
		return this
	},


	set_tags: function( tags ){
		var widget = this;
		$.each(tags.split('\n'), function(){
			var match = /^<(\w+)>?(.*)$/.exec(this);
			if ( match ) {
				$('[get*='+match[1]+']', widget).each(function(){
					this.set_tags(match[2])
				})
			}
		});
		return this
	},


	_submit_fetch: function( tag_cmds ){
		var widget = this;
		var $busy = $('.widget-busy', widget).show();

		if ( tag_cmds ) {
			// 'harden' the new tags into the user tag-bar, but styled 'local-only'
			// tags in the response from the server will wipe-out local-only
			$('.tbar[get*=user]', this).each(function(){
				this.update_tags(tag_cmds, 'prepend', 'local-only')
			});
		}

		$.post('/ajax.pl', {
			op:	'tags_setget_combined',
			id:	this.tagwidget_data.item_id,
			tags:	tag_cmds || '',
			reskey:	reskey_static,
		}, function( response ){
			// console.log(response);
			widget.set_tags(response);
			$busy.removeAttr('style')
		});
		return this
	},


	fetch_tags: function(){
		return this._submit_fetch()
	},


	submit_tags: function( tag_cmds ){
		return this._submit_fetch(normalize_nodnix(tag_cmds))
	},


	open: function(){
		this.tagwidget_data.$parent_entry.addClass('tagging');
		$(this).slideDown(100)
			.find(':text')
			.each(function(){
				this.focus()
			});
		return this
	},


	close: function(){
		$(this).slideUp(100);
		this.tagwidget_data.$parent_entry.removeClass('tagging');
		return this
	}

}; // twidget_fns


function $init_tag_bars( selector, widget, options ){
	// <div get="user" label="My Tags">tag1 tag2 tag3</div>
	widget = widget || $(selector).eq(0).parents('.tag-widget').get(0);

	return $(selector, widget).each(function(){
		var $this_bar = $(this);

		var menu_template = join_wrap(
			$this_bar.attr('menu') || $init_tag_bars.menu_templates[$this_bar.attr('get')] || '',
			'<li>', '</li>',
			'<ul class="tmenu">', '</ul>'
		);

		var t, legend = (t=$this_bar.attr('label')) ? '<h1 class="legend">' + t + '</h1>' : '';

		var tags = $this_bar.text();
		$this_bar.html(legend+'<ul></ul>');

		$.extend(
			this,
			tbar_fns,
			{ tagbar_data: {
				menu_template:	menu_template,
				$list_el:	$this_bar.find('ul'),
				widget_el:	widget,
			} },
			options
		);

		if ( tags ) this.set_tags(tags);

	}).addClass('tbar').removeClass('stub').removeAttr('menu').removeAttr('label')
}

$init_tag_bars.menu_templates = {
	user:	'! x',
	top:	'_ # ! )',
}


function create_tag_bar( listens_for, tags, label ){
	var get_attr	= listens_for ? ' get="'+listens_for+'"' : '';
	var label_attr	= label ? ' label="'+label+'"' : '';
	var tag_bar_div	= (
		'<div' + get_attr + label_attr + '>' +
			tags +
		'</div>'
	);

	return $init_tag_bars(tag_bar_div).get(0)
}

// when the tag-widget is used in the firehose:

function create_firehose_vote_handler( firehose_id ) {
	return $.extend(
		 $('<div class="connector" get="vote" style="display:none"></div>')[0],
		 {
			set_tags: function( tags ){
				if ( tags.length > 3 )
					tags = tags.split(' ')[0];

				firehose_fix_up_down(firehose_id, {
					'':	'vote',
					'nod':	'votedup',
					'nix':	'voteddown'
				}[tags])
			},
		 }
	);
}

function open_firehose_tag_widget( event, selector ) {
	// Walk up to the dom element for this entire entry
	$(selector || this).parents('[id^=firehose-]').andSelf()

		// ...then back down to the tag-widget (if closed) within.
		.find('.tag-widget:hidden')

		// Initialize if it's only a stub...
		.filter('.stub').each(function(){
			$.extend(this, twidget_fns);
			var firehose_id = firehose_id_of(this.id);
			this.init(
				firehose_id,
				$(this).prepend(create_firehose_vote_handler(firehose_id))
					.parents('[id^=firehose-]')
			);
		}).removeClass('stub')

		// ...and now that it's ready, we can just tell it to open itself.
		.end().each(function(){
		       this.open();
		       this.fetch_tags();
		});
}

function close_firehose_tag_widget( event, selector ) {
	// Walk up to the dom element for this entire entry
       $(selector || this).parents('[id^=firehose-]').andSelf()

		// ...then back down to the tag-widget (if open) within.
               .find('.tag-widget:visible')

		// We can just tell it to close itself.
               .each(function(){
                       this.close()
               })
}
