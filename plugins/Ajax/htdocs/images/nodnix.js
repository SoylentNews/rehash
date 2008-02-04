// _*_ Mode: JavaScript; tab-width: 8; indent-tabs-mode: true _*_
// $Id$

var nodmenu = null;
var nixmenu = null;

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
