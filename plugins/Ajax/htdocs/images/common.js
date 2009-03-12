// _*_ Mode: JavaScript; tab-width: 8; indent-tabs-mode: true _*_
; // $Id$

/*global setFirehoseAction firehose_get_updates tagsHideBody tagsShowBody
	firehose_fix_up_down firehose_toggle_tag_ui_to ajax_update json_handler
	json_update firehose_reorder firehose_get_next_updates getFirehoseUpdateInterval run_before_update
	firehose_play firehose_add_update_timerid firehose_collapse_entry
	 vendorStoryPopup vendorStoryPopup2 firehose_save_tab check_logged_in
	scrollWindowToFirehose scrollWindowToId viewWindowLeft getOffsetTop firehoseIsInWindow
	isInWindow viewWindowTop viewWindowBottom firehose_set_cur firehose_style_switch
	firehose_style_switch_handler */

YAHOO.namespace('slashdot');

;$(function(){
	$.ajaxSetup({
		url:	'/ajax.pl',
		type:	'POST',
		contentType: 'application/x-www-form-urlencoded'
	});
});

var reskey_static = '';

// global settings, but a firehose might use a local settings object instead
var firehose_settings = {};
  firehose_settings.startdate = '';
  firehose_settings.duration = '';
  firehose_settings.mode = '';
  firehose_settings.color = '';
  firehose_settings.orderby = '';
  firehose_settings.orderdir = '';
  firehose_settings.view = '';
  firehose_settings.tab = '';
  firehose_settings.fhfilter  = '';
  firehose_settings.base_filter = '';
  firehose_settings.user_view_uid = '';

  firehose_settings.issue = '';
  firehose_settings.is_embedded = 0;
  firehose_settings.not_id = 0;
  firehose_settings.section = 0;
  firehose_settings.more_num = 0;
  firehose_settings.metamod = 0;
  firehose_settings.admin_filters = 0;

// Settings to port out of settings object
  firehose_item_count = 0;
  firehose_updates = [];
  firehose_updates_size = 0;
  firehose_ordered = [];
  firehose_before = [];
  firehose_after = [];
  firehose_removed_first = '0';
  firehose_removals = null;
  firehose_future = null;
  firehose_more_increment = 10;

// globals we haven't yet decided to move into |firehose_settings|
var fh_play = 0;
var fh_is_timed_out = 0;
var fh_is_updating = 0;
var fh_update_timerids = [];
var fh_is_admin = 0;
var console_updating = 0;
var fh_ticksize;
var fh_colors = [];
var fh_idle_skin = 0;
var vendor_popup_timerids = [];
var vendor_popup_id = 0;
var ua=navigator.userAgent;
var is_ie = ua.match("/MSIE/");

// ads
var fh_adTimerSecsMax   = 15;
var fh_adTimerClicksMax = 0;
var fh_adTimerUrl       = '';
//fh_adTimerUrl = '/images/iframe/firehose.html'; // testing


function createPopup(xy, titlebar, name, contents, message, onmouseout) {
	var body = document.getElementsByTagName("body")[0];
	var div = document.createElement("div");
	div.id = name + "-popup";
	div.style.position = "absolute";

	if (onmouseout) {
		div.onmouseout = onmouseout;
	}

	var leftpos = xy[0] + "px";
	var toppos  = xy[1] + "px";

	div.style.left = leftpos;
	div.style.top = toppos;
	div.style.zIndex = "100";
	contents = contents || "";
	message  = message || "";

	div.innerHTML = '<iframe></iframe><div id="' + name + '-title" class="popup-title">' + titlebar + '</div>' +
                        '<div id="' + name + '-contents" class="popup-contents">' + contents + '</div>' +
			'<div id="' + name + '-message" class="popup-message">' + message + '</div>';

	body.appendChild(div);
	div.className = "popup";
	return div;
}

function createPopupButtons() {
	return '<span class="buttons"><span>' + $.makeArray(arguments).join('</span><span>') + '</span></span>';
}

function closePopup(id, refresh) {
	$('#'+id).remove();
	if (refresh) {
		window.location.reload();
	}
}

function handleEnter(ev, func, arg) {
	if (!ev) {
		ev = window.event;
	}
	var code = ev.which || ev.keyCode;
	if (code == 13) { // return/enter
		func(arg);
		ev.returnValue = true;
		return true;
	}
	ev.returnValue = false;
	return false;
}


function moveByObjSize(div, addOffsetWidth, addOffsetHeight) {
	if (addOffsetWidth) {
		div.style.left = parseFloat(div.style.left || 0) + (addOffsetWidth * div.offsetWidth) + "px";
	}
	if (addOffsetHeight) {
		div.style.top = parseFloat(div.style.top || 0) + (addOffsetHeight * div.offsetHeight) + "px";
	}
}

function moveByXY(div, x, y) {
	if (x) {
		div.style.left = parseFloat(div.style.left || 0) + x + "px";
	}
	if (y) {
		div.style.top = parseFloat(div.style.top || 0) + y + "px";
	}
}

function getXYForSelector( selector, addWidth, addHeight ){
	var $elem = $(selector);
	var dX = addWidth ? $elem.attr('offsetWidth') : 0;
	var dY = addHeight ? $elem.attr('offsetHeight') : 0;

	var o = $elem.offset();
	return [ o.left+dX, o.top+dY ];
}

// function getXYForId(id, addWidth, addHeight){ return getXYForSelector('#'+id, addWidth, addHeight); }

function firehose_id_of( expr ) {
	try {
		// We accept a number, or...
		if ( typeof expr === 'number' ) {
			return expr;
		}

		// ...a dom element that is or is within a firehose entry, or...
		else if ( typeof expr === 'object' && expr.parentNode ) {
			if ( expr.id && expr.id.match(/-\d+$/) ) {
				expr = expr.id;
			} else {
				expr = $(expr).parents('[id^=firehose-]').attr('id');
			}
		}

		// ...a string that is a number or the id of
		//	a dom element that is or is within a firehose entry.
		var match = /(?:.+-)?(\d+)$/.exec(expr);

		// We return an integer id.
		if ( match ) {
			return parseInt(match[1], 10);
		}
	}
	catch ( e ) {
		// If we can't deduce an integer id; we won't throw...
	}

	// ...but we won't return an answer, either.
	return undefined;
}

function after_article_moved( article ){
	var data = article ? $(article).nextAll(':visible').andSelf() : null;
	$('#firehoselist').trigger('articlesMoved', data);
}

function before_article_removed( article, if_also_trigger_moved ){
	var next_article = article ? $(article).next(':visible')[0] : null;
	$('#firehoselist').trigger('beforeArticleRemoved', article);
	if ( if_also_trigger_moved ) {
		after_article_moved(next_article);
	}
}

function firehose_toggle_advpref() {
	$('#fh_advprefs').toggleClass('hide');
}

function firehose_open_prefs() {
	$('#fh_advprefs').removeClass();
}

function toggleIntro(id, toggleid) {
	var new_class = 'condensed';
	var new_html = '[+]';
	if ( $('#'+id).setClass(applyMap('introhide', 'intro')).hasClass('intro') ) {
		new_class = 'expanded';
		new_html = '[-]';
	}
	$('#'+toggleid).setClass(new_class).html(new_html);
}


function tagsToggleStoryDiv(id, is_admin, type) {
	if ( $('#toggletags-body-'+id).hasClass('tagshide') ) {
		tagsShowBody(id, is_admin, '', type);
	} else {
		tagsHideBody(id);
	}
}

function tagsHideBody(id) {
	$('#toggletags-body-'+id).setClass('tagshide');		// Make the body of the tagbox vanish
	$('#tagbox-title-'+id).setClass('tagtitleclosed');	// Make the title of the tagbox change back to regular
	$('#tagbox-'+id).setClass('tags');			// Make the tagbox change back to regular.
	$('#toggletags-button-'+id).html('[+]');		// Toggle the button back.
	after_article_moved($('#firehose-'+id)[0]);
}

function tagsShowBody(id, is_admin, newtagspreloadtext, type) {

	type = type || "stories";

	if (type == "firehose") {
		setFirehoseAction();
		if (fh_is_admin) {
			firehose_get_admin_extras(id);
		}
	}

	//alert("Tags show body / Type: " + type );
	$('#toggletags-button-'+id).html("[-]");		// Toggle the button to show the click was received
	$('#tagbox-'+id).setClass("tags");			// Make the tagbox change to the slashbox class
	$('#tagbox-title-'+id).setClass("tagtitleopen");	// Make the title of the tagbox change to white-on-green
	$('#toggletags-body-'+id).setClass("tagbody");		// Make the body of the tagbox visible
	after_article_moved($('#firehose-'+id)[0]);
}

function tagsOpenAndEnter(id, tagname, is_admin, type) {
	// This does nothing if the body is already shown.
	tagsShowBody(id, is_admin, tagname, type);
}

function reportError(request) {
	// replace with something else
	alert("error");
}

