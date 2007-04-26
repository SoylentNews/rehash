// _*_ Mode: JavaScript; tab-width: 8; indent-tabs-mode: true _*_
// $Id$

var fh_play = 0;
var fh_is_timed_out = 0;
var fh_is_updating = 0;
var fh_update_timerids = Array(0);
var fh_is_admin = 0;
var console_updating = 0;
var firehose_updates = Array(0);
var firehose_updates_size = 0;
var firehose_ordered = Array(0);
var firehose_before = Array(0);
var firehose_after = Array(0);
var firehose_startdate = '';
var firehose_issue = '';
var firehose_duratiton = '';
var firehose_removed_first = '0';
var firehose_future;
var fh_colorslider; 
var fh_ticksize;
var fh_pageval = 0;
var fh_colors = Array(0);
var vendor_popup_timerids = Array(0);
var vendor_popup_id = 0;
var fh_slider_init_set = 0;

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
	var buttons = "";
	if (arguments.length > 0) {
		buttons = '<span class="buttons">';
	}
	for (var i=0; i<arguments.length; i++) {
		buttons =  buttons + "<span>" + arguments[i] + "</span>";
	}

	buttons = buttons + "</span>";
	return buttons;
}

function closePopup(id, refresh) {
	var el = $(id);
	if (el) {
		el.parentNode.removeChild(el);
	}
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

function getXYForId(id, addWidth, addHeight) {
	var div = $(id);
	var xy = Position.cumulativeOffset(div);
	if (addWidth) {
		xy[0] = xy[0] + div.offsetWidth;
	}
	if (addHeight) {
		xy[1] = xy[1] + div.offsetHeight;
	}
	return xy;
}

function firehose_toggle_advpref() {
	var obj = $('fh_advprefs');
	if (obj.className == 'hide') {
		obj.className = "";
	} else {
		obj.className = "hide";
	}
}

function toggleIntro(id, toggleid) {
	var obj = $(id);
	var toggle = $(toggleid);
	if (obj.className == 'introhide') {
		obj.className = "intro"
		toggle.innerHTML = "[-]";
		toggle.className = "expanded";
	} else {
		obj.className = "introhide"
		toggle.innerHTML = "[+]";
		toggle.className = "condensed";
	}
}

function tagsToggleStoryDiv(id, is_admin, type) {
	var bodyid = 'toggletags-body-' + id;
        var tagsbody = $(bodyid);
	if (tagsbody.className == 'tagshide') {
		tagsShowBody(id, is_admin, '', type);
	} else {
		tagsHideBody(id);
	}
}

function tagsHideBody(id) {
	// Make the body of the tagbox vanish
	var tagsbodyid = 'toggletags-body-' + id;
        var tagsbody = $(tagsbodyid);
	tagsbody.className = "tagshide"

	// Make the title of the tagbox change back to regular
	var titleid = 'tagbox-title-' + id;
        var title = $(titleid);
	title.className = "tagtitleclosed";

	// Make the tagbox change back to regular.
	var tagboxid = 'tagbox-' + id;
        var tagbox = $(tagboxid);
	tagbox.className = "tags";

	// Toggle the button back.
	var tagsbuttonid = 'toggletags-button-' + id;
        var tagsbutton = $(tagsbuttonid);
	tagsbutton.innerHTML = "[+]";
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
	
	// Toggle the button to show the click was received
	var tagsbuttonid = 'toggletags-button-' + id;
        var tagsbutton = $(tagsbuttonid);
	tagsbutton.innerHTML = "[-]";

	// Make the tagbox change to the slashbox class
	var tagboxid = 'tagbox-' + id;
        var tagbox = $(tagboxid);
	tagbox.className = "tags";

	// Make the title of the tagbox change to white-on-green
	var titleid = 'tagbox-title-' + id;
        var title = $(titleid);
	title.className = "tagtitleopen";

	// Make the body of the tagbox visible
	var tagsbodyid = 'toggletags-body-' + id;
        var tagsbody = $(tagsbodyid);
	
	tagsbody.className = "tagbody";
	
	// If the tags-user div hasn't been filled, fill it.
	var tagsuserid = 'tags-user-' + id;
	var tagsuser = $(tagsuserid);
	if (tagsuser.innerHTML == "") {
		// The tags-user-123 div is empty, and needs to be
		// filled with the tags this user has already
		// specified for this story, and a reskey to allow
		// the user to enter more tags.
		tagsuser.innerHTML = "Retrieving...";
		var params = [];
		if (type == "stories") {
			params['op'] = 'tags_get_user_story';
			params['sidenc'] = id;
		} else if (type == "urls") {
			//alert('getting user urls ' + id);
			params['op'] = 'tags_get_user_urls';
			params['id'] = id;
		} else if (type == "firehose") {
			params['op'] = 'tags_get_user_firehose';
			params['id'] = id;
		}
		params['newtagspreloadtext'] = newtagspreloadtext;
		var handlers = {
			onComplete: function() { 
				var textid = 'newtags-' + id;
				var input = $(textid);
				input.focus();
			}
		}
		ajax_update(params, tagsuserid, handlers);
		//alert('after ajax_update ' + tagsuserid);

		// Also fill the admin div.  Note that if the user
		// is not an admin, this call will not actually
		// return the necessary form (which couldn't be
		// submitted anyway).  The is_admin parameter just
		// saves us an ajax call to find that out, if the
		// user is not actually an admin.
		if (is_admin) {
			var tagsadminid = 'tags-admin-' + id;
			params = [];
			if (type == "stories") {
				params['op'] = 'tags_get_admin_story';
				params['sidenc'] = id;
			} else if (type == "urls") {
				params['op'] = 'tags_get_admin_url';
				params['id'] = id;
			} else if (type == "firehose") {
				params['op'] = 'tags_get_admin_firehose';
				params['id'] = id;
			}
			ajax_update(params, tagsadminid);
		}

	} else {
		if (newtagspreloadtext) {
			// The box was already open but it was requested
			// that we append some text to the user text.
			// We can't do that by passing it in, so do it
			// manually now.
			var textinputid = 'newtags-' + id;
			var textinput = $(textinputid);
			textinput.value = textinput.value + ' ' + newtagspreloadtext;
			textinput.focus();
		}
	}
}

function tagsOpenAndEnter(id, tagname, is_admin, type) {
	// This does nothing if the body is already shown.
	tagsShowBody(id, is_admin, tagname, type);
}

function completer_renameMenu( s, params ) {
  if ( s )
    params._sourceEl.innerHTML = s;
}

function completer_setTag( s, params ) {
  createTag(s, params._id, params._type);
  var tagField = document.getElementById('newtags-'+params._id);
  if ( tagField ) {
    var s = tagField.value.slice(-1);
    if ( s.length && s != " " )
      tagField.value += " ";
    tagField.value += s;
  }
}

function completer_handleNeverDisplay( s, params ) {
  if ( s == "neverdisplay" )
    admin_neverdisplay("", "firehose", params._id);
}

function completer_save_tab(s, params) {
	firehose_save_tab(params._id);
}

function attachCompleter( obj, id, is_admin, type, tagDomain, customize ) {
  if ( navigator.vendor !== undefined ) {
    var vendor = navigator.vendor.toLowerCase();
    if ( vendor.indexOf("apple") != -1
         || vendor.indexOf("kde") != -1 )
      return false;
  }

  if ( customize === undefined )
    customize = new Object();
	customize._id = id;
	customize._is_admin = is_admin;
	customize._type = type;
	if ( tagDomain != 0 && customize.queryOnAttach === undefined )
	  customize.queryOnAttach = true;
  
	if ( !YAHOO.slashdot.gCompleterWidget )
		YAHOO.slashdot.gCompleterWidget = new YAHOO.slashdot.AutoCompleteWidget();

	YAHOO.slashdot.gCompleterWidget.attach(obj, customize, tagDomain);
	return false;
}

function reportError(request) {
	// replace with something else
	alert("error");
}

function createTag(tag, id, type) {
	var params = [];
	params['op'] = 'tags_create_tag';
	params['reskey'] = reskey_static;
	params['name'] = tag;
	params['id'] = id;
	params['type'] = type;
	ajax_update(params, '');
}

function tagsCreateForStory(id) {
	var toggletags_message_id = 'toggletags-message-' + id;
	var toggletags_message_el = $(toggletags_message_id);
	toggletags_message_el.innerHTML = 'Saving tags...';

	var params = [];
	params['op'] = 'tags_create_for_story';
	params['sidenc'] = id;
	var newtagsel = $('newtags-' + id);
	params['tags'] = newtagsel.value;
	var reskeyel = $('newtags-reskey-' + id);
	params['reskey'] = reskeyel.value;

	ajax_update(params, 'tags-user-' + id);

	// XXX How to determine failure here?
	toggletags_message_el.innerHTML = 'Tags saved.';
}

function tagsCreateForUrl(id) {
	var toggletags_message_id = 'toggletags-message-' + id;
	var toggletags_message_el = $(toggletags_message_id);
	toggletags_message_el.innerHTML = 'Saving tags...';

	var params = [];
	params['op'] = 'tags_create_for_url';
	params['id'] = id;
	var newtagsel = $('newtags-' + id);
	params['tags'] = newtagsel.value;
	var reskeyel = $('newtags-reskey-' + id);
	params['reskey'] = reskeyel.value;

	ajax_update(params, 'tags-user-' + id);

	// XXX How to determine failure here?
	toggletags_message_el.innerHTML = 'Tags saved.';
}

//Firehose functions begin
function setOneTopTagForFirehose(id, newtag) {
	var params = [];
	params['op'] = 'firehose_update_one_tag';
	params['id'] = id;
	params['tags'] = newtag;
	// params['reskey'] = reskeyel.value;
	ajax_update(params, '');
}

function tagsCreateForFirehose(id) {
	var toggletags_message_id = 'toggletags-message-' + id;
	var toggletags_message_el = $(toggletags_message_id);
	toggletags_message_el.innerHTML = 'Saving tags...';
	
	var params = [];
	params['op'] = 'tags_create_for_firehose';
	params['id'] = id;
	var newtagsel = $('newtags-' + id);
	params['tags'] = newtagsel.value; 
	var reskeyel = $('newtags-reskey-' + id);
	params['reskey'] = reskeyel.value;

	ajax_update(params, 'tags-user-' + id);
	toggletags_message_el.innerHTML = 'Tags saved.';
}

function toggle_firehose_body(id, is_admin) {
	var params = [];
	setFirehoseAction();
	params['op'] = 'firehose_fetch_text';
	params['id'] = id;
	var fhbody = $('fhbody-'+id);
	var fh = $('firehose-'+id);
	if (fhbody.className == "empty") {
		var handlers = {
			onComplete: function() { 
				firehose_get_admin_extras(id); 
			}
		};
		params['reskey'] = reskey_static;
		if (is_admin) {
			ajax_update(params, 'fhbody-'+id, handlers);
		} else {
			ajax_update(params, 'fhbody-'+id);
		}
		fhbody.className = "body";
		fh.className = "article";
		if (is_admin)
			tagsShowBody(id, is_admin, '', "firehose");
	} else if (fhbody.className == "body") {
		fhbody.className = "hide";
		fh.className = "briefarticle";
		if (is_admin)
			tagsHideBody(id);
	} else if (fhbody.className == "hide") {
		fhbody.className = "body";
		fh.className = "article";
		if (is_admin)
			tagsShowBody(id, is_admin, '', "firehose");
	}
}

function toggleFirehoseTagbox(id) {
	var fhtb = $('fhtagbox-'+id);
	if (fhtb.className == "hide") {
		fhtb.className = "tagbox";
	} else {
		fhtb.className = "hide";
	}
}

function firehose_set_options(name, value) {
	var pairs = [
		// name		value		curid		newid		newvalue 	title 
		["orderby", 	"createtime", 	"popularity",	"time",		"popularity"	],
		["orderby", 	"popularity", 	"time",		"popularity",	"createtime"	],
		["orderdir", 	"ASC", 		"asc",		"desc",		"DESC"],
		["orderdir", 	"DESC", 	"desc",		"asc",		"ASC"],
		["mode", 	"full", 	"abbrev",	"full",		"fulltitle"],
		["mode", 	"fulltitle", 	"full",		"abbrev",	"full"],
	];
	var params = [];
	params['op'] = 'firehose_set_options';
	params['reskey'] = reskey_static;
	theForm = document.forms["firehoseform"];
	if (name == "firehose_usermode") {
		if (value ==  true) {
			value = 1;
		}
		if (value == false) {
			value = 0;
		}
		params['setusermode'] = 1;
		params[name] = value;
	}

	if (name == "nodates" || name == "nobylines") {
		value = value == true ? 1 : 0;
		params[name] = value;
		params['setfield'] = 1;
		var classname;
		if (name == "nodates") {
			classname = "date";
		} else if (name == "nobylines") {
			classname = "nickname";
		}

		var els = document.getElementsByClassName(classname, $('firehoselist'));
		var classval = classname;
		if (value) {
			classval = classval + " hide";
		}
		for (i = 0; i< els.length; i++) {
			els[i].className = classval;
		}
	}

	if (name == "fhfilter") {
		for (i=0; i< theForm.elements.length; i++) {
			if (theForm.elements[i].name == "fhfilter") {
				params['fhfilter'] = theForm.elements[i].value;
			}
		}
	}
	if (name != "color") {
	for (i=0; i< pairs.length; i++) {
		var el = pairs[i];
		if (name == el[0] && value == el[1]) {
			params[name] = value;
			if ($(el[2])) {
				$(el[2]).id = el[3];
				if($(el[3])) {
					var namenew = el[0];
					var valuenew = el[4];
					$(el[3]).firstChild.onclick = function() { firehose_set_options(namenew, valuenew); return false;}
				}
			}
		}
	}
	if (name == "mode" || name == "firehose_usermode" || name == "tab") {
		// blur out then remove items
		if (name == "mode") {
			fh_view_mode = value;
		}
		if ($('firehoselist')) {
			// set page
			page = 0;
			var attributes = { 
				 opacity: { from: 1, to: 0 }
			};
			var myAnim = new YAHOO.util.Anim("firehoselist", attributes); 
			myAnim.duration = 1;
			myAnim.onComplete.subscribe(function() {
				$('firehoselist').style.opacity = "1";
			});
			myAnim.animate();
			// remove elements
			setTimeout("firehose_remove_all_items()", 600);
		}
	}
	}

	if (name == "color" || name == "tab" || name == "pause" || name == "startdate" || name == "duration" ) { 
		params[name] = [value];
	}

	var handlers = {
		onComplete: function(transport) { 
			json_handler(transport);
			firehose_get_updates({ oneupdate: 1 });
		}
	};
	ajax_update(params, '', handlers);
}

function firehose_remove_all_items() {
	var fhl = $('firehoselist');
	var children = fhl.childNodes;
	for (var i = children.length -1 ; i >= 0; i--) {
		var el = children[i];
		if (el.id) {
			el.parentNode.removeChild(el);
		}
	}
}


function firehose_up_down(id, dir) {
	setFirehoseAction();
	var params = [];
	var handlers = {
		onComplete: json_handler
	};
	params['op'] = 'firehose_up_down';
	params['id'] = id;
	params['reskey'] = reskey_static;
	params['dir'] = dir;
	var updown = $('updown-' + id);
	ajax_update(params, '', handlers);
	if (dir == "-" && fh_is_admin) {
		firehose_collapse_entry(id);
	}
}

function firehose_remove_tab(tabid) {
	setFirehoseAction();
	var params = [];
	var handlers = {
		onComplete:  json_handler
	};
	params['op'] = 'firehose_remove_tab';
	params['tabid'] = tabid;
	params['reskey'] = reskey_static;
	ajax_update(params, '', handlers);

}
// firehose functions end

// helper functions
function ajax_update(params, onsucc, options, url) {
	var h = $H(params);

	if (!url)
		url = '/ajax.pl';

	if (!options)
		options = {};

	options.method = 'post';
	options.parameters = h.toQueryString();

	var ajax = new Ajax.Updater(
		{ success: onsucc },
		url,
		options
	);
}

function ajax_periodic_update(secs, params, onsucc, options, url) {
	var h = $H(params);
	
	if (!url) 
		url = '/ajax.pl';
		
	if (!options)
		options = {};

	options.frequency = secs;
	options.method = 'post';
	options.parameters = h.toQueryString();

	var ajax = new Ajax.PeriodicalUpdater({ success: onsucc }, url, options);
}

function eval_response(transport) {
	var response;
	try {
		eval("response = " + transport.responseText)
	} catch (e) {
		//alert(e + "\n" + transport.responseText)
	}
	return response;
}

function json_handler(transport) {
	var response = eval_response(transport);
	json_update(response);
}

function json_update(response) {
	if (response.eval_first) {
		try {
			eval(response.eval_first)
		} catch (e) {

		}
	}

 	if (response.html) {
		for (el in response.html) {
			if ($(el))
				$(el).innerHTML = response.html[el];
		}
		
	} 

	if (response.value) {
		for (el in response.value) {
			if ($(el))
				$(el).value = response.value[el];
		}
	}

	if (response.html_append) {
		for (el in response.html_append) {
			if ($(el))
				$(el).innerHTML = $(el).innerHTML + response.html_append[el];
		}
	}

	if (response.html_append_substr) {
		for (el in response.html_append_substr) {
			if ($(el)) {
				var this_html = $(el).innerHTML;
				var i = $(el).innerHTML.search(/<span class="substr"> <\/span>[\s\S]*$/i);
				if (i == -1) {
					$(el).innerHTML += response.html_append_substr[el];
				} else {
					$(el).innerHTML = $(el).innerHTML.substr(0, i) +
						response.html_append_substr[el];
				}
			}
		}
	}		
	
	if (response.eval_last) {
		try {
			eval(response.eval_last)
		} catch (e) {

		}
	}
}


function firehose_handle_update() {
	if (firehose_updates.length > 0) {
		var el = firehose_updates.pop();
		var fh = 'firehose-' + el[1];
		var wait_interval = 800;
		if(el[0] == "add") {
			if (firehose_before[el[1]] && $('firehose-' + firehose_before[el[1]])) {
				new Insertion.After('firehose-' + firehose_before[el[1]], el[2]);
			} else if (firehose_after[el[1]] && $('firehose-' + firehose_after[el[1]])) {
				new Insertion.Before('firehose-' + firehose_after[el[1]], el[2]);
			} else if (insert_new_at == "bottom") {
				new Insertion.Bottom('firehoselist', el[2]);
			} else {
				new Insertion.Top('firehoselist', el[2]);
			}
		
			var toheight = 50;
			if (fh_view_mode == "full") {
				toheight = 200;
			}

			var attributes = { 
				 opacity: { from: 0, to: 1 },
				 height: { from: 0, to: toheight }
			};
			var myAnim = new YAHOO.util.Anim(fh, attributes); 
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
				if ($(fh)) {
					$(fh).style.height = "";
				}
			});
			myAnim.animate();
		} else if (el[0] == "remove") {
			var fh_node = $(fh);
			if (fh_is_admin && fh_view_mode == "fulltitle" && fh_node && fh_node.className == "article" ) {
				// Don't delete admin looking at this in expanded view
			} else {
				var attributes = { 
					 height: { to: 0 },
					 opacity: { to: 0}
				};
				var myAnim = new YAHOO.util.Anim(fh, attributes); 
				myAnim.duration = 0.4;
				wait_interval = 500;
				
				if (firehose_updates_size > 10) {
					myAnim.duration = myAnim.duration * 2;
					if (!firehose_removed_first) {
						wait_interval = wait_interval * 2;
					} else {
						wait_interval = 20;
					}
				}
				firehose_removed_first = 1;
				myAnim.onComplete.subscribe(function() {
					var elem = this.getEl();
					if (elem && elem.parentNode) {
						elem.parentNode.removeChild(elem);
					}
				});
				myAnim.animate(); 
			}
		}
		setTimeout("firehose_handle_update()", wait_interval);
	} else {
		firehose_reorder();
		firehose_get_next_updates();
	}
}

