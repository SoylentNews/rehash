// _*_ Mode: JavaScript; tab-width: 8; indent-tabs-mode: true _*_
; // $Id$

/*global setFirehoseAction firehose_get_updates tagsHideBody tagsShowBody
	firehose_fix_up_down firehose_toggle_tag_ui_to ajax_update json_handler
	json_update firehose_reorder firehose_get_next_updates getFirehoseUpdateInterval run_before_update
	firehose_play firehose_add_update_timerid firehose_collapse_entry
	vendorStoryPopup vendorStoryPopup2 firehose_save_tab check_logged_in
	firehose_set_cur firehose_style_switch
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



var view; // function view( what, how )
(function(){
var $body, $body_html, el_q=[];

// el_q has a matching DOM element for each queued call to animate(); synchronized by queue() and dequeue().
// el_q.length > 0 means a view() animation is in-progress, scrolling to reveal el_q[0].
function queue( el, how ){
	el_q.push(el);	// Keep el_q synchronized with the 'fx' queue on body.
	$body.queue('fx', function(){
		animate($(el), how);
	});
}
function dequeue(){
	el_q.shift();	// Keep el_q synchronized with the 'fx' queue on body.
	$body.dequeue('fx');
}

// view(false) to stop animation yourself.
view = function( what, how ){
	var stop_old=(what===false), start_new=!stop_old, $el, el;
	if ( start_new ) {
		how = how || { animate: true };
		$el=$any(what); el=$el[0];
		if ( !el || $.TypeOf.not('element', el) || Bounds.empty($el) ) {
			start_new = false;
		} else if ( el_q.length && ($.TypeOf.defNo(how.animate) || !DOM_descendant(el_q[el_q.length-1], el)) ) {
			// Stop the current animation for a request that is:
			//   (a) non-animated, i.e., how.animated===false; or
			//   (b) an element not contained in the current animation.
			stop_old = true;
		}
	}
	stop_old && stop();
	start_new && queue(el, how);
	return $el;
}
function stop(){
	// All-stop.  Clear the animation queue.  Hopefully no one else is animating body.
	$body_html.stop(true);
	el_q.length=0;
}

function offset( el, w, how, delta ){
	var $elem=$(el), e=new Bounds($elem);
	if ( ! Bounds.empty(e) ) {
		$.each({ top:-1, left:-1, bottom:1, right:1 }, function(edge, scale){
			e[edge] += scale*parseInt($elem.css('margin-'+edge));
		});

		delta || (delta={ dx:0, dy:0 });
		if ( how.axis!='y' && !Bounds.contain(Bounds.x(w), e) ) {
			delta.dx += (e.left<=w.left || w.width<=e.width() ? e.left-w.left : e.right-w.right);
		}
		if ( how.axis!='x' && !Bounds.contain(Bounds.y(w), e) ) {
			delta.dy += (e.top<=w.top || w.height()<=e.height() ? e.top-w.top : e.bottom-w.bottom);
		}
	}
	return delta;
}

function animate( $elem, how ){
	// (minimally) scroll an element entirely into view; how='x' or how='y' to scroll only on that axis
	var w0=new Bounds(window), w1, delta;
	if ( how.hint && !Bounds.empty($elem) ) {
		// If a "hint element" is given, then calculate the goal as if we
		//   viewed both in succession: view(how.hint); view($elem)
		delta = offset(how.hint, w0, how);
		w1 = new Bounds({
			top:	w0.top+delta.dy,
			left:	w0.left+delta.dx,
			bottom:	w0.bottom+delta.dy,
			right:	w0.right+delta.dx
		});
	} else {
		delta = { dx:0, dy:0 };
		w1 = new Bounds(w);
	}
	delta=offset($elem, w1, how, delta);

	if ( delta.dx || delta.dy ) {
		var x=w0.left+delta.dx, y=w0.top+delta.dy;
		if ( $.TypeOf.defNo(how.animate) ) {
			window.scrollTo(x, y);
			dequeue();
		} else {
			$body_html.animate({ scrollLeft:x, scrollTop:y }, dequeue);
		}
	}
}

function DOM_descendant( a, b ){
	var ancestor=$(a)[0], $descendant=$(b).eq(0);
	return ancestor && $descendant.parents().filter(function(){ return this===ancestor; }).length>0;
}

$(function(){
	$body=$('body');
	$body_html=$('body,html');
});
})();


function createPopup(pos_selector, titlebar, name, contents, message, onmouseout) {
	function div( kind, html ){
		return $('<div id="'+name+'-'+kind+'" class="popup-'+kind+'">'+(html||'')+'</div>');
	}

	var	pos	= Position(pos_selector),
		$popup	= $('<div id="'+name+'-popup" class="popup" style="position:absolute; top:'+pos.top+'px; left:'+pos.left+'px; z-index:100">').
				appendTo('body').
				append('<iframe>').
				append(div('title', titlebar)).
				append(div('contents', contents)).
				append(div('message', message));

	$.TypeOf.fn(onmouseout) && $popup.mouseleave(onmouseout);
	return $popup[0];
}

function createPopupButtons() {
	return '<span class="buttons"><span>' + $.makeArray(arguments).join('</span><span>') + '</span></span>';
}

function closePopup(id, refresh) {
	$any(id).remove();
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



function fhitems( o ){
	var fn = fhitems.fn.init.apply($.extend(function(){ return $(fn.root)[fn.op](fn.filter); }, fhitems.fn), arguments);
	return $.TypeOf(this)==='fhitems' ? fn : fn();
}
(function(){
var	sx = { root:'#firehoselist', items:'div[id^=firehose-]:not(.daybreak)', current:'.currfh' },
	$root = $([]);	// Don't cache sx.root until it actually exists...
$(function(){ $root = $(sx.root); });
fhitems.fn = fhitems.prototype = {
	__typeOf: function(){ return 'fhitems'; },
	init: function( o ){
		if ( arguments.length===1 && T(o)==='fhitems' ) {
			return $.extend(this, o); // "copy-constructor"
		}
		o = normalize_options.apply(this, arguments);

		var sxv = [ // ...will become this.filter.
			sx.root+'>',
			o.scope,
			o.sx || '',
			o.op_sx
		];

		if ( 'root' in o ) {
			this.root=o.root;
		} else if ( relOps[o.op] ) {
			this.root = sx.root+'>'+sx.items+sx.current; sxv[0]='';
		} else if ( o.op!=='children' ) {
			this.root = sxv.slice(0,3).join(''); sxv[0]=sxv[2]='';
		} else {
			this.root=$root; sxv[0]='';
		}
		this.op = o.op;
		this.filter = o.fn || sxv.join('') || undefined;
		return this;
	},
	selector: function(){
		return this.op==='children'
			? (this.root.selector||this.root)+'>'+(this.filter||'')
			: fhitems(this).selector;
	}
}

var	fhitemsArgTypes = {
		'function':	'fn',
		'boolean':	'scope',
		'element':	'root',
		'jquery':	'root',
		'undefined':	'root',
		'null':		'root'
	},
	relOps = Slash.Util.qw.as_set('next nextAll prev prevAll siblings'),
	T = $.TypeOf,
	optType = T.makeTest(function( o ){
		var t=T(o, true);
		return t==='string' ? o==='*' && 'scope' || o in $.fn && 'op' || 'sx' : fhitemsArgTypes[t];
	});

function normalize_options(){
	var o={ op_sx:'' }, i, v, k;
	for ( i=0; i<arguments.length; ++i ){
		(k=optType(v=arguments[i])) && (o[k]=v);
	}

	o.scope = o.scope===false && ':not('+sx.items+')'
		|| o.scope && '*'
		|| sx.items;

	if ( o.op==='next' || o.op==='prev' ) {
		o.op+='All'; o.op_sx=':first';
	} else if ( !o.op || T.not('string', o.op) ) {
		o.op = 'root' in o && 'closest' || o.fn && 'filter' || 'children';
	}

	return o;
}
})();


function fhitem_of( any ){
	// Returns a jQuery selection of the firehose-item that is, contains, or is identified by any.
	// Use fhitem_of() to present the "any" API from functions that work on firehose-items.
	switch ( $.TypeOf.unqualified(any) ) {
		case 'string':	if ( !/^\d+$/.test(any) ) { break; }
		case 'number':	any = 'firehose-' + any;
	}
	return $any(any).closest('#firehoselist>*');
}

function fhid_of( any ){
	// Returns the firehose-id associated with any, e.g., from 'firehose-12345', return 12345.
	var M;
	switch ( $.TypeOf.unqualified(any) ) {
		case 'number':
			return any;
		case 'element': case 'string':
			if ( M=/^(?:[-a-z]-)?(\d+)$/.exec(any.id||any) ) { return M[1]; }
		default:
			return (fhitem_of(any).attr('id') || '').substr(9); // chop off 'firehose-'
	}
}

function after_article_moved( article ){
	var data = article ? $(article).nextAll(':visible').andSelf() : null;
	$any('firehoselist').trigger('articlesMoved', data);
}

function before_article_removed( article, if_also_trigger_moved ){
	var next_article = article ? $(article).next(':visible')[0] : null;
	$any('firehoselist').trigger('beforeArticleRemoved', article);
	if ( if_also_trigger_moved ) {
		after_article_moved(next_article);
	}
}

function firehose_toggle_advpref() {
	$any('fh_advprefs').toggleClass('hide');
}

function firehose_open_prefs() {
	$any('fh_advprefs').removeClass();
}

function toggleIntro(id, toggleid) {
	var new_class = 'condensed';
	var new_html = '[+]';
	if ( $any(id).setClass(applyMap('introhide', 'intro')).hasClass('intro') ) {
		new_class = 'expanded';
		new_html = '[-]';
	}
	$any(toggleid).setClass(new_class).html(new_html);
}


function tagsToggleStoryDiv(id, is_admin, type) {
	if ( $any('toggletags-body-'+id).hasClass('tagshide') ) {
		tagsShowBody(id, is_admin, '', type);
	} else {
		tagsHideBody(id);
	}
}

function tagsHideBody(id) {
	$any('toggletags-body-'+id).setClass('tagshide');	// Make the body of the tagbox vanish
	$any('tagbox-title-'+id).setClass('tagtitleclosed');	// Make the title of the tagbox change back to regular
	$any('tagbox-'+id).setClass('tags');			// Make the tagbox change back to regular.
	$any('toggletags-button-'+id).html('[+]');		// Toggle the button back.
	after_article_moved(elemAny('firehose-'+id));
}

function tagsShowBody(id, unused, newtagspreloadtext, type) {

	type = type || "stories";

	if (type == "firehose") {
		setFirehoseAction();
		if (fh_is_admin) {
			firehose_get_admin_extras(id);
		}
	}

	//alert("Tags show body / Type: " + type );
	$any('toggletags-button-'+id).html("[-]");		// Toggle the button to show the click was received
	$any('tagbox-'+id).setClass("tags");			// Make the tagbox change to the slashbox class
	$any('tagbox-title-'+id).setClass("tagtitleopen");	// Make the title of the tagbox change to white-on-green
	$any('toggletags-body-'+id).setClass("tagbody");	// Make the body of the tagbox visible
	after_article_moved(elemAny('firehose-'+id));
}

function tagsOpenAndEnter(id, tagname, unused, type) {
	// This does nothing if the body is already shown.
	tagsShowBody(id, unused, tagname, type);
}

function reportError(request) {
	// replace with something else
	alert("error");
}

//Firehose functions begin
function toggle_firehose_body( any, unused, /*optional:*/toggle_to, dont_next ) {
	setFirehoseAction();

	var	$fhitem		= fhitem_of(any),
		id		= fhid_of($fhitem),
		$body		= $fhitem.children('[id^=fhbody-]'),
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


	var showing = toggle_to>0;

	if ( body_is_empty ) {
		var handlers = {};
		fh_is_admin && (handlers.onComplete = function(){
			firehose_get_admin_extras(id);
		});
		ajax_update({ op:'firehose_fetch_text', id:id, reskey:reskey_static }, $body.attr('id'), handlers);
	} else if ( fh_is_admin && showing ) {
		firehose_get_admin_extras(id);
	}

	$body.	removeClass('body empty hide').
		addClass(showing ? 'body' : 'hide');

	$fhitem.removeClass('article briefarticle adminmode usermode').
		addClass((showing ? 'article ' : 'briefarticle ') + (fh_is_admin ? 'adminmode' : 'usermode'));

	if (!dont_next && toggle_to < 0 && $fhitem.is('.currfh')) {
		firehose_go_next();
	}

	after_article_moved($fhitem);
	inlineAdFirehose(showing && $fhitem);
	return false;
}
toggle_firehose_body.SHOW	= 1;
toggle_firehose_body.TOGGLE	= 0;
toggle_firehose_body.HIDE	= -1;