//Firehose functions begin
function toggle_firehose_body( id, is_admin, /*optional:*/toggle_to ) {
	setFirehoseAction();

	var	body_id		= 'fhbody-' + id,
		$body		= $any(body_id),
		body_is_empty	= $body.is('.empty'),
		toggle_from	= sign(!body_is_empty && !$body.is('.hide') || -1);


	// normalize toggle_to to a number: toggle_to>0 => show, toggle_to==0 => toggle, toggle_to<0 => hide
	if ( toggle_to === false ) {
		// from boolean: true=>show, false=>hide
		toggle_to = -1;
	} else if ( typeof(toggle_to)==='string' ) {
		// from string: 'show'=>show, 'hide'=>hide, else toggle
		toggle_to = { show:1, hide:-1 }[toggle_to];
	}
	// from anything else, use sign(toggle_to); resolve cases that toggle now
	toggle_to = sign(toggle_to||-toggle_from);
	if ( toggle_to == toggle_from ) {
		return;
	}


	if ( body_is_empty ) {
		var handlers = {};
		is_admin && (handlers.onComplete = function(){
			vScrollToAny('firehose-'+id, vScrollToAny.IF_VISIBLE);
			firehose_get_admin_extras(id);
		});
		ajax_update({ op:'firehose_fetch_text', id:id, reskey:reskey_static }, body_id, handlers);
	}

	var	toggle_to_show	= toggle_to > 0,
		op		= toggle_to_show ? 'show' : 'hide',
		class_for	= toggle_firehose_body.class_for[op];

	$body.setClass(class_for.body).
		closest('#firehose-' + id).
			setClass(class_for.article).
			addClass(fh_is_admin ? 'adminmode' : 'usermode').
			find('h3 a img')[op]('fast').end().
			each(function(){
				after_article_moved(this);
				inlineAdFirehose(toggle_to_show && $(this));
				firehose_set_cur($(this));
			});
	return false;
}
toggle_firehose_body.SHOW	= 1;
toggle_firehose_body.TOGGLE	= 0;
toggle_firehose_body.HIDE	= -1;
toggle_firehose_body.class_for = {
	show: { body:'body', article:'article' },
	hide: { body:'hide', article:'briefarticle' }
};

function toggleFirehoseTagbox(id) {
	$('#fhtagbox-'+id).setClass(applyMap('tagbox', 'hide'));
	after_article_moved($('#firehose-'+id)[0]);
}

function firehose_style_switch(section) {
	var params = {};
	params['op'] 	 	= 'firehose_section_css';
	params['layout'] 	= 'yui';
	params['reskey'] 	= reskey_static;
	params['section'] 	= section;

	ajax_update(params, '', { onComplete: firehose_style_switch_handler });
}

function firehose_style_switch_handler(transport) {
	var response = eval_response(transport);

	if (response && response.skin_name) {
		if ($('html head link[title=' + response.skin_name + ']').length == 0 ) {
                      $('html head link:last').after(response.css_includes);
		}

		$("head link[title]").each(function(i) {
			        this.disabled = true;
				if (this.getAttribute('title') == response.skin_name) {
					this.disabled = false;
				}
	        });
	} else {
		$("head link[title]").each(function(i) { this.disabled = true; });
	}
}


var firehose_set_options;
(function(){
var	qw = Slash.Util.qw,
	uses_setfield	= qw.as_set('mixedmode nobylines nocolors nocommentcnt nodates nomarquee noslashboxes nothumbs'),
	loads_new	= qw.as_set('section setfhfilter setsearchfilter tab view'),
	removes_all	= $.extend(qw.as_set('firehose_usermode mixedmode mode nocolors nothumbs'), loads_new),
	sets_param	= $.extend(qw.as_set('color duration issue pagesize pause startdate tab tabtype usermode'), uses_setfield),
	flags_param	= {	fhfilter:	'filterchanged',
				more_num:	'ask_more',
				section:	'sectionchanged',
				setfhfilter:	'filterchanged',
				setsearchfilter:'searchtriggered',
				tab:		'tabchanged',
				usermode:	'setusermode',
				view:		'viewchanged'
			},
	sets_directly	= qw.as_set('color duration issue mode orderby orderdir section startdate tab view'),
	sets_indirectly	= {	setfhfilter:	'fhfilter',
				setsearchfilter:'fhfilter',
				tabsection:	'section'
			},
	resets_pagemore	= qw.as_set('fhfilter view tab issue pagesize section setfhfilter setsearchfilter'),
	toggle_pairs	= {	orderby_createtime:	{ id:"popularity",	new_id:"time",		new_value:"popularity" },
				orderby_popularity:	{ id:"time",		new_id:"popularity",	new_value:"createtime" },
				orderdir_ASC:		{ id:"asc",		new_id:"desc",		new_value:"DESC" },
				orderdir_DESC:		{ id:"desc",		new_id:"asc",		new_value:"ASC" },
				mode_full:		{ id:"abbrev",		new_id:"full",		new_value:"fulltitle" },
				mode_fulltitle:		{ id:"full",		new_id:"abbrev",	new_value:"full" }
			},
	update_handlers	= {	onComplete: function(transport) {
					json_handler(transport);
					firehose_get_updates({ oneupdate: 1 });
				}
			};

function set_fhfilter_from( expr ){
	$(expr).each(function(){
		firehose_settings.fhfilter = this.value;
	});
}
function toggle_details( selector, hide ){
	var $elem = $(selector).toggleClass('hide', !!hide);
	hide || $elem.css({ display: 'inline' });
}

firehose_set_options = function(name, value, context) {
	// Exit early for trouble.
	if ( !firehose_user_class || name==='color' && !value ) {
		return;
	}

	// Perl thinks true and false are strings, so never let booleans get to the server.
	typeof(value)==='boolean' && (value = sign(value));


	// Set values in params and firehose_settings; mostly table-driven...
	var params={};
	uses_setfield[name]	&& (params.setfield = 1);
	sets_param[name]	&& (params[name] = value);
	flags_param[name]	&& (params[flags_param[name]] = 1);
	sets_directly[name]	&& (firehose_settings[name] = value);
	sets_indirectly[name]	&& (firehose_settings[sets_indirectly[name]] = value);
	resets_pagemore[name]	&& (firehose_settings.page = firehose_settings.more_num = 0);
	// ...and a few exceptions "by hand".
	switch ( name ) {
		case 'fhfilter':	set_fhfilter_from('form[name=firehoseform] input[name=fhfilter]'); break;
		case 'issue':		firehose_settings.startdate=value; firehose_settings.duration=1; break;
		case 'mode':		fh_view_mode=value; break;
		case 'nobylines':	toggle_details('#firehoselist span.nickname', value); break;
		case 'nodates':		toggle_details('#firehoselist span.date', value); break;
		case 'tabsection':	params.tabtype='tabsection'; break;
		case 'view':		set_fhfilter_from('#searchquery'); break;
	}


	// For "toggling" options, update the toggle-element's click-handler.
	var toggle = toggle_pairs[ name+'_'+value ];
	toggle && $any(toggle.id).each(function(){
		this.id = toggle.new_id;
		$('>*:first', this).
			unbind('click.option-toggle').
			bind('click.option-toggle', function(){
				firehose_set_options(name, toggle.new_value);
				return false;
			});
	});


	// If removing list items, fadeOut the list first...
	removes_all[name] && $any('firehoselist').fadeOut(function(){
		// ...then actually delete its contents, possibly with a loading message.
		$(this).html(loads_new[name] ? '<h1 class="loading_msg">Loading New Items</h1>' : '').
			css({ opacity:1 });
	});
	// div.paginate isn't in the list, so it wasn't handled above.
	loads_new[name] && $('div.paginate').hide();


	// Tell the server (asynchronously).
	ajax_update($.extend({
			op:		'firehose_set_options',
			reskey:		reskey_static,
			setting_name:	name,
			context:	context,
			section:	firehose_settings.section
		}, params, firehose_settings),
		'', update_handlers
	);

	// Tell the UI.
	$(document).trigger('firehose-setting-' + name, value);
};
})();

function firehose_fix_up_down( id, new_state ){
	// Find the (possibly) affected +/- capsule.
	var $updown = $('#updown-'+id);

	if ( $updown.length && ! $updown.hasClass(new_state) ) {
		// We found the capsule, and it's state needs to be fixed.
		$updown.setClass(new_state);
	}
}

function firehose_click_nodnix_reason( event ) {
	var $entry = $(event.target).closest('[tag-server]');
	var id = $entry.attr('tag-server');

	if ( (fh_is_admin || firehose_settings.metamod) && ($('#updown-'+id).hasClass('voteddown') || $entry.is('[type=comment]')) ) {
		firehose_collapse_entry(id);
	}

	return true;
}


function firehose_remove_tab(tabid) {
	setFirehoseAction();
	ajax_update({
		op:		'firehose_remove_tab',
		tabid:		tabid,
		reskey:		reskey_static,
		section:	firehose_settings.section
	}, '', { onComplete: json_handler });

}