function firehose_reorder() {
	if (firehose_ordered) {
		var fhlist = $('firehoselist');
		if (fhlist) {
			var item_count = 0;
			for (i = 0; i < firehose_ordered.length; i++) {
				if (/^\d+$/.test(firehose_ordered[i])) {
					item_count++;
				}
				var fhel = $('firehose-' + firehose_ordered[i]);
				if (fhlist && fhel) {
					fhlist.appendChild(fhel);
				}
				if ( firehose_future[firehose_ordered[i]] ) {
					if ($("ttype-" + firehose_ordered[i])) {
						$("ttype-" + firehose_ordered[i]).className = "future";	
					}
				} else {
					if ($("ttype-" + firehose_ordered[i]) && $("ttype-" + firehose_ordered[i]).className == "future") {
						$("ttype-" + firehose_ordered[i]).className = "story";	
					}
				}
			}
			if (console_updating) {
				document.title = "Console (" + item_count + ")";
			} else {
				document.title = "Firehose (" + item_count + ")";
			}
		}
	}

}

function firehose_get_next_updates() {
	var interval = getFirehoseUpdateInterval();
	//alert("fh_get_next_updates");
	fh_is_updating = 0;
	firehose_add_update_timerid(setTimeout("firehose_get_updates()", interval));
}