function toggleFirehoseTagbox(id) {
	$any('fhtagbox-'+id).setClass(applyMap('tagbox', 'hide'));
	after_article_moved(elemAny('firehose-'+id));
}

function firehose_style_switch(section) {
	ajax_update({
		op: 'firehose_section_css',
		reskey: reskey_static,
		layout: 'yui',
		section: section
	}, '', {
		onComplete: function( xhr ){
			var json=eval_response(xhr), name=json&&json.skin_name, new_css=name&&json.css_includes;
			$('head link[rel=alternate stylesheet]').each(function(){
				(this.disabled = this.getAttribute('title')!==name) || (new_css=null);
			});
			new_css && $('head').append(new_css);
		}
	});
}


var firehose_set_options;
(function(){
var	qw		= Slash.Util.qw,
	loading_msg	= '<h1 class="loading_msg">Loading New Items</h1>',
	removes_all	= qw.as_set('firehose_usermode mixedmode mode nocolors nothumbs section setfhfilter setsearchfilter tab view'),
	start_over	= $.extend(qw.as_set('startdate'), removes_all),
	uses_setfield	= qw.as_set('mixedmode nobylines nocolors nocommentcnt nodates nomarquee noslashboxes nothumbs'),
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
	update_handlers	= {	onComplete: function(transport) {
					json_handler(transport);
					firehose_get_updates({ oneupdate: 1 });
				}
			};

// Grab a reference to #firehoselist as soon as possible...
var $fhl = $([]);	// ...but no sooner.
$(function(){ $fhl = $any('firehoselist'); });

function set_fhfilter_from( expr ){
	$(expr).each(function(){
		firehose_settings.fhfilter = this.value;
	});
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
		case 'tabsection':	params.tabtype='tabsection'; break;
		case 'view':		set_fhfilter_from('#searchquery'); break;
	}

	if ( start_over[name] ) {
		window.scrollTo(0, 0);
	}

	// We own #firehoselist and its contents; no need to pull _this_ UI code out into an event handler.
	if ( removes_all[name] ) {
		$('div.paginate').hide();
		// Fade the list; replace its contents with a single loading message; re-show it.
		$fhl.fadeOut(function(){ $fhl.html(loading_msg).show(); });
	}


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

	// Note: when setting a new section, we don't actually know the new color, filter,
	// or view until we get the response.  The firehose_sections code, though, _does_
	// That code can bind to firehose-setting-section to trigger the component
	// firehose-setting-{color,view,setfhfilter} events that will update the UI.
};
})();