//
// firehose + tag_ui
//

var $related_trigger = $().filter();

var kExpanded=true, kCollapsed=false;

function firehose_toggle_tag_ui_to( if_expanded, selector ){
	var	$server = $(selector).closest('[tag-server]'), // assert($server.length)
		id	= $server.attr('tag-server'),
		$widget = $server.find('.tag-widget.body-widget'),
		toggle	= $widget.length && $widget.hasClass('expanded') == !if_expanded; // force boolean conversion

	if ( toggle ) {
		setFirehoseAction();
		$server.find('.tag-widget').each(function(){ this.set_context(); });

		$widget.toggleClass('expanded', !!if_expanded);

		var toggle_button={}, toggle_div={};
		if ( if_expanded ){
			$server[0].fetch_tags();
			fh_is_admin && firehose_get_admin_extras(id);
		}

		$widget.find('a.edit-toggle .button').setClass(applyToggle({expand:if_expanded, collapse:!if_expanded}));
		$server.find('#toggletags-body-'+id).setClass(applyToggle({tagbody:if_expanded, tagshide:!if_expanded}));
		after_article_moved($server[0]);
	}

	// always focus for expand request, even if already expanded
	if_expanded && $widget.find('.tag-entry:visible:first').focus();

	return $widget;
}

function firehose_toggle_tag_ui( toggle ) {
	firehose_toggle_tag_ui_to( ! $(toggle.parentNode).hasClass('expanded'), toggle );
}