function firehose_get_updates_handler(transport) {
	$('busy').className = "hide";
	var response = eval_response(transport);
	var processed = 0;
	firehose_ordered = response.ordered;
	firehose_future = response.future;
	firehose_before = Array(0);
	firehose_after = Array(0);
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
	var fhl = $('firehoselist');
	var children = fhl.childNodes;
	var str = "";
	var id;
	for (var i = 0; i < children.length; i++) {
		if (children[i].id) {
			id = children[i].id;
			id = id.replace(/^firehose-/g, "");
			id = id.replace(/^\s+|\s+$/g, "");
			str = str + id + ",";
		}
	}
	return str;
}


function firehose_get_updates(options) {
	options = options || {};
	run_before_update();
	if ((fh_play == 0 && !options.oneupdate) || fh_is_updating == 1) {
		firehose_add_update_timerid(setTimeout("firehose_get_updates()", 2000));
		//alert("wait loop: " + fh_is_updating);
		return;
	}
	if (fh_update_timerids.length > 0) {
		var id = 0;
		while(id = fh_update_timerids.pop()) { clearTimeout(id) };
	}
	fh_is_updating = 1
	var params = [];
	var handlers = {
		onComplete: firehose_get_updates_handler
	};
	params['op'] = 'firehose_get_updates';
	params['ids'] = firehose_get_item_idstring();
	params['updatetime'] = update_time;
	params['startdate'] = firehose_startdate;
	params['issue'] = firehose_issue;
	params['page'] = page;
	params['fh_pageval'] = fh_pageval;
	$('busy').className = "";
	ajax_update(params, '', handlers);
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
			console_update(1, 0)
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
		if ($('message_area'))
			$('message_area').innerHTML = "Automatic updates have been slowed due to inactivity";
		//firehose_pause();
	}
}

