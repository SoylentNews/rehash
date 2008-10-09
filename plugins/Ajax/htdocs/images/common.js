// _*_ Mode: JavaScript; tab-width: 8; indent-tabs-mode: true _*_
; // $Id$

/*global setFirehoseAction firehose_get_updates tagsHideBody tagsShowBody attachCompleter createTag
	firehose_remove_all_items firehose_fix_up_down firehose_toggle_tag_ui_to ajax_update json_handler
	json_update firehose_reorder firehose_get_next_updates getFirehoseUpdateInterval run_before_update
	firehose_play firehose_add_update_timerid firehose_collapse_entry firehose_slider_end
	firehose_slider_set_color vendorStoryPopup vendorStoryPopup2 firehose_save_tab check_logged_in
	scrollWindowToFirehose scrollWindowToId viewWindowLeft getOffsetTop firehoseIsInWindow
	isInWindow viewWindowTop viewWindowBottom firehose_set_cur firehose_get_onscreen */

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

  firehose_settings.issue = '';
  firehose_settings.is_embedded = 0;
  firehose_settings.not_id = 0;
  firehose_settings.section = 0;
  firehose_settings.more_num = 0;
  firehose_settings.metamod = 0;

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

  var firehose_cur = 0;

// globals we haven't yet decided to move into |firehose_settings|
var fh_play = 0;
var fh_is_timed_out = 0;
var fh_is_updating = 0;
var fh_update_timerids = [];
var fh_is_admin = 0;
var console_updating = 0;
var fh_colorslider;
var fh_ticksize;
var fh_colors = [];
var fh_idle_skin = 0;
var vendor_popup_timerids = [];
var vendor_popup_id = 0;
var fh_slider_init_set = 0;
var ua=navigator.userAgent;
var is_ie = ua.match("/MSIE/");

// ads
var fh_adTimerSecsMax   = 15;
var fh_adTimerClicksMax = 0;
var fh_adTimerUrl       = '';
adTimerUrl = '/images/iframe/firehose.html'; // testing


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

function article_moved( article ){
	var data = article ? $(article).nextAll(':visible').andSelf() : null;
	$('#firehoselist').trigger('articlesMoved', data);
}

function article_removed( article ){
	var next_article = article ? $(article).next(':visible')[0] : null;
	article_moved(next_article);
}

function firehose_toggle_advpref() {
	$('#fh_advprefs').toggleClass('hide');
}

function firehose_open_prefs() {
	$('#fh_advprefs').removeClass();
}

function toggleId(id, c1, c2) {
	$('#'+id).toggleClasses(c1, c2, c1);
}

