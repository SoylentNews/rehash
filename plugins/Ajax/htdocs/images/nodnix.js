// _*_ Mode: JavaScript; tab-width: 8; indent-tabs-mode: true _*_
// $Id$

var nod_completer = null;
var nix_completer = null;

function get_nod_menu() {
	if ( !get_nod_menu.nodmenu )
		get_nod_menu.nodmenu = document.getElementById('nodmenu');
	return get_nod_menu.nodmenu;
}

function get_nix_menu() {
	if ( !get_nix_menu.nixmenu )
		get_nix_menu.nixmenu = document.getElementById('nixmenu');
	return get_nix_menu.nixmenu;
}

function get_predefined_nodnix_tags() {
  var tags = [];
  var query = _get_nodnix('input').getAttribute("updown");
  var listEl = query=="+" ? document.getElementById('static-nod-completions')
                          : document.getElementById('static-nix-completions');
  if ( listEl ) {
    var itemEls = listEl.getElementsByTagName('li');
    for ( var i=0; i<itemEls.length; ++i )
      tags.push([itemEls[i].textContent]);
  }
  return tags;
}
var predefinedDS = new YAHOO.widget.DS_JSFunction(get_predefined_nodnix_tags);


var proxyDS = new Object();
proxyDS.__proto__ = YAHOO.slashdot.dataSources[0];
proxyDS.doQuery = function( oCallbackFn, sQuery, oParent ) {
  if ( sQuery && sQuery.length )
    this.__proto__.doQuery(oCallbackFn, sQuery, oParent)
  else
    predefinedDS.doQuery(oCallbackFn, sQuery, oParent);
}

function get_nodnix_listener() {
  if ( !get_nodnix_listener.nodnix_listener ) {
    var keylist = new Array(); // must be an actual Array(), not just [], for YUI to do-the-right-thing
    keylist.push(YAHOO.util.KeyListener.KEY.ESCAPE);

    var a='A'.charCodeAt(0), z='Z'.charCodeAt(0);
    for ( var kc = a; kc <= z; ++kc )
      keylist.push(kc);
    var extras = "!_#)^*";
    for ( var i=0; i<extras.length; ++i )
      keylist.push(extras.charCodeAt(i));

    get_nodnix_listener.nodnix_listener = new YAHOO.util.KeyListener(document, {keys:keylist},
                                                           {fn:handle_nodnix_key});


    var keylist2 = new Array();
    keylist2.push(YAHOO.util.KeyListener.KEY.SPACE);
    keylist2.push(YAHOO.util.KeyListener.KEY.ESCAPE);
    keylist2.push(YAHOO.util.KeyListener.KEY.ENTER);

    var setupCompleter = function(inputEl, containerEl) {
      var ac = new YAHOO.widget.AutoComplete(inputEl, containerEl, proxyDS);
      //ac.typeAhead = true;
      ac.allowBrowserAutocomplete = false;
      ac.highlightClassName = "selected";
      ac.minQueryLength = 0;

      ac.textboxBlurEvent.subscribe(handle_nodnix_blur);
      ac.itemSelectEvent.subscribe(handle_nodnix_select);
      ac.unmatchedItemSelectEvent.subscribe(handle_nodnix_select);

      var listener = new YAHOO.util.KeyListener(inputEl, {keys:keylist2}, {fn:handle_completer_key});
      listener.enable();

      return ac;
    }

    nod_completer = setupCompleter("nod-input", "nod-completions");
    nix_completer = setupCompleter("nix-input", "nix-completions");
  }
  return get_nodnix_listener.nodnix_listener;
}



var g_elem_for_pending_showmenu = null;
var g_menu_for_pending_showmenu = null;
var g_id_for_pending_showmenu = null;
var g_pending_showmenu = null;
var g_pending_hidemenu = null;

var g_nodnix_item_id = null;

function nodnix_tag( tag, up_down ) {
	createTag(tag, g_nodnix_item_id, "firehose");
	if ( up_down !== undefined )
		firehose_up_down(g_nodnix_item_id, up_down);
}

function nodnix_not_tag( old_tag ) {
  var new_tag = old_tag[0]=='!' ? old_tag.slice(1) : '!'+old_tag;
	createTag(new_tag, g_nodnix_item_id, "firehose");
	var tag_list = _get_nodnix('ol');
	  // XXX not a good idea if the tag happens to be 'span' or 'li', etc
	tag_list.innerHTML = tag_list.innerHTML.replace(old_tag, new_tag, "g");
}

function nodnix_del_tag( tag ) {
}

function hide_nod_menu() {
	get_nod_menu().style.display = 'none';
}

function hide_nix_menu() {
	get_nix_menu().style.display = 'none';
}

function hide_nodnix_menu( delay ) {
	if ( delay == undefined || !delay ) {
		hide_nod_menu();
		hide_nix_menu();
		end_nodnix_editing();
		get_nodnix_listener().disable();
	} else {
		if ( g_pending_hidemenu )
			clearTimeout(g_pending_hidemenu);
		g_pending_hidemenu = setTimeout(hide_nodnix_menu, delay);
	}
}

function dont_hide_nodnix_menu() {
	clearTimeout(g_pending_hidemenu);
	g_pending_hidemenu = null;
}