function firehose_play() {
	fh_play = 1;
	setFirehoseAction();
	firehose_set_options('pause', '0');
	if ($('message_area'))
		$('message_area').innerHTML = "";
	if ($('pauseorplay'))
		$('pauseorplay').innerHTML = "Updating";
	var pause = $('pause');
	
	var play_div = $('play');
	play_div.className = "hide";
	pause.className = "show";
}

function firehose_pause() {
	fh_play = 0;
	var pause = $('pause');
	var play_div = $('play');
	pause.className = "hide";
	play_div.className = "show";
	if ($('pauseorplay'))
		$('pauseorplay').innerHTML = "Paused";
	firehose_set_options('pause', '1');
}

function firehose_add_update_timerid(timerid) {
	fh_update_timerids.push(timerid);		
}

function firehose_collapse_entry(id) {
	var fhbody = $('fhbody-'+id);
	var fh = $('firehose-'+id);
	if (fhbody.className == "body") {
		fhbody.className = "hide";
		fh.className = "briefarticle";
	}	
	tagsHideBody(id)

}

function firehose_remove_entry(id) {
	var fh = $('firehose-' + id);
	if (fh) {
		var attributes = { 
			 height: { to: 0 },
			 opacity: { to: 0 }
		};
		var myAnim = new YAHOO.util.Anim(fh, attributes); 
		myAnim.duration = 0.5;
		myAnim.onComplete.subscribe(function() {
		    var el = this.getEl();
		        el.parentNode.removeChild(el);
		});
		myAnim.animate();
	}
}