function toggleIntro(id, toggleid) {
	var new_class = 'condensed';
	var new_html = '[+]';
	if ( $('#'+id).toggleClasses('introhide', 'intro').hasClass('intro') ) {
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
	article_moved($('#firehose-'+id)[0]);
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
	article_moved($('#firehose-'+id)[0]);
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
function toggle_firehose_body(id, is_admin) {
	var params = {};
	setFirehoseAction();
	params.op = 'firehose_fetch_text';
	params.id = id;
	var fhbody = $dom('fhbody-'+id);
	var fh = $dom('firehose-'+id);

	var usertype = fh_is_admin ? " adminmode" : " usermode";
	if (fhbody.className == "empty") {
		var handlers = {
			onComplete: function() {
				if(firehoseIsInWindow(id)) {
					scrollWindowToFirehose(id);
				}
				firehose_get_admin_extras(id);
			}
		};
		params.reskey = reskey_static;
		ajax_update(params, 'fhbody-'+id, is_admin ? handlers : null);
		fhbody.className = "body";
		fh.className = "article" + usertype;
		if (is_admin) {
			firehose_toggle_tag_ui_to(true, fh);
		}
	} else if (fhbody.className == "body") {
		fhbody.className = "hide";
		fh.className = "briefarticle" + usertype;
		/*if (is_admin)
			tagsHideBody(id);*/
	} else if (fhbody.className == "hide") {
		fhbody.className = "body";
		fh.className = "article" + usertype;
		if (is_admin) {
			firehose_toggle_tag_ui_to(true, fh);
		}
		/*if (is_admin)
			tagsShowBody(id, is_admin, '', "firehose"); */
	}
	article_moved(fh);
	return false;
}

function toggleFirehoseTagbox(id) {
	$('#fhtagbox-'+id).toggleClasses('tagbox', 'hide');
	article_moved($('#firehose-'+id)[0]);
}

function firehose_set_options(name, value) {
	if (firehose_user_class === 0) {
		return;
	}
	if (name == "color" && value === undefined) {
		return;
	}

	var pairs = [
		// name		value		curid		newid		newvalue 	title
		["orderby", 	"createtime", 	"popularity",	"time",		"popularity"	],
		["orderby", 	"popularity", 	"time",		"popularity",	"createtime"	],
		["orderdir", 	"ASC", 		"asc",		"desc",		"DESC"],
		["orderdir", 	"DESC", 	"desc",		"asc",		"ASC"],
		["mode", 	"full", 	"abbrev",	"full",		"fulltitle"],
		["mode", 	"fulltitle", 	"full",		"abbrev",	"full"]
	];
	var params = {};
	params.setting_name = name;
	params.op = 'firehose_set_options';
	params.reskey = reskey_static;
	var theForm = document.forms.firehoseform;
	if (name == "firehose_usermode") {
		value = value ? 1 : 0;
		params.setusermode = 1;
		params[name] = value;
	}

	if (name == "nodates" || name == "nobylines" || name == "nothumbs" || name == "nocolors" || name == "mixedmode" || name == "nocommentcnt" || name == "nomarquee" || name == "noslashboxes") {
		value = value ? 1 : 0;
		params[name] = value;
		params.setfield = 1;
		var classname;
		if (name == "nodates") {
			classname = "date";
		} else if (name == "nobylines") {
			classname = "nickname";
		}

		if (classname) {
			$('#firehoselist .'+classname).setClass(classname + value ? ' hide' : '');
		}
	}

	if (name == "fhfilter" && theForm) {
		for (i=0; i< theForm.elements.length; i++) {
			if (theForm.elements[i].name == "fhfilter") {
				firehose_settings.fhfilter = theForm.elements[i].value;
			}
		}
		firehose_settings.page = 0;
		firehose_settings.more_num = 0;
	}

	if (name == "setfhfilter") {
		firehose_settings.fhfilter = value;
		firehose_settings.page = 0;
		firehose_settings.more_num = 0;
	}

	if (name != "color") {
	for (i=0; i< pairs.length; i++) {
		var el = pairs[i];
		if (name == el[0] && value == el[1]) {
			firehose_settings[name] = value;
			var $ctrl = $('#'+el[2]);
			if ( $ctrl.length ) {
				$ctrl.attr('id', el[3]);
				var namenew = el[0], valuenew = el[4];
				$ctrl.children().eq(0).click(function(){
					firehose_set_options(namenew, valuenew);
					return false;
				});
			}
		}
	}
	if (name == "mode" || name == "firehose_usermode" || name == "tab" || name == "mixedmode" || name == "nocolors" || name == "nothumbs") {
		// blur out then remove items
		if (name == "mode") {
			fh_view_mode = value;
		}
		if ($dom('firehoselist')) {
			// set page
			page = 0;

			if (!is_ie) {
				var attributes = {
					opacity: { from: 1, to: 0 }
				};
				var myAnim = new YAHOO.util.Anim("firehoselist", attributes);
				myAnim.duration = 1;
				myAnim.onComplete.subscribe(function() {
					$dom('firehoselist').style.opacity = "1";
				});
				myAnim.animate();
			}
			// remove elements
			firehose_remove_all_items();
		}
	}
	}

	if (name == "color" || name == "tab" || name == "pause" || name == "startdate" || name == "duration" || name == "issue" || name == "pagesize") {
		params[name] = value;
		if (name == "startdate") {
			firehose_settings.startdate = value;
		}
		if (name == "duration")  {
			firehose_settings.duration = value;
		}
		if (name == "issue") {
			firehose_settings.issue = value;
			firehose_settings.startdate = value;
			firehose_settings.duration = 1;
			firehose_settings.page = 0;
			firehose_settings.more_num = 0;
			var issuedate = firehose_settings.issue.substr(5,2) + "/" + firehose_settings.issue.substr(8,2) + "/" + firehose_settings.issue.substr(10,2);

			$('#fhcalendar, #fhcalendar_pag').each(function(){
				this._widget.setDate(issuedate, "day");
			});
		}
		if (name == "color") {
			firehose_settings.color = value;
		}
		if (name == "pagesize") {
			firehose_settings.page = 0;
			firehose_settings.more_num = 0;
		}
	}

	var handlers = {
		onComplete: function(transport) {
			json_handler(transport);
			firehose_get_updates({ oneupdate: 1 });
		}
	};

	if (name == 'tabsection') {
		firehose_settings.section = value;
		params.tabtype = 'tabsection';
	}

	if (name == 'tabtype') {
		params.tabtype = value;
	}

	if (name == 'more_num') {
		params.ask_more = 1;
	}

	params.section = firehose_settings.section;
	$.extend(params, firehose_settings);
	ajax_update(params, '', handlers);
}

function firehose_remove_all_items() {
	$('#firehoselist').empty();
	article_moved();
}


function firehose_up_down(id, dir, type) {
	if (!check_logged_in()) { return; }

	setFirehoseAction();
	var meta = 0;
	if (type && type == "comment") {
		meta = 1;
	}
	ajax_update({
		op:	'firehose_up_down',
		id:	id,
		reskey:	reskey_static,
		dir:	dir,
		meta:	meta
	}, '', { onComplete: json_handler });


	// We changed the tags outside the notice of the tag widget (if any).
	// If there is one, we need to tell it.  Look for the tag widget.
	var new_context = {'+':'nod', '-':'nix'}[dir];
	var found_widgets = 0;

	var $server = $('#firehoselist > [tag-server='+id+']');
	$server.find('.tag-widget').
			each(function(){
				++found_widgets;
				this.set_context(new_context);
			});

	if ( found_widgets ) {
		$server[0].fetch_tags();
	} else {
		// No tag widget; we have to call directly...
		firehose_fix_up_down(id, {'+':'votedup', '-':'voteddown'}[dir]);
	}
}

function firehose_fix_up_down(id, new_state) {
	// Find the (possibly) affected +/- capsule.
	var $updown = $('#updown-'+id);

	if ( $updown.length && ! $updown.hasClass(new_state) ) {
		// We found the capsule, and it's state needs to be fixed.
		$updown.setClass(new_state);
	}
}

function firehose_click_nodnix_reason( event ) {
	var $entry = $(event.target).nearest_parent('[tag-server]');
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
	var	$server = $(selector).nearest_parent('[tag-server]'),
		id	= $server.attr('tag-server'),
		$widget = $server.find('.tag-widget.body-widget'),
		toggle	= if_expanded != $widget.hasClass('expanded');

	if ( toggle ) {
		setFirehoseAction();
		$server.find('.tag-widget').each(function(){ this.set_context(); });

		$widget.toggleClassTo('expanded', if_expanded);

		var toggle_button={}, toggle_div={};
		if ( if_expanded ){
			$server.each(function(){ this.fetch_tags(); });
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
		$server.find('#toggletags-body-'+id).mapClass(toggle_div);
		article_moved($server[0]);
	}

	return $widget;
}

function firehose_toggle_tag_ui( toggle ) {
	firehose_toggle_tag_ui_to( ! $(toggle.parentNode).hasClass('expanded'), toggle );
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
	} else if ( ($menu = $target.nearest_parent('.tmenu')).length ) {
		var op = $target.text();
		var $tag = $target.nearest_parent(':has(span.tag)').find('.tag');
		$related_trigger = $tag;

		var tag = $tag.text();
		command = normalize_tag_menu_command(tag, op);
	} else {
		$related_trigger = $().filter();
	}

	if ( command ) {
		// No!  You no hurt Dr. Jones!  You log-in first!
		if ( ! check_logged_in() ) {
			return false;
		}

		var $server = $target.nearest_parent('[tag-server]');

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


function tag_ui_init_new_articles(){
	if ( $('#firehose').length ) {
		return firehose_init_tag_ui();
	}

	var $new_articles = $(document).article_info__find_articles(':not(:has(span.sd-info-block .tag-ui))');
	$new_articles.
		click(firehose_click_tag).
		each(function(){
			install_tag_server(this);
			this.command_pipeline.push(firehose_handle_context_triggers);
		});
	$init_tag_widgets($new_articles.find('.tag-widget-stub'));
	init_tag_ui_styles($new_articles);
	$new_articles.article_info('tag-ui', true);
	return $new_articles;
}

$(function(){
	tag_ui_init_new_articles();
});


function firehose_init_tag_ui( $new_entries ){
	if ( ! $new_entries || ! $new_entries.length ) {
		var $firehoselist = $('#firehoselist');
		if ( $firehoselist.length ) {
			$new_entries = $firehoselist.children('[id^=firehose-][class*=article]');
		} else {
			$new_entries = $('[id^=firehose-][class*=article]');
		}
	}

	$new_entries = $new_entries.filter(':not([tag-server])');

	$new_entries.
		each(function(){
			var $this = $(this), id = firehose_id_of(this);

			install_tag_server(this, id);

			if ( fh_is_admin ) {
				this.command_pipeline.push(firehose_handle_admin_commands);
			}

			this.command_pipeline.push(
				firehose_handle_context_triggers,
				($this.attr('type') == 'comment') ?
					firehose_handle_comment_nodnix :
					firehose_handle_nodnix );

			$this.
				find('.title').
					append('<div class="tag-widget-stub nod-nix-reasons" init="context_timeout:15000">' +
							'<div class="tag-display-stub" context="related" init="legend:\'why\', menu:false" />' +
						'</div>').
					find('.tag-display-stub').
						click(firehose_click_nodnix_reason);
		});

	var $widgets = $init_tag_widgets($new_entries.find('.tag-widget-stub'));

	if ( fh_is_admin ) {
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
	json_update(response);
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

	if (response.html) {
		var new_content = response.html;
		for (id in new_content) {
			if ( new_content.hasOwnProperty(id) ) {
				$('#'+id).html(new_content[id]);
			}
		}

	}

	if (response.value) {
		var new_value = response.value;
		for (id in new_value) {
			if ( new_value.hasOwnProperty(id) ) {
				var elem = $dom(id);
				if ( elem !== gFocusedText ) {
					$(elem).val(new_value[id]);
				}
			}
		}
	}

	if (response.html_append) {
		new_content = response.html_append;
		for (id in new_content) {
			if ( new_content.hasOwnProperty(id) ) {
				$('#'+id).each(function(){
					this.innerHTML += new_content[id];
				});
			}
		}
	}

	if (response.html_append_substr) {
		new_content = response.html_append_substr;
		for (id in new_content) {
			if ( new_content.hasOwnProperty(id) ) {
				var $found = $('#'+id);
				if ($found.size()) {
					var existing_content = $found.html();
					var pos = existing_content.search(/<span class="?substr"?> ?<\/span>[\s\S]*$/i);
					if ( pos != -1 ) {
						existing_content = existing_content.substr(0, pos);
					}
					$found.html(existing_content + new_content[id]);
				}
			}
		}
	}

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
	var $menu = $('.ac_results:visible');

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
				$('#firehose-' + firehose_after[el[1]]).before(el[2]);
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
					article_moved(fh_node);
					fh_node.style.height = "";
					if (fh_idle_skin) {
						$("h3 a[class!='skin']", fh_node).click(function(){
							var h3 = $(this).parent('h3');
							h3.next('div.hid').and(h3.find('a img')).toggle("fast");
							return false;
						});
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

				if ((firehose_removals < 10 ) || !need_animate) {
					myAnim.onComplete.subscribe(function() {
						var elem = this.getEl();
						if (elem && elem.parentNode) {
							article_removed(elem);
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
		if(!need_animate) {
			wait_interval = 10;
		}
		setTimeout(firehose_handle_update, wait_interval);
	} else {
		firehose_reorder();
		inlineAdFirehose();
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

function firehose_reorder() {
	if (firehose_ordered) {
		var fhlist = $('#firehoselist');
		if (fhlist) {
			firehose_item_count = firehose_ordered.length;
			var moved = false;
			for (i = 0; i < firehose_ordered.length; ++i) {
				if (!/^\d+$/.test(firehose_ordered[i])) {
					--firehose_item_count;
				}
				if ( $('#firehose-'+firehose_ordered[i]).appendTo(fhlist).length ) {
					moved = true;
				}
				if ( firehose_future[firehose_ordered[i]] ) {
					$('#ttype-'+firehose_ordered[i]).setClass('future');
				} else {
					$('#ttype-'+firehose_ordered[i]+'.future').setClass('story');
				}
			}
			if ( moved ) article_moved();
			var newtitle = document.title;
			if (/\(\d+\)/.test(newtitle)) {
				newtitle = newtitle.replace(/(\(\d+\))/,"(" + firehose_item_count + ")");
			} else {
				newtitle = newtitle + " (" + firehose_item_count + ")";
			}
			document.title = newtitle;
		}
	}

}

function firehose_get_next_updates() {
	var interval = getFirehoseUpdateInterval();
	//alert("fh_get_next_updates");
	fh_is_updating = 0;
	firehose_add_update_timerid(setTimeout(firehose_get_updates, interval));
}

function firehose_get_updates_handler(transport) {
	$('.busy').hide();
	var response = eval_response(transport);

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
	if (response.html) {
		json_update(response);
		processed = processed + 1;
	}
	if (response.updates) {
		firehose_updates = response.updates;
		firehose_updates_size = firehose_updates.length;
		firehose_removed_first = 0;
		processed = processed + 1;
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

	for (i in firehose_settings) {
		if ( firehose_settings.hasOwnProperty(i) ) {
			params[i] = firehose_settings[i];
		}
	}

	$('.busy').show();
	ajax_update(params, '', { onComplete: firehose_get_updates_handler });
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
		$('#message_area').html("Automatic updates have been slowed due to inactivity");
		//firehose_pause();
	}
}

function firehose_play() {
	fh_play = 1;
	setFirehoseAction();
	firehose_set_options('pause', '0');
	$('#message_area').html('');
	$('#pauseorplay').html('Updated');
	$('#play').setClass('hide');
	$('#pause').setClass('show');
}

function is_firehose_playing() {
  return fh_play==1;
}

function firehose_pause() {
	fh_play = 0;
	$('#pause').setClass('hide');
	$('#play').setClass('show');
	$('#pauseorplay').html('Paused');
	firehose_set_options('pause', '1');
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
	var fh = $dom('firehose-' + id);
	if (fh) {
		var attributes = {
			height: { to: 0 }
		};
		if (!is_ie) {
			attributes.opacity = { to: 0 };
		}
		var myAnim = new YAHOO.util.Anim(fh, attributes);
		myAnim.duration = 0.5;
		myAnim.onComplete.subscribe(function() {
			var el = this.getEl();
			article_moved(el);
			el.parentNode.removeChild(el);
		});
		myAnim.animate();
	}
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

function firehose_slider_init() {
	if (!fh_slider_init_set) {
		fh_colorslider = YAHOO.widget.Slider.getHorizSlider("colorsliderbg", "colorsliderthumb", 0, 105, fh_ticksize);
		var fh_set_val_return = fh_colorslider.setValue(fh_ticksize * fh_colors_hash[fh_color] , 1);
		var fh_get_val_return = fh_colorslider.getValue();
		fh_colorslider.subscribe("slideEnd", firehose_slider_end);
	}
}

function firehose_slider_end(offsetFromStart) {
	var newVal = Math.round(fh_colorslider.getValue());
	if (newVal) {
		fh_slider_init_set = 1;
	}
	var color = fh_colors[ newVal / fh_ticksize ];
	if (color !== undefined) {
		$dom('fh_slider_img').title = "Firehose filtered to " + color;
		if (fh_slider_init_set) {
			firehose_set_options("color", color);
		}
	} else if (firehohse_settings.color !== undefined) {
		firehose_slider_set_color(firehose_settings.color);
	}
}

function firehose_slider_set_color(color) {
	fh_colorslider.setValue(fh_ticksize * fh_colors_hash[color] , 1);
}

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
	$dom('tab-input-'+id).focus();
	$('#tab-text-'+id).setClass('hide');
}

function firehose_save_tab(id) {
	ajax_update({
		op:		'firehose_save_tab',
		tabname:	$('#tab-input-'+id).val(),
		section:	firehose_settings.section,
		tabid:		id
	}, '',  { onComplete: json_handler });
	$('#tab-form-'+id).setClass('hide');
	$('#tab-text-'+id).removeClass();
}
var logged_in   = 1;
var login_cover = 0;
var login_box   = 0;
var login_inst  = 0;

function init_login_divs() {
	login_cover = $dom('login_cover');
	login_box   = $dom('login_box');
}

function install_login() {
	if (login_inst) {
		return;
	}

	if (!login_cover || !login_box) {
		init_login_divs();
	}

	if (!login_cover || !login_box) {
		return;
	}

	login_cover.parentNode.removeChild(login_cover);
	login_box.parentNode.removeChild(login_box);

	var top_parent = document.getElementById('top_parent');
	top_parent.parentNode.insertBefore(login_cover, top_parent);
	top_parent.parentNode.insertBefore(login_box, top_parent);
	login_inst = 1;
}

function show_login_box() {
	if (!login_inst) {
		install_login();
	}

	if (login_cover && login_box) {
		login_cover.style.display = '';
		login_box.style.display = '';
	}

	return;
}

function hide_login_box() {
	if (!login_inst) {
		install_login();
	}

	if (login_cover && login_box) {
		login_box.style.display = 'none';
		login_cover.style.display = 'none';
	}

	return;
}

function check_logged_in() {
	if (!logged_in) {
		show_login_box();
		return 0;
	}
	return 1;
}
var modal_cover = 0;
var modal_box   = 0;
var modal_inst  = 0;

function init_modal_divs() {
	modal_cover = $dom('modal_cover');
	modal_box   = $dom('modal_box');
}

function install_modal() {
	if (modal_inst) {
		return;
	}

	if (!modal_cover || !modal_box) {
		init_modal_divs();
	}

	if (!modal_cover || !modal_box) {
		return;
	}

	modal_cover.parentNode.removeChild(modal_cover);
	modal_box.parentNode.removeChild(modal_box);

	var modal_parent = $dom('top_parent');
	modal_parent.parentNode.insertBefore(modal_cover, modal_parent);
	modal_parent.parentNode.insertBefore(modal_box, modal_parent);
	modal_inst = 1;
}

function show_modal_box() {
	if (!modal_inst) {
		install_modal();
	}

	if (modal_cover && modal_box) {
		modal_cover.style.display = '';
		modal_box.style.display = '';
	}

	return;
}

function hide_modal_box() {
	if (!modal_inst) {
		install_modal();
	}

	if (modal_cover && modal_box) {
		modal_box.style.display = 'none';
		modal_cover.style.display = 'none';
	}

	return;
}

function getModalPrefs(section, title, tabbed) {
	if (!reskey_static) {
		return show_login_box();
	}
	$('#preference_title').html(title);
	ajax_update({
		op:		'getModalPrefs',
		section:	section,
		reskey:		reskey_static,
		tabbed:		tabbed
	}, 'modal_box_content', { onComplete: show_modal_box });
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

function saveModalPrefs() {
	var params = {};
	params.op = 'saveModalPrefs';
	params.data = jQuery("#modal_prefs").serialize();
	params.reskey = reskey_static;
	var handlers = {
		onComplete: function() {
			hide_modal_box();
			if (document.forms.modal_prefs.refreshable.value) {
				document.location=document.URL;
			}
		}
	};
	ajax_update(params, '', handlers);
}

function displayModalPrefHelp(id) {
	var el = $('#'+id);
	el.css('display', el.css('display')!='none' ? 'none' : 'block');
}

function toggle_filter_prefs() {
	var fps = $dom('filter_play_status');
	var fp  = $dom('filter_prefs');
	if (fps) {
		if (fps.className === "") {
			fps.className = "hide";
			if (fp) {
				fp.className = "";
				setTimeout(firehose_slider_init,500);
			}
		} else if (fps.className == "hide") {
			fps.className = "";
			if (fp) {
				fp.className = "hide";
			}
		}
	}

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

function firehoseIsInWindow(fhid, just_head) {
	var in_window = isInWindow($('firehose-' + fhid));
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
	if (!firehose_cur) {
		firehose_cur = firehose_ordered[0];
		firehose_set_cur(firehose_cur);
	}
	return firehose_cur;
}

function firehose_set_cur(id) {
	firehose_cur = id;
}

function firehose_get_pos_of_id(id) {
	var ret;
	for (var i=0; i< firehose_ordered.length; i++) {
		if (firehose_ordered[i] == id) {
			ret = i;
		}
	}
	return ret;
}

function firehose_go_next() {
	var cur = firehose_get_cur();
	var pos = firehose_get_pos_of_id(cur);
	if (pos < (firehose_ordered.length - 1)) {
		pos++;
	} else {
	}
	firehose_set_cur(firehose_ordered[pos]);
	scrollWindowToFirehose(firehose_cur);
}

function firehose_go_prev() {
	var cur = firehose_get_cur();
	var pos = firehose_get_pos_of_id(cur);
	if (pos>0) {
		pos--;
	}
	firehose_set_cur(firehose_ordered[pos]);
	scrollWindowToFirehose(firehose_cur);

}

function firehose_more() {
	firehose_settings.more_num = firehose_settings.more_num + firehose_more_increment;

	if (((firehose_item_count + firehose_more_increment) >= 200) && !fh_is_admin) {
		$('#firehose_more').hide();
	}
	if (firehose_user_class) {
		firehose_set_options('more_num', firehose_settings.more_num);
	} else {
		firehose_get_updates({ oneupdate: 1 });
	}
}

function firehose_get_onscreen() {
	var onscreen = [];
	$('#firehoselist').children().each(function() { if(isInWindow(this)){ onscreen.push(this.id);} });
	return onscreen;
}


function getSeconds () {
	return new Date().getTime()/1000;
}


// ads!  ads!  ads!
var adTimerSeen   = {};
var adTimerSecs   = 0;
var adTimerClicks = 0;
var adTimerInsert = 0;
var adTimerUrl    = '/images/iframe/firehose.html';

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
	var $visible_ads = $('.inlinead').filter(function(){ if ( isInWindow(this) ) return this; });
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


function inlineAdFirehose() {
	if (!fh_is_admin)
		return 0; // testing

	var $article = Slash.Firehose.choose_article_for_next_ad();
	var id = $article.article_info__key().key;
	if (!id)
		return 0;

	// we need to remove the existing ad from the hash so it can be re-used
	var old_id = inlineAdInsertId();

	if (! inlineAdCheckTimer(id, fh_adTimerUrl, fh_adTimerClicksMax, fh_adTimerSecsMax))
		return 0;

	// XXX after N seconds we still want to replace this ad
	if (Slash.Firehose.floating_slashbox_ad.is_visible())
		return 0;

	var $system = $article.find('[context=system]');
	var topic = $system.find('.t2:not(.s1)').tag_ui__tags().join(',');
	var skin  = $system.find('.s1').tag_ui__tags()[0];
	var adUrl = adBaseUrl + '?skin=' + (skin || 'mainpage');
	if (topic)
		adUrl = adUrl + '&topic=' + topic;

	var ad_content = '<iframe src="' + adUrl + '" height="300" width="300" frameborder="0" border="0" scrolling="no" marginwidth="0" marginheight="0"></iframe>';

	Slash.Firehose.floating_slashbox_ad(ad_content, $article);

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

	current_mode = { has_content: false },
	$ad_position,		// 300x300 div that holds the current (if any) ad
	$current_article,	// the article to which that ad is attached
	$slashboxes;		// the container in which the ad floats

$(function(){
	var $firehose = $('#firehose');
	$slashboxes = $firehose.find('> #slashboxes').
		append('<div id="floating-slashbox-ad" style="display:none; position:absolute; height:'+AD_HEIGHT+'px; width:'+AD_WIDTH+'px;" />');
	$ad_position = $slashboxes.find('#floating-slashbox-ad');

	$(window).scroll(fix_ad_position);
	$('#firehoselist').bind('articlesMoved', fix_ad_position);
});

function if_same_mode( a, b ){
	return	(!a.has_content && !b.has_content) ||
		(
			(a.has_content == b.has_content) &&
			(a.is_in_window == b.is_in_window) &&
			(a.top == b.top) &&
			(a.pinned == b.pinned)
		);
}

function set_mode( next ){
	var cur = current_mode;

	if ( ! if_same_mode(cur, next) ) {
		if ( next.has_content ) {
			if ( cur.has_content && (next.is_in_window || cur.is_in_window) ) {
				$ad_position.animate({top: next.top}, 'fast');
			} else {
				$ad_position.hide().css({top: next.top});
				if ( !cur.has_content ) {
					$ad_position.fadeIn('fast');
				} else {
					$ad_position.show();
				}
			}
		} else {
			$ad_position.hide();
		}

		var event_name;
		if ( cur.has_content != next.has_content ) {
			event_name = next.has_content ? 'adInserted' : 'adRemoved';
		} else if ( cur.pinned != next.pinned ) {
			event_name = 'adPinnedTo' + next.pinned;
		} else if ( cur.is_in_window != next.is_in_window ) {
			event_name = next.is_in_window ? 'adMovedIntoWindow' : 'adMovedOutOfWindow';
		} else if ( cur.top != next.top ) {
			event_name = 'adMoved';
		}

		current_mode = next;

		if ( event_name ) {
			$ad_position.trigger(event_name);
		}
	}
}

function remove_current_ad(){
	if ( current_mode.has_content ) {
		set_mode({ has_content: false });
		$ad_position.empty();
		$current_article = null;
	}
}

function set_current_ad( ad_content, $article ){
	if ( ad_content && $article && $article.length==1 ) {
		remove_current_ad();
		current_mode.will_have_content = true;
		$current_article = $article;
		$ad_position.append(ad_content);
		fix_ad_position();
	}
}

function fix_ad_position(){
	if ( current_mode.has_content || current_mode.will_have_content ) {
		var	$footer		= $('#firehose > #fh-pag-div'),
			space_top	= $slashboxes.offset().top + $slashboxes.height(),
			space_bottom	= $footer.offset().top + $footer.height(),
			article_top	= $current_article.offset().top,
			window_top	= window.pageYOffset,
			window_bottom	= window_top + window.innerHeight,
			ad_top		= Math.max(space_top, Math.min(article_top, space_bottom-AD_HEIGHT)),
			next_mode	= {	has_content:	true,
						is_in_window:	!( ad_top > window_bottom || ad_top + AD_HEIGHT < window_top ),
						top:		ad_top - $slashboxes.offset().top
					};

		if ( ad_top == article_top ) {
			next_mode.pinned = 'Article';
		} else if ( ad_top < article_top ) {
			next_mode.pinned = 'Bottom';
		} else if ( ad_top > (article_top + $current_article.height()) ) {
			next_mode.pinned = 'TopDisconnected';
		} else {
			next_mode.pinned = 'Top';
		}

		set_mode(next_mode);
	}
}


Slash.Util.Package({ named: 'Slash.Firehose.floating_slashbox_ad',
	api: {
		is_visible:		function(){ return current_mode.has_content && current_mode.is_in_window; },
		remove:			remove_current_ad,
		current_article:	function(){ return $current_article; },
		is_pinned_to:		function(){ return current_mode.pinned; },
		bind:			function(){ return $ad_position.bind.apply($ad_position, arguments); },
		unbind:			function(){ return $ad_position.unbind.apply($ad_position, arguments); }
	},
	stem_function: set_current_ad
});

Slash.Firehose.articles_on_screen = function(){
	var	window_top = window.pageYOffset,
		window_bottom = window_top + window.innerHeight,
		lo,	// index within the jQuery selection of the first article visible on the screen
		hi=0;	// index one beyond the last article visible on the screen

	var $articles = $('#firehose > #firehoselist').
		article_info__find_articles().
			filter(':visible').
				// examine articles in order until I _know_ no further articles can be on screen
				each(function(){
					var $this=$(this), this_top=$this.offset().top;
					// hi is the index of this article

					if ( this_top >= window_bottom ) {
						// ...then this article, and all that follow must be entirely below the screen
						// the last article on screen (if any) must be the previous one (at hi-1)
						return false;
					}

					// until we find the first on-screen article...
					if ( lo === undefined ) {
						var this_bottom = this_top + $this.height();

						// we know this_top is above window_bottom, so...
						if ( this_bottom > window_top ) {
							// ...then _this_ article must be (the first) on screen
							lo = hi;
						}

						if ( this_bottom >= window_bottom ) {
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

Slash.Firehose.choose_article_for_next_ad = function(){
	var $articles = Slash.Firehose.articles_on_screen();
	return $articles.eq( Math.floor(Math.random()*$articles.length) );
}

})(Slash.jQuery);