function show_nodnix_menu(elem, id, menu, show_delay, hide_delay) {
	if ( show_delay == undefined || !show_delay ) {
		var pos = YAHOO.util.Dom.getXY(elem);
		menu.style.display = 'block';
		end_nodnix_editing();
		YAHOO.util.Dom.setXY(menu, pos);
		g_nodnix_item_id = id;
		menu.focus();
		get_nodnix_listener().enable();
	} else {
		g_elem_for_pending_showmenu = elem;
		g_menu_for_pending_showmenu = menu;
		g_id_for_pending_showmenu = id;
		if ( g_pending_showmenu )
			clearTimeout(g_pending_showmenu);
		g_pending_showmenu = setTimeout("show_nodnix_menu(g_elem_for_pending_showmenu, g_id_for_pending_showmenu, g_menu_for_pending_showmenu)", show_delay);
	}

	if ( hide_delay != undefined && hide_delay != 0 ) {
		hide_nodnix_menu(hide_delay);
	}
}

function dont_show_nodnix_menu() {
	clearTimeout(g_pending_showmenu);
	g_pending_showmenu = null;
}

function show_nod_menu(elem, id, show_delay, hide_delay) {
	hide_nix_menu();
	show_nodnix_menu(elem, id, get_nod_menu(), show_delay, hide_delay);
}

function show_nix_menu(elem, id, show_delay, hide_delay) {
	hide_nod_menu();
	show_nodnix_menu(elem, id, get_nix_menu(), show_delay, hide_delay);
}

function _get_nodnix( tag ) {
  var menu;
     ((menu=get_nod_menu()).style.display != 'none')
  || ((menu=get_nix_menu()).style.display != 'none')
  ||  (menu=null);

  if ( ! YAHOO.util.Dom.hasClass(menu, 'editing') )
    return;

  return menu.getElementsByTagName(tag)[0];
}

function handle_nodnix_key( type, args, obj ) {
  if ( args ) {
    var event = args[1];
    if ( event ) {
        // space key initiates editing, but _doesn't_ go into the text field (swallow it)
        // escape key hides the menu before we even start editing (and we swallow it)
        // any other key initiates editing and goes into the text field (don't swallow it)
      var isSPACE = event.keyCode == YAHOO.util.KeyListener.KEY.SPACE;
      var isESCAPE = event.keyCode == YAHOO.util.KeyListener.KEY.ESCAPE;

      if ( isSPACE || isESCAPE )
        YAHOO.util.Event.stopEvent(event);

      if ( isESCAPE )
        hide_nodnix_menu();
      else
        begin_nodnix_editing();
    }
  }
}

function soon_is_now() {
  YAHOO.util.Dom.removeClass(get_nod_menu(), 'soon');
  YAHOO.util.Dom.removeClass(get_nix_menu(), 'soon');
}

function begin_nodnix_editing() {
  get_nodnix_listener().disable();
  YAHOO.util.Dom.addClass(get_nod_menu(), 'soon');
  YAHOO.util.Dom.addClass(get_nix_menu(), 'soon');
  YAHOO.util.Dom.addClass(get_nod_menu(), 'editing');
  YAHOO.util.Dom.addClass(get_nix_menu(), 'editing');
  dont_hide_nodnix_menu();

  var input = _get_nodnix('input');
  input.value = "";
  input.focus();

  var tag_list = _get_nodnix('ol');
  tag_list.innerHTML = "";

  // ajax request to fill the user tags list
  var params = [];
  params['op'] = 'tags_get_user_firehose';
  params['id'] = g_nodnix_item_id;
  params['nodnix'] = 1;
  ajax_update(params, tag_list, {});

  (input.getAttribute("updown")=="+" ? nod_completer : nix_completer).sendQuery();
  setTimeout(soon_is_now, 225);
}

function end_nodnix_editing() {
  YAHOO.util.Dom.removeClass(get_nod_menu(), 'editing');
  YAHOO.util.Dom.removeClass(get_nix_menu(), 'editing');
}

function handle_nodnix_blur( type, args ) {
  hide_nodnix_menu();
}

function handle_nodnix_select( type, args, stay_open ) {
  var tagname = args[2];
  if ( tagname !== undefined && tagname !== null ) {
    if ( typeof tagname != 'string' )
      tagname = tagname[0];
    nodnix_tag(tagname);
      // now 'harden' the tag
    var list = _get_nodnix('ol');
    list.innerHTML = handle_nodnix_select.template_string.split('$').join(tagname) + list.innerHTML;
    _get_nodnix('input').value = "";
  }
  if ( !stay_open )
    hide_nodnix_menu();
}

  // WARNING: keep this string in sync with tagsnodnixuser;misc;default
handle_nodnix_select.template_string = '<li>$<span class="tag-actions"><a class="not-tag" onmousedown="nodnix_not_tag(\'$\'); return false" href="#">!</a> <a class="del-tag" onmousedown="nodnix_del_tag(\'$\'); return false" href="#">x</a></span></li>';

function handle_completer_key( type, args ) {
  var key = args[0];
  var event = args[1];
  var stay_open = false;
  switch ( key ) {
    case YAHOO.util.KeyListener.KEY.ESCAPE:
      hide_nodnix_menu();
      break;
    case YAHOO.util.KeyListener.KEY.SPACE:
      YAHOO.util.Event.stopEvent(event);
      stay_open = true;
      // fall through
    case YAHOO.util.KeyListener.KEY.ENTER:
      handle_nodnix_select("", [null, null, _get_nodnix('input').value], stay_open);
      break;
  }
}

