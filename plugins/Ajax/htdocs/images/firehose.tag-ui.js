;(function($){
/*jslint evil:true */
eval(Slash.Util.Package.with_packages('Slash.Util'));
/*jslint evil:false */

// public API
Package({ named: 'Slash.Firehose.TagUI',
	api: {
		click_handler:	firehose_click_tag,
		init_entries:	firehose_init_tag_ui,
		toggle:		firehose_toggle_tag_ui,
		toggle_to:	firehose_toggle_tag_ui_to,
		form_submit:	form_submit_tags,
		before_update:	before_update,
		after_update:	after_update
	}
});

var Firehose = Slash.Firehose;


function before_update(){
	return {
		selection:	new $.TextSelection(gFocusedText),
		$menu:		$('.ac_results:visible')
	};
}

function after_update( $new_entries, state ){
	firehose_init_tag_ui($new_entries);
	state.selection.restore().focus();
	state.$menu.show();
}



// Slash.Firehose.TagUI private implementation details

function firehose_toggle_tag_ui_to( if_expanded, selector ){
	var	$entry	= $(selector).nearest_parent('.tag-server'),
		$widget = $entry.find('.tag-widget.body-widget'),
		id	= $entry.attr('tag-server');

	Firehose.set_action();
	$entry.find('.tag-widget').each(function(){ this.set_context(); });

	$widget.toggleClassTo('expanded', if_expanded);

	var toggle_button={}, toggle_div={};
	if ( if_expanded ){
		$entry.each(function(){ this.tag_server.fetch_tags(); });
		if ( fh_is_admin ) {
			firehose_get_admin_extras(id);
		}
		$widget.find('.tag-entry:visible:first').each(function(){ this.focus(); });

		toggle_button['+'] = (toggle_button.collapse = 'expand');
		toggle_div['+'] = (toggle_div.tagshide = 'tagbody');
	} else {
		toggle_button['+'] = (toggle_button.expand = 'collapse');
		toggle_div['+'] = (toggle_div.tagbody = 'tagshide');
	}

	$widget.find('a.edit-toggle .button').mapClass(toggle_button);
	$entry.find('#toggletags-body-'+id).mapClass(toggle_div);
}

function firehose_toggle_tag_ui( toggle ) {
	firehose_toggle_tag_ui_to( ! $(toggle.parentNode).hasClass('expanded'), toggle );
}

var $related_trigger = $().filter();

function form_submit_tags( form, options ){
	var $input = $('.tag-entry:input', form);
	$related_trigger = $input;
	$(form).nearest_parent('.tag-server').
		each(function(){
			var tag_cmds = $input.val();
			$input.val('');
			this.tag_ui_server.submit_tags(tag_cmds, options);
		});
}

function firehose_click_tag( event ) {
	var $target = $(event.target), command='', $menu;

	$related_trigger = $target;

	if ( $target.is('a.up') ) {
		command = 'nod';
	} else if ( $target.is('a.down') ) {
		command = 'nix';
	} else if ( $target.is('.tag') ) {
		command = $target.text();
	} else if ( $target.nearest_parent('.tmenu').length ) {
		var op = $target.text();
		var $tag = $target.nearest_parent(':has(span.tag)').find('.tag');
		$related_trigger = $tag;

		var tag = $tag.text();
		command = Slash.TagUI.Command.normalize_tag_menu_command(tag, op);
	} else {
		$related_target = $().filter();
	}

	if ( command ) {
		// No!  You no hurt Dr. Jones!  You log-in first!
		if ( firehose_user_class !== undefined && !firehose_user_class ) {
			show_login_box();
			return true;
		}

		Firehose.set_action();
		var $s_elem = $target.nearest_parent('.tag-server');

		// Make sure the user sees some feedback...
		if ( $menu || event.shiftKey ) {
			// for a menu command or copying a tag into edit field, open the tag_ui
			var $widget = firehose_toggle_tag_ui_to(kExpanded, $s_elem);

			// the menu is hover css, you did the command, so the menu should go away
			// but you're still hovering
			if ( $menu ) {
				// so explicitly hide the menu
				$menu.hide();
				// Yikes! that makes it permanently gone; so undo at our earliest convenience
				setTimeout(function(){ $menu.removeAttr('style'); });
				// it can't immediately re-pop because you no longer qualify for the hover
			}
		}

		if ( event.shiftKey ) { // if the shift key is down, append the tag to the edit field
			$s_elem.find('.tag-entry:text:visible:first').each(function(){
				if ( this.value ) {
					var last_char = this.value[ this.value.length-1 ];
					if ( '-^#!)_ '.indexOf(last_char) == -1 ) {
						this.value += ' ';
					}
				}
				this.value += command;
				this.focus();
			});
		} else { // otherwise, send it the server to be processed
			$s_elem.each(function(){
				this.tag_ui_server.submit_tags(command, { fade_remove: 400, order: 'prepend', classes: 'not-saved'});
			});
		}
		return false;
	}

	return true;
}

var context_triggers = qw.as_set('submission journal bookmark feed story vendor misc comment discussion project');


function firehose_handle_context_triggers( commands ){
	var context;
	commands = $.map(commands, function(cmd){
		if ( cmd in context_triggers ) {
			context = cmd;
			cmd = null;
		}
		return cmd;
	});

	$('.tag-widget:not(.nod-nix-reasons)', this).
		each(function(){
			this.set_context(context);
		});

	return commands;
}


function firehose_handle_nodnix( commands ){
	if ( commands.length ) {
		var $reasons = $('.nod-nix-reasons', this);

		var context_not_set = true;
		var nodnix_context = function( ctx ){
			$reasons.each(function(){
				this.tag_ui_widget.set_context(ctx);
			});
			context_not_set = false;
		};

		var tag_ui_server=this, context_not_set=true;
		$.each(commands.slice(0).reverse(), function(i, cmd){
			if ( cmd=='nod' || cmd=='nix' ) {
				nodnix_context(cmd);
				return false;
			}
		});

		if ( context_not_set ) {
			nodnix_context(undefined);
		}
	}

	return commands;
}

function firehose_handle_comment_nodnix( commands ){
	if ( commands.length ) {
		var voted=false;
		commands = $.map(commands, function( cmd ){
			var match = /^([\-!]*)(nod|nix)$/.exec(cmd);
			if ( match ) {
				var modifier = match[1], vote = match[2];
				cmd = modifier + 'meta' + vote;
				if ( ! modifier ) {
					voted = true;
				}
			}
			return cmd;
		});

		var $entry = $(this);
		if ( voted ) {
			Firehose.collapse_entries($entry);
		}
		$entry.find('.nod-nix-reasons').each(function(){
			this.set_context(undefined);
		});
	}

	return commands;
}

function firehose_tag_feedback( signal, data ){
	var tr = this.tag_ui_responder;
	var tags;

	function if_have( k ){ return k in tags || 'meta'+k in tags; }
	function if_busy( depth ){ return depth>0; }

	var $entry = tr._$entry || (tr._$entry = $(this).nearest_parent('.tag-server'));

	var depth, was_busy=if_busy(depth = tr._busy_depth || 0);
	switch ( signal ) {
		case 'user':		// fix the nod/nix capsule, data => user tags
			tags = qw.as_set(data);
			var nod = if_have('nod'), nix = if_have('nix');
			(tr._$updown || (tr._$updown = $entry.find('#updown-' +  $entry.attr('tag-server')))).
				setClass(nod==nix && 'vote' || nod && 'votedup' || 'voteddown');
			break;
		case 'ajaxSuccess':	// new tags are all in place, refresh "computed styles"
			Slash.TagUI.Markup.refresh_styles($entry);
			break;
		case 'ajaxStart':	// start the spinner
			++depth;
			break;
		case 'ajaxComplete':	// stop the spinner
			--depth;
			break;
	}
	if ( was_busy != if_busy(tr._busy_depth = depth) ) {
		var $spinner = $(this);
		if ( was_busy ) {
			$spinner.removeAttr('style');
		} else {
			$spinner.show();
		}
	}
}

function firehose_click_nodnix_reason( event ) {
	Firehose.set_action();
	var $entry = $(event.target).nearest_parent('.tag-server');
	var id = $entry.attr('tag-server');

	if ( (fh_is_admin || firehose_settings.metamod) && ($('#updown-'+id).hasClass('voteddown') || $entry.is('[type=comment]')) ) {
		Firehose.collapse_entries($entry);
	}

	return true;
}


function firehose_init_tag_ui( $new_entries ){
	if ( ! $new_entries || ! $new_entries.length ) {
		var $firehoselist = $('#firehoselist');
		if ( $firehoselist.length ) {
			$new_entries = $firehoselist.children('[id^=firehose-][class*=article]');
		} else {
			$new_entries = $('[id^=firehose-][class*=article]');
		}
	}
	$new_entries = $new_entries.filter(':not(.tag-server)');

	var pipeline = [ firehose_handle_context_triggers ];
	if ( fh_is_admin ) {
		pipeline.unshift(firehose_handle_admin_commands);
	}

	$new_entries.
		tag_ui_server(firehose_id_of, pipeline, { request_data: { reskey: reskey_static } }).
		each(function(){
			this.tag_ui_server.command_pipeline.push(
				($(this).attr('type') == 'comment') ?
					firehose_handle_comment_nodnix :
					firehose_handle_nodnix );
		}).
		find('.title').
			append('<div class="tag-widget-stub nod-nix-reasons" init="context_timeout:15000">' +
					'<div class="tag-display-stub respond-related" init="legend:\'why\', menu:false" />' +
				'</div>').
			find('.tag-display-stub').
				click(firehose_click_nodnix_reason);

	Slash.Firehose.TagUI.init($new_entries);

	if ( fh_is_admin ) {
		$new_entries.
			find('.body-widget').
				each(function(){
					this.tag_ui_widget.modify_context = firehose_admin_context;
				});
	}

	$new_entries.
		find('.tag-server-busy').
			tag_ui_responder(firehose_tag_feedback, 'user ajaxStart ajaxSuccess ajaxComplete');

	$new_entries.
		find('.tag-entry').
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
		});
}


$(function(){
	var add_style_triggers = Slash.TagUI.Markup.add_style_triggers;


	add_style_triggers(YAHOO.slashdot.sectionTags, 's1');
	add_style_triggers(YAHOO.slashdot.topicTags, 't2');
	add_style_triggers(['nod', 'metanod'], 'y p');
	add_style_triggers(['nix', 'metanix'], 'x p', );
	add_style_triggers(qw('submission journal bookmark feed story vendor misc comment discussion project'), 'd');

	if ( fh_is_admin ) {
		add_style_triggers(['signed', 'unsigned', 'signoff'], 'w p');
		Slash.TagUI.Display.defaults.menu = 'x ! # ## _ )';
	}
});



})(jQuery);