function firehose_fix_up_down( id, new_state ){
	// Find the (possibly) affected +/- capsule.
	var $updown = $any('updown-'+id);

	if ( $updown.length && ! $updown.hasClass(new_state) ) {
		// We found the capsule, and it's state needs to be fixed.
		$updown.setClass(new_state);
	}
}

function firehose_click_nodnix_reason( event ) {
	var $fhitem=fhitem_of(event.target), id=fhid_of($fhitem);

	if ( (fh_is_admin || firehose_settings.metamod) && ($any('updown-'+id).is('.voteddown') || $fhitem.is('[type=comment]')) ) {
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

function tag_ui_in( $fhitem ){
	var $W = $fhitem.find('.tag-widget.body-widget');
	return { widget:$W, expanded:$W.is('.expanded') };
}

function firehose_toggle_tag_ui_to( want_expanded, any, dont_next ){
	var	$fhitem		= fhitem_of(any), // assert($fhitem.length)
		id		= fhid_of($fhitem),
		tag_ui		= tag_ui_in($fhitem),
		toggle		= tag_ui.expanded == !want_expanded; // force boolean conversion

	if ( toggle ) {
		if (want_expanded) { // need to expand
			if ($fhitem.find('div[id^=fhbody-]').is('.empty,.hide')) {
				toggle_firehose_body($fhitem, 0, true, dont_next);
				$fhitem.data('tags-opened-body', true);
			}
		}
	
		setFirehoseAction();
		want_expanded && $fhitem[0].fetch_tags();

		$fhitem.find('.tag-widget').each(function(){ this.set_context(); });
		tag_ui.widget.toggleClass('expanded', !!want_expanded);
		tag_ui.widget.find('a.edit-toggle .button').setClass(applyToggle({expand:want_expanded, collapse:!want_expanded}));
		$fhitem.find('#toggletags-body-'+id).setClass(applyToggle({tagbody:want_expanded, tagshide:!want_expanded}));

		if (!want_expanded && $fhitem.data('tags-opened-body')) { // is expanded, and parent was expanded by us
			toggle_firehose_body($fhitem, 0, false);
			$fhitem.removeData('tags-opened-body');
		}

		after_article_moved($fhitem[0]);
	}

	// always focus for expand request, even if already expanded
	want_expanded && tag_ui.widget.find('.tag-entry:visible:first').focus();
	return tag_ui.widget;
}

function firehose_toggle_tag_ui( any ) {
	var $fhitem = fhitem_of(any);
	firehose_toggle_tag_ui_to(!tag_ui_in($fhitem).expanded, $fhitem);
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
//
// Page initialization.
//

firehose_init_tag_ui();
$any('firehoselist').click(firehose_click_tag);	// if no #firehoselist, install click handler per article

// .live() binds these handlers to all current _and_ future firehose items
$('#firehoselist > div[id^=firehose-]:not(.daybreak)').
	live('blur-article', function(){
		var $fhitem = $(this);
		if ( $fhitem.data('blur-closes-item') ) {		toggle_firehose_body($fhitem, 0, false, true);
		} else if ( $fhitem.data('blur-closes-tags') ) {	firehose_toggle_tag_ui_to(false, $fhitem, true);
		}
		// optional, will focus before next blur
		$fhitem.removeData('blur-closes-item').
			removeData('blur-closes-tags').
			find('.tag-widget').
				each(function(){ this.set_context(); });
	}).
	live('focus-article', function(){
		var $fhitem = $(this);
		$fhitem.data('blur-closes-tags', !tag_ui_in($fhitem).expanded).
			data('blur-closes-item', $fhitem.find('[id^=fhbody-]').is('.empty,.hide'));
	});
	$('#firehoselist a.more').
	live('mousedown', pos_logger);

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
	'<span class="tag-display-stub" context="related" init="menu:false" />' +
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
			var $this = $(this), id = fhid_of(this);

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
			$any(id).html(html);
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
		$any(elem_id).
			html(new_html);
	});

	// ...set new values in these elements
	$.each(response.value||[], function(elem_id, new_value){
		$any(elem_id).
			each(function(){
				if ( this !== gFocusedText ) {
					$(this).val(new_value);
				}
			});
	});

	// ...append content to these elements
	$.each(response.html_append||[], function(elem_id, new_html){
		$any(elem_id).
			append(new_html);
	});

	// ...replace the specially marked "tail-end" (or else append) content of these elements
	$.each(response.html_append_substr||[], function(elem_id, new_html){
		$any(elem_id).
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

	var $fhl = $any('firehoselist');

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
			var $before, $after, before_id=firehose_before[el[1]], after_id=firehose_after[el[1]];
			before_id && ($before = $any('firehose-'+before_id));
			after_id && ($after = $any('firehose-'+after_id));

			if ( $before && $before.length ) {
				$before.after(el[2]);
				if ( !Bounds.intersect(window, 'title-'+ before_id) ) {
					need_animate = 0;
				}
			} else if ( $after && $after.length ) {

				// don't insert a new article between the floating slashbox ad and its article
				var $landmark=$after, $prev=$landmark.prev();
				if ( $prev.is('#floating-slashbox-ad') ) {
					$landmark = $prev;
				}

				$landmark.before(el[2]);
				if ( !Bounds.intersect(window, 'title-'+ after_id) ) {
					need_animate = 0;
				}
			} else if (insert_new_at == "bottom") {
				$fhl.append(el[2]);
				if ( !Bounds.intersect(window, 'fh-paginate') ) {
					need_animate = 0;
				}
			} else {
				$fhl.prepend(el[2]);
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
		} else if ( el[0]==='remove' && !$any(fh).is('.currfh') ) {
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
				if (!Bounds.intersect(window, fh_node)) {
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
			$fhl.fadeIn('slow');
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

function firehose_after_update(){
	firehose_reorder(firehose_ordered);
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


function pos_logger() {
	var id = fhid_of(this);
	var pos = 0;

	pos = $('#firehoselist > div[id^=firehose-]:not(.daybreak)').index(elemAny('firehose-' + id)) + 1;

	if(this.href.match(/\?/)) {
		this.href = this.href + "&art_pos=" + pos;
	} else {
		this.href= this.href + "?art_pos=" + pos;
	}
	return true;
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
		var $fh = $any('firehoselist');
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

	ajax_update($.extend({
		op:		'firehose_get_updates',
		ids:		firehose_get_item_idstring(),
		updatetime:	update_time,
		fh_pageval:	firehose_settings.pageval,
		embed:		firehose_settings.is_embedded,
		dynamic_blocks:	dynamic_blocks_list()
	}, firehose_settings), '', { onComplete: firehose_get_updates_handler, onError: firehose_updates_error_handler });
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
	$any('preference_title').html('Firehose Paused due to inactivity');
	show_modal_box();
	$any('modal_box_content').html("<a href='#' onclick='setFirehoseAction();hide_modal_box()'>Click to unpause</a>");
	show_modal_box();
}

function start_up_hose() {
	firehose_set_options('pause', false);
}

function firehose_play(context) {
	fh_play = 1;
	var wait = 0;
	if (context && context == "init") {
		wait = getFirehoseUpdateInterval();
	}

	setFirehoseAction();
	if (context && context == "init") {
		setTimeout(start_up_hose, wait);
	} else {
		firehose_set_options('pause', false, context);
	}

	$any('message_area').html('');
	$any('pauseorplay').html('Updated');
	$any('play').setClass('hide');
	$any('pause').setClass('show');
}

function is_firehose_playing() {
  return fh_play==1;
}

function firehose_pause(context) {
	fh_play = 0;
	$any('pause').setClass('hide');
	$any('play').setClass('show');
	$any('pauseorplay').html('Paused');
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
		removeClass('article').
		addClass('briefarticle');

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
	createPopup('sponsorlinks', title, "vendorStory-" + id, "Loading", "", closepopup );
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
	createPopup('sponsorlinks', title, "vendorStory-" + id, "Loading", "", closepopup );
	var params = {};
	params.op = 'getTopVendorStory';
	params.skid = id;
	ajax_update(params, "vendorStory-" + id + "-contents");
}

function logToDiv(id, message) {
	$any(id).append(message + '<br>');
}


function firehose_open_tab(id) {
	$any('tab-form-'+id).removeClass();
	$any('tab-input-'+id).focus();
	$any('tab-text-'+id).setClass('hide');
}

function firehose_save_tab(id) {
	var	$tab		= $any('fhtab-'+id),
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
	$any('modal_box_content').load(
		'/ajax.pl',
		$.extend({
			op:		'getModalPrefs',
			section:	section,
			reskey:		reskey_static,
			tabbed:		tabbed
		}, params||{}),
		function(){
			$any('preference_title').html(title);
			show_modal_box().data('tabbed', tabbed);
		}
	);
}

function firehose_get_media_popup(id) {
	$any('preference_title').html('Media');
	show_modal_box();
	$any('modal_box_content').html("<h4>Loading...</h4><img src='/images/spinner_large.gif'>");
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
	$any('preference_title').html('Firehose updates failed');
	$any('modal_box_content').html('Update failed or timed out.  <a href="#" onclick="firehose_reinit_updates();hide_modal_box();">Click to retry</a>');
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
		data: 	serialize_multiple($any('modal_prefs')),
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
		data:	serialize_multiple($any('modal_prefs')),
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
	var el = $any(id);
	el.css('display', el.css('display')!='none' ? 'none' : 'block');
}

function toggle_filter_prefs() {
	$('#filter_play_status, #filter_prefs').toggleClass('hide');
}


function firehose_get_cur() {
	return $('#firehoselist > div.currfh');
}

function firehose_get_first() {
	return $('#firehoselist > div[id^=firehose-]:not(.daybreak):first');
}

function firehose_set_cur($new_current) {
	if (!$new_current || !$new_current.length)
		$new_current = firehose_get_first();

	$new_current = $new_current.eq(0); // only one article may be current at a time
	if ($new_current.is('.currfh'))
		return $new_current;

	var	$old_current	= $new_current.siblings('div[id^=firehose-]:not(.daybreak).currfh'),
		event_data	= { blurring:$old_current, focusing:$new_current };

	$old_current.each(function(){
		// "blur" previous current article, if any (and correct if "multiple current")
		$(this).trigger('blur-article', event_data).
			removeClass('currfh'); // after event
	});

	return view(
		// scroll to and "focus" new current article
		$new_current.
			addClass('currfh'). // before event
			trigger('focus-article', event_data)
	);
}

function firehose_go_next($current) {
	$current = $current || firehose_get_cur();
	var $next = $current.nextAll('div[id^=firehose-]:not(.daybreak):first');
	// if no current, pick top; if current but no next, do more
	if ($next[0] || !$current[0]) {
		return firehose_set_cur($next);
	} else {
		view('div#fh-paginate');
		firehose_more();
	}
}

function firehose_go_prev($current) {
	$current = $current || firehose_get_cur();
	return firehose_set_cur(
		$current.prevAll('div[id^=firehose-]:not(.daybreak):first')
	);
}

function firehose_more(noinc) {
	if (!noinc) {
		firehose_settings.more_num = firehose_settings.more_num + firehose_more_increment;
	}

	if (((firehose_item_count + firehose_more_increment) >= 200) && !fh_is_admin) {
		$any('firehose_more').hide();
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
	$any('viewsearch').parent().toggleClass('mode-filter', data.id!=='unsaved');
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
	var	$section_menu	= $any('firehose-sections'),
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
	var	visible		= new Bounds(window),
		$visible_ads	= $('li.inlinead').filter(function(){
					if ( Bounds.intersect(visible, this) ) return this;
				});
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

	$footer = $any('ft');
	$slashboxes = $('#slashboxes, #userboxes').eq(0);

	$any('firehoselist').
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

function verticalAdSpace(){
	var bounds = Bounds.y($slashboxes);
	bounds.top	= bounds.bottom;
	bounds.bottom	= Position($footer).top;
	return bounds;
}

var pinClasses = {};
pinClasses[-1]		= 'Top';	// pinned to the top of the available space, though the natural top is higher
pinClasses[0]		= 'No';		// not pinned
pinClasses[1]		= 'Bottom';	// pinned to the bottom of the available space, though the natural top would be lower
pinClasses[undefined]	= 'Empty';	// not enough room to hold an ad


function fix_ad_position(){
	if ( $ad_position.length ) {
		var space = verticalAdSpace();
		if ( $.TypeOf(space.top)!=='number' ||  $.TypeOf(space.bottom)!=='number' ) {
			return;
		}
		space.bottom-=AD_HEIGHT;

		// the "natural" ad position is top-aligned with the following article
		var natural_top = Position($ad_position.next()).top;
		if ( natural_top===undefined ) {
			// ...or else top-aligned to the previous bottom, I guess... but wouldn't this mean you're at the end the page?
			natural_top = Bounds($ad_position.prev()).bottom;
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
			new_top = pin_between(space.top, natural_top, space.bottom) - Position($ad_offset_parent).top;
		}

		$ad_position.
			setClass(pinClasses[pinning]).
			css('top', new_top);
	}
}

Slash.Util.Package({ named: 'Slash.Firehose.floating_slashbox_ad',
	api: {
		is_visible:		function(){ return Bounds.intersect(window, $ad_position); },
		remove:			remove_ad
	},
	stem_function: insert_ad
});

Slash.Firehose.articles_on_screen = function(){
	var	visible = Bounds.y(window),
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
			var visible = Bounds.intersection(Bounds.y(window), verticalAdSpace());
			visible.bottom -= AD_HEIGHT;

			$result = $articles.filter(function(){
				return Bounds.contain(visible, Position(this));
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

function openInWindow(mylink, samewin) {
	if (!samewin && window.open(mylink, '_blank')) {
		return false;
	}
	window.location = mylink;
	return false;
}

$(function(){
	// firehose only!
	var validkeys = {};
	if (window.location.href.match(/\b(?:firehose|index2|console)\.pl\b/)) {
		validkeys = {
			'X' : {           tags    : 1, signoff  : 1 },
			'T' : {           tags    : 1, tag      : 1 },
			187 : { chr: '+', tags    : 1, tag      : 1, nod    : 1 }, // 61, 107
			189 : { chr: '-', tags    : 1, tag      : 1, nix    : 1 }, // 109

			'R' : {           open    : 1, readmore : 1 },
			'E' : {           open    : 1, edit     : 1 },
			'O' : {           open    : 1, link     : 1 },

			'G' : {           more    : 1 },
			'Q' : {           toggle  : 1 },
			'S' : {           next    : 1 },
			'W' : {           prev    : 1 },

			'F' : {           search  : 1 },
			190 : { chr: '.', slash   : 1 }, // 110

			27  : {           form    : 1, unfocus : 1 } // esc
		};
		validkeys['H'] = validkeys['A'] = validkeys['Q'];
		validkeys['L'] = validkeys['D'] = validkeys['Q'];
		validkeys['K'] = validkeys['W'];
		validkeys['J'] = validkeys['S'];
		validkeys['I'] = validkeys['T'];
		validkeys[107] = validkeys[61] = validkeys[187];
		validkeys[109] = validkeys[189];
		validkeys[110] = validkeys[190];
	}

// down arrow: 40
// left arrow: 37
// enter: 13


	$(document).keydown(function( e ) {
		// no modifiers, except maybe shift
		if (e.ctrlKey || e.metaKey || e.altKey)
			return true;

		var shiftKey = e.shiftKey ? 1 : 0;

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

		var cur = firehose_get_cur();
		var el, id;
		if (cur.length) {
			el = cur[0];
			id = el.id.substr(9);
		}

		if (keyo.tag && el) {
			if (keyo.nod)     { el.submit_tags('nod') }
			if (keyo.nix)     { el.submit_tags('nix') }
			firehose_toggle_tag_ui_to(true, el);
		}

		if (keyo.signoff && el && tag_admin) {
			el.submit_tags('signoff');
			// we either call set_cur($(el)) as above,
			// or just pass $(el) to go_next()
			firehose_go_next($(el));
		}

		if (keyo.slash)          {
			// a bit silly
			var fsid = $('#firehose-sections').find('li:not([id=fhsection-unsaved]):first')[0].id.substr(10);
			firehose_set_options('section', fsid);
		}
		if (keyo.unfocus)        { $(e.target).blur()        }
		if (keyo.next)           { firehose_go_next()        }
		if (keyo.prev)           { firehose_go_prev()        }
		if (keyo.more)           { firehose_more()           }
		if (keyo.search)         { $('#searchquery').focus() }
		if (keyo.toggle && id)   { toggle_firehose_body(id)  }

		if (keyo.open) {
			var mylink = '';
			var obj;
			//var doc_url = document.location.href.replace(/(\w\/).*$/, '$1');
			if (keyo.link) {
				obj = cur.find('span.external > a:first');
			}
			if (keyo.readmore) {
				obj = cur.find('a.datitle:first');
				//mylink = doc_url + 'firehose.pl?op=view&id=' + id;
			}
			if (keyo.edit) { // && fh_is_admin) {
				obj = cur.find('form.edit > a:first');
				//mylink = doc_url + 'firehose.pl?op=edit&id=' + id;
			}
			if (!mylink.length && obj.length) {
				mylink = obj[0].href;
			}

			if (mylink.length) {
				return openInWindow(mylink, (shiftKey ? 1 : 0));
			} else {
				return true;
			}
		}

		return false;
	});
});


