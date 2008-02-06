// _*_ Mode: JavaScript; tab-width: 8; indent-tabs-mode: true _*_
// $Id$

var nodmenu = null;
var nixmenu = null;
var nodnix_listener = null;

function get_nod_menu() {
	if ( !nodmenu )
		nodmenu = document.getElementById('nodmenu');
	return nodmenu;
}

function get_nix_menu() {
	if ( !nixmenu )
		nixmenu = document.getElementById('nixmenu');
	return nixmenu;
}

function get_nodnix_listener() {
  if ( !nodnix_listener ) {
    var keylist = new Array(); // must be an actual Array(), not just [], for YUI to do-the-right-thing
    keylist.push(YAHOO.util.KeyListener.KEY.SPACE);
    keylist.push('!'.charCodeAt(0));

    var a='A'.charCodeAt(0), z='Z'.charCodeAt(0);
    for ( var kc = a; kc <= z; ++kc )
      keylist.push(kc);

    // allow the following when we allow admin commands as well, e.g., #sometag
    //keylist.push('_'.charCodeAt(0));
    //keylist.push('#'.charCodeAt(0));
    //keylist.push('_'.charCodeAt(0));
    //keylist.push('*'.charCodeAt(0));
    //keylist.push('+'.charCodeAt(0));

    nodnix_listener = new YAHOO.util.KeyListener(document, {keys:keylist},
                                                           {fn:begin_nodnix_editing});
  }
  return nodnix_listener;
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
		g_pending_hidemenu = setTimeout("hide_nodnix_menu()", delay);
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
		YAHOO.util.Dom.setXY(menu, pos);
		g_nodnix_item_id = id;
		menu.focus();
		// temporarily disable listener, so live behavior won't change
		// get_nodnix_listener().enable();
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

function current_nodnix_input() {
  var menu;
     ((menu=get_nod_menu()).style.display != 'none')
  || ((menu=get_nix_menu()).style.display != 'none')
  ||  (menu=null);

  return YAHOO.util.Dom.hasClass(menu, 'editing') ? m.getElementsByTagName('input')[0] : null;
}

function begin_nodnix_editing( type, args, obj ) {
  if ( args ) {
    var event = args[1];
    // swallow the space character, if that's how they initiated editing,
    //  otherwise, let the key propogate so the newly focused text edit field can have it
    if ( event && event.keyCode==YAHOO.util.KeyListener.KEY.SPACE ) {
      YAHOO.util.Event.stopEvent(event);
    }
  }

  get_nodnix_listener().disable();
  YAHOO.util.Dom.addClass(get_nod_menu(), 'editing');
  YAHOO.util.Dom.addClass(get_nix_menu(), 'editing');
  dont_hide_nodnix_menu();

  var input = current_nodnix_input();
  input.focus();
}

function end_nodnix_editing() {
  YAHOO.util.Dom.removeClass(get_nod_menu(), 'editing');
  YAHOO.util.Dom.removeClass(get_nix_menu(), 'editing');
}