var firehose_cal_select_handler = function(type,args,obj) { 
	var selected = args[0];
  firehose_set_options('startdate', selected.startdate);
  firehose_set_options('duration', selected.duration);
}; 


function firehose_calendar_init( widget ) {
	widget.selectEvent.subscribe(firehose_cal_select_handler, widget, true);
}

function firehose_slider_init() {
	fh_colorslider = YAHOO.widget.Slider.getHorizSlider("colorsliderbg", "colorsliderthumb", 0, 105, fh_ticksize);
	fh_colorslider.setValue(fh_ticksize * fh_colors_hash[fh_color] , 1);
        fh_colorslider.subscribe("slideEnd", firehose_slider_end);
}	

function firehose_slider_set_color(color) {
	fh_colorslider.setValue(fh_ticksize * fh_colors_hash[color] , 1);
}

function firehose_slider_end(offsetFromStart) {
	var newVal = fh_colorslider.getValue();
	var color = fh_colors[ newVal / fh_ticksize ];
	$('fh_slider_img').title = "Firehose filtered to " + color;
	if(fh_slider_init_set) {
	 	firehose_set_options("color", color)
	}
	fh_slider_init_set = 1;
}

function pausePopVendorStory(id) {
	vendor_popup_id=id;
	closePopup('vendorStory-26-popup');
	vendor_popup_timerids[id] = setTimeout("vendorStoryPopup()", 500);
}