function firehose_click_tag( event ) {
	var $target = $(event.target), command = '', $menu;

	// skip for non-JS hrefs
	if (! $target.closest('a[href]:not([href=#])').length) {
		// _any_ click can trigger, but click-specific ad will win
		setTimeout(function(){ inlineAdFirehose(); }, 0);
	}

	$related_trigger = $target;

	if ( $target.is('a.up') ) {
		command = 'nod';
	} else if ( $target.is('a.down') ) {
		command = 'nix';
	} else if ( $target.is('.tag') ) {
		command = $target.text();
	} else if ( ($menu = $target.closest('.tmenu')).length ) {
		var op = $target.text();
		var $tag = $target.closest(':has(span.tag)').find('.tag');
		$related_trigger = $tag;

		var tag = $tag.text();
		command = normalize_tag_menu_command(tag, op);
	} else {
		$related_trigger = $().filter();
	}

	var $server = $target.closest('[tag-server]');
	if ($server.length) {
		firehose_set_cur($server);
	}

	if ( command ) {
		// No!  You no hurt Dr. Jones!  You log-in first!
		if ( ! check_logged_in() ) {
			return false;
		}

		// Make sure the user sees some feedback...
		if ( $menu || event.shiftKey ) {
			// for a menu command or copying a tag into edit field, open the tag_ui
			var $widget = firehose_toggle_tag_ui_to(kExpanded, $server);

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
			$widget.find('.tag-entry:text:visible:first').each(function(){
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
			$server.each(function(){
				this.submit_tags(command, { fade_remove: 400, order: 'prepend', classes: 'not-saved'});
			});
		}
		return false;
	}

	return true;
}


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
		var nodnix_context = function( ctx ){
			$reasons.each(function(){
				this.set_context(ctx);
			});
		};

		var tag_server=this, context_not_set=true;
		$.each(commands.slice(0).reverse(), function(i, cmd){
			if ( cmd=='nod' || cmd=='nix' ) {
				nodnix_context(cmd);
				context_not_set = false;
				firehose_fix_up_down(
					tag_server.getAttribute('tag-server'),
					{ nod:'votedup', nix:'voteddown' }[cmd] );
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
		var tag_server=this, handled_underlying=false;
		commands = $.map(commands.reverse(), function( cmd ){
			var match = /^([\-!]*)(nod|nix)$/.exec(cmd);
			if ( match ) {
				var modifier = match[1], vote = match[2];
				cmd = modifier + 'meta' + vote;
				if ( !handled_underlying && !modifier ) {
					var id = tag_server.getAttribute('tag-server');
					firehose_fix_up_down(
						id,
						{ nod:'votedup', nix:'voteddown' }[vote] );
					firehose_collapse_entry(id);
					handled_underlying = true;
				}
			}
			return cmd;
		}).reverse();

		$('.nod-nix-reasons', this).each(function(){
			this.set_context(undefined);
		});
	}

	return commands;
}


$(function(){
	firehose_init_tag_ui();
	$('#firehoselist').click(firehose_click_tag);	// if no #firehoselist, install click handler per article
	firehose_set_cur(firehose_get_cur());
});



function inject_reasons( expr, init ){
	// expr is an element, selector, or $selection.
	var $selection = $any(expr);
	$selection.
		find('>h3').
			append(inject_reasons.template).
			find('.tag-display-stub').
				click(firehose_click_nodnix_reason);

	// Unless caller _explicitly_ tells me _not_ to init, e.g., inject_reasons(..., false)...
	if ( $.TypeOf.not('defNo', init) ) {
		$init_tag_widgets($selection.find('.tag-widget-stub'));
	}
}
inject_reasons.template = (
'<div class="tag-widget-stub nod-nix-reasons" init="context_timeout:15000">' +
	'<div class="tag-display-stub" context="related" init="menu:false" />' +
'</div>'
);


function firehose_init_tag_ui( $new_entries ){
	var $firehoselist = $('#firehoselist');

	if ( ! $new_entries || ! $new_entries.length ) {
		if ( $firehoselist.length ) {
			$new_entries = $firehoselist.children('[id^=firehose-][class*=article]');
		} else {
			$new_entries = $('[class*=article]');
		}
	}

	$new_entries = $new_entries.filter(':not([tag-server])');
	var have_nodnix = $new_entries.children('[id^=updown-]').length;

	$new_entries.
		each(function(){
			var $this = $(this), id = firehose_id_of(this);

			install_tag_server(this, id);

			if ( tag_admin ) {
				this.command_pipeline.push(firehose_handle_admin_commands);
			}

			this.command_pipeline.push(firehose_handle_context_triggers);

			if ( have_nodnix ) {
				// install nod/nix handling only if I see the nod/nix buttons
				this.command_pipeline.push(
					($this.attr('type') == 'comment') ?
						firehose_handle_comment_nodnix :
						firehose_handle_nodnix);
				inject_reasons(this, false);
			}
		});

	if ( ! $firehoselist.length ) {
		$new_entries.click(firehose_click_tag);
	}

	var $widgets = $init_tag_widgets($new_entries.find('.tag-widget-stub'));

	if ( tag_admin ) {
		$widgets.
			filter('.body-widget').
				each(function(){
					this.modify_context = firehose_admin_context;
				});
	}

	return init_tag_ui_styles($new_entries);
}
// firehose functions end

// helper functions
function ajax_update(request_params, id, handlers, options) {
	// make an ajax request to request_url with request_params, on success,
	//  update the innerHTML of the element with id
	if ( !options ) {
		options = {};
	}

	var opts = {
		data: request_params
	};

	if ( options.request_url ) {
		opts.url = options.request_url;
	}

	if ( options.async_off ) {
		opts.async = false;
	}

	if ( id ) {
		opts.success = function(html){
			$('#'+id).html(html);
		};
	}

	if ( handlers && handlers.onComplete ) {
		opts.complete = handlers.onComplete;
	}

	if ( handlers && handlers.onError ) {
		opts.error = handlers.onError;
	}

	jQuery.ajax(opts);
}

function ajax_periodic_update(interval_in_seconds, request_params, id, handlers, options) {
	setInterval(function(){
		ajax_update(request_params, id, handlers, options);
	}, interval_in_seconds*1000);
}

function eval_response(transport) {
	var response;
	try {
/*jslint evil: true */
		eval("response = " + transport.responseText);
/*jslint evil: false */
	} catch (e) {
		//alert(e + "\n" + transport.responseText)
	}
	return response;
}

function json_handler(transport) {
	var response = eval_response(transport);
	response && json_update(response);
	return response;
}

function json_update(response) {
	if ( ! response ) {
		return;
	}

	if (response.eval_first) {
		try {
/*jslint evil: true */
			eval(response.eval_first);
/*jslint evil: false */
		} catch (e0) {

		}
	}

	// Server says:

	// ...replace the content of these elements
	$.each(response.html||[], function(elem_id, new_html){
		$('#'+elem_id).
			html(new_html);
	});

	// ...set new values in these elements
	$.each(response.value||[], function(elem_id, new_value){
		$('#'+elem_id).
			each(function(){
				if ( this !== gFocusedText ) {
					$(this).val(new_value);
				}
			});
	});

	// ...append content to these elements
	$.each(response.html_append||[], function(elem_id, new_html){
		$('#'+elem_id).
			append(new_html);
	});

	// ...replace the specially marked "tail-end" (or else append) content of these elements
	$.each(response.html_append_substr||[], function(elem_id, new_html){
		$('#'+elem_id).
			each(function(){
				var	$this		= $(this),
					old_html	= $this.html(),
					truncate_at	= old_html.search(/<span class="?substr"?> ?<\/span>[\s\S]*$/i);
				if ( truncate_at != -1 ) {
					old_html = old_html.substr(0, truncate_at);
				}
				$this.html(old_html + new_html);
			});
	});

	// ...trigger events on these elements (do this last to include any content added above)
	$.each(response.events||[], function(){
		if ( this.event ) {
			$(this.target||document).trigger(this.event, this.data);
		}
	});

	if (response.eval_last) {
		try {
/*jslint evil: true */
			eval(response.eval_last);
/*jslint evil: false */
		} catch (e1) {

		}
	}
}

function firehose_handle_update() {
	var saved_selection = new $.TextSelection(gFocusedText);
	var $menu = $('div.ac_results:visible');

	var add_behind_scenes = $("#firehoselist h1.loading_msg").length;
	if (add_behind_scenes) { firehose_busy(); }

	if (firehose_updates.length > 0) {
		var el = firehose_updates.pop();
		var fh = 'firehose-' + el[1];
		var wait_interval = 800;
		var need_animate = 1;

		var attributes = {};
		var myAnim;

		if(el[0] == "add") {
			if (firehose_before[el[1]] && $('#firehose-' + firehose_before[el[1]]).size()) {
				$('#firehose-' + firehose_before[el[1]]).after(el[2]);
				if (!isInWindow($dom('title-'+ firehose_before[el[1]]))) {
					need_animate = 0;
				}
			} else if (firehose_after[el[1]] && $('#firehose-' + firehose_after[el[1]]).size()) {

				// don't insert a new article between the floating slashbox ad and its article
				var $landmark = $('#firehose-' + firehose_after[el[1]]), $prev = $landmark.prev();
				if ( $prev.is('#floating-slashbox-ad') ) {
					$landmark = $prev;
				}

				$landmark.before(el[2]);
				if (!isInWindow($dom('title-'+ firehose_after[el[1]]))) {
					need_animate = 0;
				}
			} else if (insert_new_at == "bottom") {
				$('#firehoselist').append(el[2]);
				if (!isInWindow($dom('fh-paginate'))) {
					need_animate = 0;
				}
			} else {
				$('#firehoselist').prepend(el[2]);
			}

			if (add_behind_scenes) {
				need_animate = 0;
			}

			var toheight = 50;
			if (fh_view_mode == "full") {
				toheight = 200;
			}

			attributes = {
				height: { from: 0, to: toheight }
			};
			if (!is_ie) {
				attributes.opacity = { from: 0, to: 1 };
			}
			myAnim = new YAHOO.util.Anim(fh, attributes);
			myAnim.duration = 0.7;

			if (firehose_updates_size > 10) {
				myAnim.duration = myAnim.duration / 2;
				wait_interval = wait_interval / 2;
			}
			if (firehose_updates_size > 20) {
				myAnim.duration = myAnim.duration / 2;
				wait_interval = wait_interval / 2;

			}
			if (firehose_updates_size > 30) {
				myAnim.duration = myAnim.duration / 1.5;
				wait_interval = wait_interval / 2;
			}

			myAnim.onComplete.subscribe(function() {
				var fh_node = $dom(fh);
				if (fh_node) {
					after_article_moved(fh_node);
					fh_node.style.height = "";
					if (fh_idle_skin) {
						/* $("h3 a[class!='skin']", fh_node).click(function(){
							var h3 = $(this).parent('h3');
							h3.next('div.hid').and(h3.find('a img')).toggle("fast");
							return false;
						}); */
					}
				}
			});
			if (need_animate) {
				myAnim.animate();
			}
		} else if (el[0] == "remove") {
			var fh_node = $dom(fh);
			if (fh_is_admin && fh_view_mode == "fulltitle" && fh_node && fh_node.className == "article" ) {
				// Don't delete admin looking at this in expanded view
			} else {
				attributes = {
					height: { to: 0 }
				};

				if (!is_ie) {
					attributes.opacity = { to: 0};
				}
				myAnim = new YAHOO.util.Anim(fh, attributes);
				myAnim.duration = 0.4;
				wait_interval = 500;

				if (firehose_updates_size > 10) {
					myAnim.duration = myAnim.duration * 2;
					if (!firehose_removed_first) {
						wait_interval = wait_interval * 2;
					} else {
						wait_interval = 50;
					}
				}
				firehose_removed_first = 1;
				if (!isInWindow(fh_node)) {
					need_animate = 0;
				}

				if ((firehose_removals < 10 ) && !add_behind_scenes ) {
					myAnim.onComplete.subscribe(function() {
						var elem = this.getEl();
						if (elem && elem.parentNode) {
							before_article_removed(elem, true);
							elem.parentNode.removeChild(elem);
						}
					});
					myAnim.animate();
				} else {
					var elem = $dom(fh);
					wait_interval = 25;
					if (elem && elem.parentNode) {
						elem.parentNode.removeChild(elem);
					}
				}
			}
		}
		if(!need_animate || add_behind_scenes) {
			wait_interval = 0;
		}
		
		//console.log("Wait: " + wait_interval);
		setTimeout(firehose_handle_update, wait_interval);
	} else {
		firehose_after_update();
		if (add_behind_scenes) {
			$('#firehoselist h1.loading_msg').each(function() { if(this && this.parentNode) { this.parentNode.removeChild(this);} });
			$('.paginate').show();
			if (elem && elem.parentNode) {
				elem.parentNode.removeChild(elem);
			}
			$('#firehoselist').fadeIn('slow');
			firehose_busy_done();
		}
		firehose_get_next_updates();
	}

	var $new_entries = firehose_init_tag_ui();
	if ( fh_idle_skin ) { firehose_init_idle($new_entries); }
	if ( fh_is_admin ) { firehose_init_note_flags($new_entries); }

	saved_selection.restore().focus();
	$menu.show();
}

function firehose_adjust_window(onscreen) {
	var i=0;
	var on = 0;
	while(i < onscreen.length && on === 0) {
		if(isInWindow($(onscreen[i]))) {
			on = 1;
		} else {
			scrollWindowToId(onscreen[i]);
			if(isInWindow($(onscreen[i]))) {
				on = 1;
			}
		}
		i++;
	}
}


function firehose_after_update(){
	firehose_reorder(firehose_ordered);
	firehose_set_cur(firehose_get_cur());
	firehose_update_title_count(
		firehose_storyfuture(firehose_future).length
	);
}

function firehose_storyfuture( future ){
	// Select all articles in #firehoselist.  Update .story|.future as needed.  Return the complete list.

	var if_not=['h3.future', 'h3.story'], class_if=['story', 'future'];
	return $any('firehoselist').article_info__find_articles().
		each(function(){
			var is_future = sign(future[this.id.substr(9)]);
			$(this).find(if_not[is_future]).attr('className', class_if[is_future]);
		});
}

function firehose_reorder( required_order ){
	// Reorder items in the firehose; complicated by the i2 ad.

	var $fhl = $any('firehoselist');
	if ( !required_order || !required_order.length || !$fhl.length ) {
		return $fhl;
	}

	// Build a selector for the elements corresponding to required_order.
	var order={}, i2ad_pos=required_order.length, prev=0, elid;
	var select_required = ['#floating-slashbox-ad'].concat(
		$.map(required_order, function( fhid ){
			order[elid='firehose-'+fhid] = prev;
			return '#' + (prev=elid);
		})
	).join(',');

	// Select the required elements into $fhl_items; jQuery>=1.3.2 returns it in
	// document order.  select_required included the i2 ad so we could learn its
	// relative position; but don't let it into $fhl_items.
	var $fhl_items = $(
		$fhl.children(select_required).map(function( i ){
			if ( this.id !== 'floating-slashbox-ad' ) { return this; }
			i2ad_pos = i;
		})
	);

	// Scan $fhl_items noting runs of already-ordered elements.  tails[] will include
	// the run with the i2 ad; movable_runs[] won't.
	var i=0, el=$fhl_items[0], movable_runs=[], tails=[];
	while ( el ){
		var run=[], tail;
		do { run.push(tail=el); } while ( (el=$fhl_items[++i]) && order[el.id]==tail.id );
		i>i2ad_pos ? i2ad_pos=$fhl_items.length : movable_runs.push($(run));
		tails.push(tail);
	}

	// Re-insert movable runs after the tails they were intended to follow.
	if ( tails.length > 1 ) {
		var $tails = $(tails);
		for ( var i=0; i < movable_runs.length; ++i ) {
			var $run=movable_runs[i], prev=order[$run[0].id];
			prev ? $tails.filter('#'+prev).after($run) : $fhl.prepend($run);
		}
		after_article_moved();
	}

	return $fhl;
}

function firehose_update_title_count(num) {
	var newtitle = document.title;
	if (!num) {
		num = $('#firehoselist>div[class!=daybreak]').length;
	}
	if (/\(\d+\)/.test(newtitle)) {
		newtitle = newtitle.replace(/(\(\d+\))/,"(" + num + ")");
	} else {
		newtitle = newtitle + " (" + num + ")";
	}
	document.title = newtitle;
}

function firehose_get_next_updates() {
	var interval = getFirehoseUpdateInterval();
	//alert("fh_get_next_updates");
	fh_is_updating = 0;
	firehose_add_update_timerid(setTimeout(firehose_get_updates, interval));
}

(function(){
var depth={};

//
// Slash.busy --- mark <body> with a class, e.g., 'busy-x', within the range you
//	declare x "busy": busy('x', true)...busy('x', false).  Ranges nest;
//	Slash.busy maintains a logical "busy-depth" per key.
//
Slash.busy = function( k, more ){
	var N=depth[k]||0, was_busy=N>0; // N guards against depth[k]===undefined.

	// busy(k) is a "getter"
	if ( arguments.length > 1 ) {
		// busy(k, expr) is a (relative) "setter".  Let's deduce the delta...
		if ( $.TypeOf(more)==='number' ) {	// busy(k, number) means depth[k]+=number, except...
			more===0 && (more = -N);	// ...busy(k, 0) means "reset"
		} else {				// For non-numbers (including 'number.Nan', 'number.Infinity' --- thank you, $.TypeOf)
			more = sign(more) || -1;	// busy(k, expr) means ++depth[k] or --depth[k]
		}
		(N+=more) ? depth[k]=N : delete depth[k];
		Slash.markBusy(k, N>0);	// Physical state may differ from logical, so let markBusy decide.
	}
	return was_busy; // Return previous "logical" state: old depth[k] > 0.
};

//
// Slash.markBusy --- ignore the logical depth maintained by Slash.busy, e.g.,
//	when you're calls to busy(..., true) and busy(..., false) don't balance.
//
Slash.markBusy = function( k, state ){
	var	$body = $('body'),
		was_busy = $body.is('.busy-'+k),
		now_busy = state || arguments.length<2 && depth[k]>0; // markBusy(k) resets to depth[k]>0.
	now_busy != was_busy && $body.toggleClass('busy-'+k);
	return was_busy; // Return previous "physical" state: body had class "busy-"+k.
};
})();

$(function(){
	$(document).
		ajaxStart(function(){ Slash.markBusy('ajax', true); }).
		ajaxStop(function(){ Slash.markBusy('ajax', false); });
});

function dynamic_blocks_list() {
        var boxes = $('#slashboxes div.title').
                map(function(){
                        return this.id.slice(0,-6);
                }).
                get().
                join(',');

                return boxes;
}

function dynamic_blocks_update(blocks) {
	$.each(blocks, function( k, v ) {
		$('#'+k+'-title h4').replaceWith(
			'<h4>' + (v.url ? '<a href="'+v.url+'">'+v.title+'</a>' : v.title) + '<span class="closebox">x</span></h4>'
		);
		v.block && $any(k+'-content').html(v.block);
	});
}

function firehose_busy() {
	return Slash.markBusy('firehose', true);
}

function firehose_busy_done() {
	return Slash.markBusy('firehose', false);
}

function firehose_get_updates_handler(transport) {
	firehose_busy_done();
	var response = eval_response(transport);
	if ( !response ){
		return;
	}

	var updated_tags = response.update_data.updated_tags;
	if ( updated_tags ) {
		var $tag_servers = $('[tag-server]');
		$.each(updated_tags, function( id, tags ){
			var updates = '';
			if ( tags.system_tags !== undefined )	{ updates += '<system>' + tags.system_tags; }
			if ( tags.top_tags !== undefined )	{ updates += '<top>' + tags.top_tags; }
			if ( updates ) {
				$tag_servers.filter('[tag-server='+id+']').each(function(){
					this.broadcast_tag_lists(updates);
				});
			}
		});
	}

	var processed = 0;
	firehose_removals = response.update_data.removals;
	firehose_ordered = response.ordered;
	firehose_future = response.future;
	firehose_before = [];
	firehose_after = [];
	for (i = 0; i < firehose_ordered.length; i++) {
		if (i > 0) {
			firehose_before[firehose_ordered[i]] = firehose_ordered[i - 1];
		}
		if (i < (firehose_ordered.length - 1)) {
			firehose_after[firehose_ordered[i]] = firehose_ordered[i + 1];
		}
	}
	if (response.dynamic_blocks) {
		dynamic_blocks_update(response.dynamic_blocks);
	}
	if (response.html) {
		json_update(response);
		processed = processed + 1;
	}
	if (response.updates) {
		firehose_updates = response.updates;
		firehose_updates_size = firehose_updates.length;
		firehose_removed_first = 0;
		processed = processed + 1;
		var $fh = $('#firehoselist');
		$fh.find('h1.loading_msg').show().length && $fh.hide();
		firehose_handle_update();
	}
}

function firehose_get_item_idstring() {
	return $('#firehoselist > [id]').map(function(){
		return this.id.replace(/firehose-(\S+)/, '$1');
	}).get().join(',');
}


function firehose_get_updates(options) {
	options = options || {};
	run_before_update();
	if ((fh_play === 0 && !options.oneupdate) || fh_is_updating == 1) {
		firehose_add_update_timerid(setTimeout(firehose_get_updates, 2000));
	//	alert("wait loop: " + fh_is_updating);
		return;
	}
	if (fh_update_timerids.length > 0) {
		var id = 0;
		while((id = fh_update_timerids.pop())) { clearTimeout(id); }
	}
	fh_is_updating = 1;
	var params = {
		op:		'firehose_get_updates',
		ids:		firehose_get_item_idstring(),
		updatetime:	update_time,
		fh_pageval:	firehose_settings.pageval,
		embed:		firehose_settings.is_embedded
	};

	params.dynamic_blocks = dynamic_blocks_list();

	for (i in firehose_settings) {
		if ( firehose_settings.hasOwnProperty(i) ) {
			params[i] = firehose_settings[i];
		}
	}

	firehose_busy();
	ajax_update(params, '', { onComplete: firehose_get_updates_handler, onError: firehose_updates_error_handler });
}

function firehose_updates_error_handler(XMLHttpRequest, textStatus, errorThrown) {
	if (fh_is_admin) {
		firehose_update_failed_modal();
	}
}

function setFirehoseAction() {
	var thedate = new Date();
	var newtime = thedate.getTime();
	firehose_action_time = newtime;
	if (fh_is_timed_out) {
		fh_is_timed_out = 0;
		firehose_play();
		firehose_get_updates();
		if (console_updating) {
			console_update(1, 0);
		}
	}
}

function getSecsSinceLastFirehoseAction() {
	var thedate = new Date();
	var newtime = thedate.getTime();
	var diff = (newtime - firehose_action_time) / 1000;
	return diff;
}

function getFirehoseUpdateInterval() {
	// keep this 45 seconds the same as cache in getFireHoseEssentials
	var interval = 45000;
	if (updateIntervalType == 1) {
		interval = 30000;
	}
	interval = interval + (5 * interval * getSecsSinceLastFirehoseAction() / inactivity_timeout);
	if (getSecsSinceLastFirehoseAction() > inactivity_timeout) {
		interval = 3600000;
	}

	return interval;
}

function run_before_update() {
	var secs = getSecsSinceLastFirehoseAction();
	if (secs > inactivity_timeout) {
		fh_is_timed_out = 1;
		firehose_inactivity_modal();
	}
}

function firehose_inactivity_modal() {
	$('#preference_title').html('Firehose Paused due to inactivity');
	show_modal_box();
	$('#modal_box_content').html("<a href='#' onclick='setFirehoseAction();hide_modal_box()'>Click to unpause</a>");
	show_modal_box();
}

function firehose_play(context) {
	fh_play = 1;
	setFirehoseAction();
	firehose_set_options('pause', false, context);
	$('#message_area').html('');
	$('#pauseorplay').html('Updated');
	$('#play').setClass('hide');
	$('#pause').setClass('show');
}

function is_firehose_playing() {
  return fh_play==1;
}

function firehose_pause(context) {
	fh_play = 0;
	$('#pause').setClass('hide');
	$('#play').setClass('show');
	$('#pauseorplay').html('Paused');
	firehose_set_options('pause', true, context);
}

function firehose_add_update_timerid(timerid) {
	fh_update_timerids.push(timerid);
}

function firehose_collapse_entry(id) {
	$('#firehoselist > #firehose-'+id).
		find('#fhbody-'+id+'.body').
			setClass('hide').
		end().
		setClass('briefarticle');
	tagsHideBody(id);
}

function firehose_remove_entry(id) {
	$('#firehose-'+id).animate({ height: 0, opacity: 0 }, 500, function(){
		after_article_moved(this);
		this.remove();
	});
}

var firehose_cal_select_handler = function(type,args,obj) {
	var selected = args[0];
	firehose_settings.issue = '';
	firehose_set_options('startdate', selected.startdate);
	firehose_set_options('duration', selected.duration);
};


function firehose_calendar_init( widget ) {
	widget.changeEvent.subscribe(firehose_cal_select_handler, widget, true);
}

function firehose_swatch_color(){} // does not exist until firehose-color-picker makes it available

function firehose_change_section_anon(section) {
	window.location.href= window.location.protocol + "//" + window.location.host + "/firehose.pl?section=" + encodeURIComponent(section) + "&tabtype=tabsection";
}

function pausePopVendorStory(id) {
	vendor_popup_id=id;
	closePopup('vendorStory-26-popup');
	vendor_popup_timerids[id] = setTimeout(vendorStoryPopup, 500);
}

function clearVendorPopupTimers() {
	clearTimeout(vendor_popup_timerids[26]);
}

function vendorStoryPopup() {
	id = vendor_popup_id;
	var title = "<a href='//intel.vendors.slashdot.org' onclick=\"javascript:pageTracker._trackPageview('/vendor_intel-popup/intel_popup_title');\">Intel's Opinion Center</a>";
	var buttons = createPopupButtons("<a href=\"#\" onclick=\"closePopup('vendorStory-" + id + "-popup')\">[X]</a>");
	title = title + buttons;
	var closepopup = function (e) {
		if (!e) { e = window.event; }
		var relTarg = e.relatedTarget || e.toElement;
		if (relTarg && relTarg.id == "vendorStory-26-popup") {
			closePopup("vendorStory-26-popup");
		}
	};
	createPopup(getXYForSelector('#sponsorlinks'), title, "vendorStory-" + id, "Loading", "", closepopup );
	var params = {};
	params.op = 'getTopVendorStory';
	params.skid = id;
	ajax_update(params, "vendorStory-" + id + "-contents");
}

function pausePopVendorStory2(id) {
	vendor_popup_id=id;
	closePopup('vendorStory-26-popup');
	vendor_popup_timerids[id] = setTimeout(vendorStoryPopup2, 500);
}

function vendorStoryPopup2() {
	id = vendor_popup_id;
	var title = "<a href='//intel.vendors.slashdot.org' onclick=\"javascript:pageTracker._trackPageview('/vendor_intel-popup/intel_popup_title');\">Intel's Opinion Center</a>";
	var buttons = createPopupButtons("<a href=\"#\" onclick=\"closePopup('vendorStory-" + id + "-popup')\">[X]</a>");
	title = title + buttons;
	var closepopup = function (e) {
		if (!e) { e = window.event; }
		var relTarg = e.relatedTarget || e.toElement;
		if (relTarg && relTarg.id == "vendorStory-26-popup") {
			closePopup("vendorStory-26-popup");
		}
	};
	createPopup(getXYForSelector('#sponsorlinks'), title, "vendorStory-" + id, "Loading", "", closepopup );
	var params = {};
	params.op = 'getTopVendorStory';
	params.skid = id;
	ajax_update(params, "vendorStory-" + id + "-contents");
}

function logToDiv(id, message) {
	$('#'+id).append(message + '<br>');
}


function firehose_open_tab(id) {
	$('#tab-form-'+id).removeClass();
	$('#tab-input-'+id).focus();
	$('#tab-text-'+id).setClass('hide');
}

function firehose_save_tab(id) {
	var	$tab		= $('#fhtab-'+id),
		new_name	= $tab.find('#tab-input-'+id).val(),
		$title		= $tab.find('#tab-text-'+id),
		$saved		= $title.children().remove(); // please ... think of the children
	// let's not wait for a server response to reflect the name-change
	$title.text(new_name).append($saved);

	// XXX: I'm having problems where the server occasionaly refuses,
	//	resets the title, and gives no explanation as to why
	ajax_update({
		op:		'firehose_save_tab',
		tabname:	new_name,
		section:	firehose_settings.section,
		tabid:		id
	}, '',  { onComplete: json_handler });
	$tab.find('#tab-form-'+id).setClass('hide');
	$title.removeClass();
}

// shared modal dialog box and the login box
// #modal_cover and #login_cover are the elements that dim the screen
// TODO: login box really should use the parts from the modal box... no need to duplicate

function cached_parts( expr ){
	// cache jQuery selection objects in the JS object that _is_ this function
	if ( ! cached_parts[expr] ){
		cached_parts[expr] = $(expr).insertBefore('#top_parent');
	}
	return cached_parts[expr];
}

function get_modal_parts( filter ){
	var $parts = cached_parts('#modal_cover, #modal_box');
	if ( filter ) {
		$parts = $parts.filter(filter);
	}
	return $parts;
}
function custom_modal_box( action_name ){
	var	custom_fn_name	= '_custom_' + action_name + '_fn',
		$all_parts	= get_modal_parts(),
		$dialog		= $all_parts.filter('#modal_box'),
		dialog_elem	= $dialog[0],
		fn		= dialog_elem[custom_fn_name] || function(){ $all_parts[action_name](); };
	fn($all_parts);
	delete dialog_elem[custom_fn_name];
	return $all_parts;
}
function show_modal_box(){
	return custom_modal_box('show').
		keyup(function( e ){
			e.which == $.ui.keyCode.ESCAPE && hide_modal_box();
		});
}
function hide_modal_box(){
	// clients may have customized; restore defaults before next use
	return custom_modal_box('hide').
		hide().
		attr('style', 'display: none;').
		removeClass().
		removeData('tabbed').
		unbind();
}

function get_login_parts(){ return cached_parts('#login_cover, #login_box'); }
function show_login_box(){ get_login_parts().show(); }
function hide_login_box(){ get_login_parts().hide(); }

var logged_in = 1;
function check_logged_in(){ return logged_in || (show_login_box(), 0); }


function getModalPrefs(section, title, tabbed, params){
	var $still_open = get_modal_parts('#modal_box:visible');
	$still_open.length && $still_open.data('tabbed')!=tabbed && hide_modal_box();

	if ( !reskey_static ) {
		return show_login_box();
	}

	// .load ensures we are fetching as HTML, and that <script> elements will be executed
	$('#modal_box_content').load(
		'/ajax.pl',
		$.extend({
			op:		'getModalPrefs',
			section:	section,
			reskey:		reskey_static,
			tabbed:		tabbed
		}, params||{}),
		function(){
			$('#preference_title').html(title);
			show_modal_box().data('tabbed', tabbed);
		}
	);
}

function firehose_get_media_popup(id) {
	$('#preference_title').html('Media');
	show_modal_box();
	$('#modal_box_content').html("<h4>Loading...</h4><img src='/images/spinner_large.gif'>");
	ajax_update({
		op:	'firehose_get_media',
		id:	id
	}, 'modal_box_content');
}

function firehose_reinit_updates() {
	fh_is_updating = 0;
	firehose_add_update_timerid(setTimeout(firehose_get_updates, 5000));
}

function firehose_update_failed_modal() {
	$('#preference_title').html('Firehose updates failed');
	$('#modal_box_content').html('Update failed or timed out.  <a href="#" onclick="firehose_reinit_updates();hide_modal_box();">Click to retry</a>');
	show_modal_box();
}

function serialize_multiple( $form ){
	// serialize a form for use in a query, but force all fieldnames to be unique

	// extract the form fields into an array
	var elems = $form.serializeArray();

	// count uses of each fieldname to find those used more than once
	var uses = {};
	$.map(	elems,
		function(el){
			++uses[el.name] || (uses[el.name]=1);
		}
	);

	// return a query string, just as $form.serialize() would, except...
	var salt = 1;
	return $.param(
		$.map(	elems,
			function(el){
				// salt fieldnames used more than once
				if ( uses[el.name] > 1 ) {
					el.name += salt++;
				}
				return el;
			}
		)
	);
}

function resetModalPrefs(extra_param) {
	var params = {
		op:	'saveModalPrefs',
		data: 	serialize_multiple($('#modal_prefs')),
		reset:  1,
		reskey:	reskey_static
	};

	if (extra_param) {
		params[extra_param] = 1;
	}

	ajax_update(params, '', {
		onComplete: function() {
			hide_modal_box();
			document.location=document.URL;
		}
	});
}

function saveModalPrefs() {

	ajax_update({
		op:	'saveModalPrefs',
		data:	serialize_multiple($('#modal_prefs')),
		reskey:	reskey_static
	}, '', {
		onComplete: function() {
			hide_modal_box();
			if (document.forms.modal_prefs.refreshable && document.forms.modal_prefs.refreshable.value) {
				document.location=document.URL;
			}
		}
	});
}

function displayModalPrefHelp(id) {
	var el = $('#'+id);
	el.css('display', el.css('display')!='none' ? 'none' : 'block');
}

function toggle_filter_prefs() {
	$('#filter_play_status, #filter_prefs').toggleClass('hide');
}

function scrollWindowToFirehose(fhid) {
	scrollWindowToId('firehose-'+fhid);
}

function scrollWindowToId(id) {
	var id_y = getOffsetTop($dom(id));
	scroll(viewWindowLeft(), id_y);
}

function viewWindowLeft() {
	if (self.pageXOffset) // all except Explorer
	{
		return self.pageXOffset;
	}
	else if (document.documentElement && document.documentElement.scrollTop)
		// Explorer 6 Strict
	{
		return document.documentElement.scrollLeft;
	}
	else if (document.body) // all other Explorers
	{
		return document.body.scrollLeft;
	}
}

function getOffsetTop (el) {
	if (!el) {
		return false;
	}
	var ot = el.offsetTop;
	while((el = el.offsetParent)) {
		ot += el.offsetTop;
	}
	return ot;
}

function firehoseIsInWindow(fhid) {
	var in_window = isInWindow($dom('firehose-' + fhid));
	return in_window;
}

function isInWindow(obj) {
	var y = getOffsetTop(obj);

	if (y > viewWindowTop() && y < viewWindowBottom()) {
		return 1;
	}
	return 0;
}

function viewWindowTop() {
	if (self.pageYOffset) // all except Explorer
	{
		return self.pageYOffset;
	}
	else if (document.documentElement && document.documentElement.scrollTop)
		// Explorer 6 Strict
	{
		return document.documentElement.scrollTop;
	}
	else if (document.body) // all other Explorers
	{
		return document.body.scrollTop;
	}
	return;
}

function viewWindowBottom() {
	return viewWindowTop() + (window.innerHeight || document.documentElement.clientHeight);
}

function firehose_get_cur() {
	var $current = $('#firehoselist > div.currfh');
	return $current;
}

function firehose_set_cur($article) {
	var $current = firehose_get_cur();
	if ($current.length) {
		$current.removeClass('currfh');
	}

	if (!$article || !$article.length) {
		$article = $('#firehoselist > div[id^=firehose-]:not(.daybreak):first');
	}

	if ($article.length) {
		$article.addClass('currfh');
	}

	return $article;
}

function firehose_go_next() {
	var $current = firehose_get_cur();
	var $next = $current.nextAll('div[id^=firehose-]:not(.daybreak):first');	

	if ($next.length) {
		firehose_set_cur($next);
		firehose_go_scroll($next);
		return $next;
	}
}

function firehose_go_prev() {
	var $current = firehose_get_cur();
	var $prev = $current.prevAll('div[id^=firehose-]:not(.daybreak):first');	

	if ($prev.length) {
		firehose_set_cur($prev);
		firehose_go_scroll($prev);
		return $prev;
	}
}

function firehose_go_scroll($article) {
	var id = $article[0].id.substr(9);
 	if (!firehoseIsInWindow(id)) {
 		scrollWindowToFirehose(id);
 	}
}

function firehose_more(noinc) {
	if (!noinc) {
		firehose_settings.more_num = firehose_settings.more_num + firehose_more_increment;
	}

	if (((firehose_item_count + firehose_more_increment) >= 200) && !fh_is_admin) {
		$('#firehose_more').hide();
	}
	if (firehose_user_class) {
		firehose_set_options('more_num', firehose_settings.more_num);
	} else {
		firehose_get_updates({ oneupdate: 1 });
	}

	inlineAdFirehose();
}

function firehose_highlight_section( $section ){
	$section.addClass('active').siblings().removeClass('active');
}

function on_firehose_select_section( event, data ){
	firehose_highlight_section($('#firehose-sections #fhsection-'+data.id));
	$('#viewsearch').parent().toggleClass('mode-filter', data.id!=='unsaved');
}

function on_firehose_set_options( event, data ){
	if ( !data.select_section ) {
		delete data.id;

		var $next_section;
		$('#firehose-sections li').each(function(){
			var $this=$(this), section=$this.metadata();
			if ( section.filter == data.filter && section.viewname == data.viewname && section.color == data.color ) {
				$next_section = $this;
				data.id = section.id;
				return false;
			}
		});

		if ( !$next_section ) {
			$next_section = the_unsaved_section();
			data = $.extend($next_section.metadata(), data);
			$(document).
				one('update.firehose', function( event, updated ){
					$next_section.find('a span').text(updated.local_time);
				});
		}
	}
	on_firehose_select_section(event, data);
}

$(function(){
	$(document).bind('set-options.firehose', on_firehose_set_options);
});

function the_unsaved_section( dont_create ){
	var	$section_menu	= $('#firehose-sections'),
		$unsaved_item	= $section_menu.find('> #fhsection-unsaved');

	if ( !$unsaved_item.length && !dont_create ) {
		var	$title	= $('<a><i>unsaved</i> <span></span></a>'),
			$edit	= $('<a class="links-sections-edit">[e]</a>');
		$section_menu.prepend(
			$unsaved_item = $('<li id="fhsection-unsaved" />').append($title).append($edit)
		);
		$unsaved_item.metadata().id = 'unsaved';
	}

	return $unsaved_item;
}

function edit_the_unsaved_section(){
	the_unsaved_section('dont-create').each(function(){
		getModalPrefs('firehoseview', 'Save Custom Section', 0, { id: undefined });
	});
}

function save_the_unsaved_section( requested, fn ){
	the_unsaved_section('dont-create').each(function(){
		if ( !requested.name ) {
			return;
		}

		var $unsaved = $(this);
		$unsaved.find('a:first').text(requested.name);

		ajax_update({	op:		'firehose_new_section',
				reskey:		reskey_static,

				name:		requested.name,
				color:		requested.color,
				fhfilter:	requested.filter,
				view_id:	requested.view,

				as_default:	requested.as_default

			}, '', { onComplete: function( transport ){
				var response = eval_response(transport);
				if ( response && response.li ) {
					var	was_active	= $unsaved.is('.active'),
						$saved		= $(response.li),
						md		= $saved.metadata();
					$unsaved.before($saved).remove();
					(was_active && firehose_highlight_section($saved));
					saveFirehoseSectionMenu();
					(fn && fn(response.id));
				}
			}
		});
	});
}


function getSeconds () {
	return new Date().getTime()/1000;
}


// ads!  ads!  ads!
var adTimerSeen   = {};
var adTimerSecs   = 0;
var adTimerClicks = 0;
var adTimerInsert = 0;

function inlineAdReset(id) {
	if (id !== undefined)
		adTimerSeen[id] = 2;
	adTimerSecs   = getSeconds();
	adTimerClicks = 0;
	adTimerInsert = 0;
}


function inlineAdClick(id) {
	//adTimerSeen[id] = adTimerSeen[id] || 1;
	adTimerClicks = adTimerClicks + 1;
}


function inlineAdInsertId(id) {
	if (id !== undefined)
		adTimerInsert = id;
	return adTimerInsert;
}


function inlineAdVisibles() {
	var $visible_ads = $('li.inlinead').filter(function(){ if ( isInWindow(this) ) return this; });
	return $visible_ads.length;
}


function inlineAdCheckTimer(id, url, clickMax, secsMax) {
	if (!url || !id)
		return 0;

	if (adTimerSeen[id] && adTimerSeen[id] == 2)
		return 0;

	// ignore clicks if adTimerClicksMax == 0
	if (clickMax > 0 && !adTimerSeen[id])
		inlineAdClick(id);

	var ad = 0;
	if (clickMax > 0 && adTimerClicks >= clickMax)
		ad = 1;
	else {
		var secs = getSeconds() - adTimerSecs;
		if (secs >= secsMax)
			ad = 1;
	}

	if (!ad)
		return 0;

	return inlineAdInsertId(id);
}

// TODO: remove this jQuery method when integration is complete and this method is really provided by Slash.TagUI
(function($){
$.fn.tag_ui__tags = function(){
	var tags = {};
	this.find('span.tag').each(function(){
		tags[ $(this).text() ] = true;
	});
	return Slash.Util.qw(tags);
}
})(Slash.jQuery);

function inlineAdFirehose($article) {
	if (!fh_adTimerUrl)
		return 0;

	if ($article)
		$article = Slash.Firehose.ready_ad_space($article);
	else
		$article = Slash.Firehose.choose_article_for_next_ad();

	if (!$article || !$article.length)
		return 0;

	var id = $article.article_info__key().key;
	if (!id)
		return 0;

	// we need to remove the existing ad from the hash so it can be re-used
	var old_id = inlineAdInsertId();

	if (! inlineAdCheckTimer(id, fh_adTimerUrl, fh_adTimerClicksMax, fh_adTimerSecsMax))
		return 0;

	if (Slash.Firehose.floating_slashbox_ad.is_visible())
		return 0;

	var $system = $article.find('[context=system]');
	var topic = $system.find('.t2:not(.s1)').tag_ui__tags().join(',');
	var skin  = $system.find('.s1').tag_ui__tags()[0];
	var adUrl = fh_adTimerUrl + '?skin=' + (skin || 'mainpage');
	if (topic)
		adUrl = adUrl + '&topic=' + topic;

	var ad_content = '<iframe src="' + adUrl + '" height="300" width="300" frameborder="0" border="0" scrolling="no" marginwidth="0" marginheight="0"></iframe>';

	Slash.Firehose.floating_slashbox_ad($article, ad_content);

	inlineAdReset(id);
	if (old_id)
		adTimerSeen[old_id] = 0;

	return id;
}


;(function($){

//
// Firehose Floating Slashbox Ad
//


var	AD_HEIGHT = 300, AD_WIDTH = 300,

	$ad_position,		// 300x300 div that holds the current (if any) ad
	ad_target_article,	// the article to which that ad is attached
	$ad_offset_parent,	// the container in which the ad _position_ floats (between articles)
	$slashboxes,		// the container (sort of) in which the ad content actually appears (though not as a child) 
	$footer,

	is_ad_locked;		// ad must be shown for at least 30 seconds

$(function(){
	is_ad_locked = false;
	$ad_position = $([]);
	ad_target_article = null;

	$footer = $('#ft');
	$slashboxes = $('#slashboxes, #userboxes').eq(0);

	$('#firehoselist').
		bind('articlesMoved', fix_ad_position).
		bind('beforeArticleRemoved', notice_article_removed);
});

function notice_article_removed( event, removed_article ){
	if ( ad_target_article === removed_article ) {
		remove_ad();
	}
}

function remove_ad(){
	ad_target_article = null;

	if ( is_ad_locked ) {
		return false;
	}

	$ad_position.remove();
	$ad_position = $([]);
	return true;
}

function insert_ad( $article, ad ){
	if ( !ad || !$article || $article.length != 1 || !remove_ad() ) {
		return;
	}

	ad_target_article = $article[0];
	$ad_position = $article.
		before('<div id="floating-slashbox-ad" class="No" />').
		prev().
			append(ad);

	setTimeout(function(){
		is_ad_locked = false;
		if ( ! ad_target_article ) {
			remove_ad();
		}
	}, 30000);
	is_ad_locked = true;

	if ( ! $ad_offset_parent ) {
		$ad_offset_parent = $article.offsetParent();
	}

	fix_ad_position();
	$ad_position.fadeIn('fast');
}

function topBottomAdSpace(){
	return { top:topBottomAny($slashboxes).bottom, bottom:topAny($footer) };
}

var pinClasses = {};
pinClasses[-1]		= 'Top';	// pinned to the top of the available space, though the natural top is higher
pinClasses[0]		= 'No';		// not pinned
pinClasses[1]		= 'Bottom';	// pinned to the bottom of the available space, though the natural top would be lower
pinClasses[undefined]	= 'Empty';	// not enough room to hold an ad


function fix_ad_position(){
	if ( $ad_position.length ) {
		var space = topBottomAdSpace();
		if ( space.top===undefined || space.bottom===undefined ) {
			return;
		}
		space.bottom-=AD_HEIGHT;

		// the "natural" ad position is top-aligned with the following article
		var natural_top = topAny($ad_position.next());
		if ( natural_top===undefined ) {
			// ...or else top-aligned to the previous bottom, I guess... but wouldn't this mean you're at the end the page?
			natural_top = topBottomAny($ad_position.prev()).bottom;
		}

		var	pinning		= between(space.top, natural_top, space.bottom),
			now_pinned	= pinning !== 0,
			now_empty	= pinning === undefined,
			was_pinned	= $ad_position.is('.Top, .Bottom, .Empty'),
			was_empty	= $ad_position.is('.Empty');

		if ( !was_pinned && !now_pinned || was_empty && now_empty ) {
			return;
		}

		var new_top = '';
		if ( now_pinned && !now_empty ) {
			new_top = pin_between(space.top, natural_top, space.bottom) - topAny($ad_offset_parent);
		}

		$ad_position.
			setClass(pinClasses[pinning]).
			css('top', new_top);
	}
}

function is_ad_visible(){
	if ( $ad_position.length ) {
		var v=intersectBounds(topBottomAny($ad_position), topBottomAny(window));
		return sign( v.bottom-v.top > 0 );
	}
	return 0;
}

Slash.Util.Package({ named: 'Slash.Firehose.floating_slashbox_ad',
	api: {
		is_visible:		is_ad_visible,
		remove:			remove_ad
	},
	stem_function: insert_ad
});

Slash.Firehose.articles_on_screen = function(){
	var	visible = topBottomAny(window),
		lo,	// index within the jQuery selection of the first article visible on the screen
		hi=0;	// index one beyond the last article visible on the screen

	var $articles = $('#firehose > #firehoselist').
		article_info__find_articles().
			filter(':visible').
				// examine articles in order until I _know_ no further articles can be on screen
				each(function(){
					var $this=$(this), this_top=$this.offset().top;
					// hi is the index of this article

					if ( this_top >= visible.bottom ) {
						// ...then this article, and all that follow must be entirely below the screen
						// the last article on screen (if any) must be the previous one (at hi-1)
						return false;
					}

					// until we find the first on-screen article...
					if ( lo === undefined ) {
						var this_bottom = this_top + $this.height();

						// we know this_top is above visible.bottom, so...
						if ( this_bottom > visible.top ) {
							// ...then _this_ article must be (the first) on screen
							lo = hi;
						}

						if ( this_bottom >= visible.bottom ) {
							// ...then we must be the _only_ article on screen
							++hi; // starting one past this article, everything is below the screen
							return false;
						}
					}
					++hi;
				});

	if ( lo === undefined ) {
		return $([]);
	} else if ( lo===0 && hi==$articles.length ) {
		return $articles;
	} else {
		return $(Array.prototype.slice.call($articles, lo, hi));
	}
}

// filter $articles to only those adjacent to available space for an ad
// return empty list if none, or if not enough time has yet passed to place a new ad
Slash.Firehose.ready_ad_space = function( $articles ){
	var $result = $([]);
	try {
		if ( !is_ad_locked ) {
			var y = intersectBounds(topBottomAdSpace(), topBottomAny(window));
			y.bottom -= AD_HEIGHT;

			$result = $articles.filter(function(){
				return between(y.top, topAny(this), y.bottom)==0;
			});
		}
	} catch ( e ) {
		// don't throw
	}
		// just tell the caller no articles supplied are at or below ad-space
	return $result;
}

Slash.Firehose.choose_article_for_next_ad = function(){
	var Fh=Slash.Firehose, $articles=Fh.ready_ad_space(Fh.articles_on_screen());
	return $articles.eq( Math.floor(Math.random()*$articles.length) );
}

})(Slash.jQuery);

$(function(){
	// firehose only!
	var validkeys = {};
	if (window.location.href.match(/\b(?:firehose|index2|console)\.pl\b/)) {
		validkeys = {
			'X' : {           tags    : 1, signoff : 1 },
			'Z' : {           tags    : 1, tag     : 1 },
			187 : { chr: '+', tags    : 1, tag     : 1, nod    : 1 }, // 61, 107
			189 : { chr: '-', tags    : 1, tag     : 1, nix    : 1 }, // 109

//			219 : { chr: '[', color   : 1, down    : 1 },
//			221 : { chr: ']', color   : 1, up      : 1 },

//			'T' : {           top     : 1 },
//			'V' : {           bottom  : 1 },
			'G' : {           more    : 1 },
			'Q' : {           toggle  : 1 },
			'S' : {           next    : 1 },
			'W' : {           prev    : 1 },

			27  : { form: 1,  unfocus : 1 } // esc
		};
		validkeys['H'] = validkeys['A'] = validkeys['K'] = validkeys['W'];
		validkeys['L'] = validkeys['D'] = validkeys['J'] = validkeys['S'];
		validkeys[107] = validkeys[61] = validkeys[187];
		validkeys[109] = validkeys[189];
	}

	$(document).keyup(function( e ) {
		var c    = e.which;
		var key  = validkeys[c] ? c : String.fromCharCode(c);
		var keyo = validkeys[key];

		if (!keyo)
			return true;

		// if keyo.form, only work on form elements; if not, then
		// never work on form elements.
		// "type" should handle all our cases here.
		if (!keyo.form && e.target && e.target.type)
			return true;
		if (keyo.form && (!e.target || !e.target.type))
			return true;

		var el = firehose_get_cur()[0];
		var id = el.id.substr(9);
		if (keyo.tags) {
			if (keyo.signoff) { el.submit_tags('signoff') }
			if (keyo.nod)     { el.submit_tags('nod')     }
			if (keyo.nix)     { el.submit_tags('nix')     }
			if (keyo.tag)     {
				toggle_firehose_body(id, 0, true);
				firehose_toggle_tag_ui_to(true, el);
				$('.tag-entry:visible:first', el).focus();
			}
			firehose_set_cur($(el));

		} else {
			if (keyo.unfocus)  { $(e.target).blur() }
			if (keyo.next)     { firehose_go_next() }
			if (keyo.prev)     { firehose_go_prev() }
			if (keyo.more)     { firehose_more()    }
			if (keyo.toggle)   { toggle_firehose_body(id, 0) }
		}

		return false;
	});
});