function clearVendorPopupTimers() {
	clearTimeout(vendor_popup_timerids[26]);
}

function vendorStoryPopup() {
	id = vendor_popup_id;
	var title = "<a href='//intel.vendors.slashdot.org' onclick=\"javascript:urchinTracker('/vendor_intel-popup/intel_popup_title');\">Intel's Opinion Center</a>";
	var buttons = createPopupButtons("<a href=\"javascript:closePopup('vendorStory-" + id + "-popup')\">[X]</a>");
	title = title + buttons;
	var closepopup = function (e) {
	if (!e) var e = window.event;
	var relTarg = e.relatedTarget || e.toElement;
	if (relTarg && relTarg.id == "vendorStory-26-popup") {
		closePopup("vendorStory-26-popup");
	}
	};
	createPopup(getXYForId('sponsorlinks', 0, 0), title, "vendorStory-" + id, "Loading", "", closepopup );
	var params = [];
	params['op'] = 'getTopVendorStory';
	params['skid'] = id;
	ajax_update(params, "vendorStory-" + id + "-contents");
}

function pausePopVendorStory2(id) {
        vendor_popup_id=id;
        closePopup('vendorStory-26-popup');
        vendor_popup_timerids[id] = setTimeout("vendorStoryPopup2()", 500);
}

function vendorStoryPopup2() {
        id = vendor_popup_id;
        var title = "<a href='//intel.vendors.slashdot.org' onclick=\"javascript:urchinTracker('/vendor_intel-popup/intel_popup_title');\">Intel's Opinion Center</a>";
        var buttons = createPopupButtons("<a href=\"javascript:closePopup('vendorStory-" + id + "-popup')\">[X]</a>");
        title = title + buttons;
        var closepopup = function (e) {
        if (!e) var e = window.event;
        var relTarg = e.relatedTarget || e.toElement;
        if (relTarg && relTarg.id == "vendorStory-26-popup") {
                closePopup("vendorStory-26-popup");
        }
        };
        createPopup(getXYForId('sponsorlinks2', 0, 0), title, "vendorStory-" + id, "Loading", "", closepopup );
        var params = [];
        params['op'] = 'getTopVendorStory';
        params['skid'] = id;
        ajax_update(params, "vendorStory-" + id + "-contents");
}

function logToDiv(id, message) {
	var div = $(id);
	if (div) {
	div.innerHTML = div.innerHTML + message + "<br>";
	}
}


function firehose_open_tab(id) {
	var tf = $('tab-form-'+id);
	var tt = $('tab-text-'+id);
	var ti = $('tab-input-'+id);
	tf.className="";
	ti.focus();
	tt.className="hide";
}

function firehose_save_tab(id) {
	var tf = $('tab-form-'+id);
	var tt = $('tab-text-'+id);
	var ti = $('tab-input-'+id);
	var params = [];
	var handlers = {
		onComplete: json_handler 
	};
	params['op'] = 'firehose_save_tab';
	params['tabname'] = ti.value;

	params['tabid'] = id;
	ajax_update(params, '',  handlers);
	tf.className = "hide";
	tt.className = "";
}

