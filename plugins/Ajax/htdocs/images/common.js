// $Id$

function createPopup(xy, titlebar, name, contents, message) {
	var body = document.getElementsByTagName("body")[0]; 
	var div = document.createElement("div");
	div.id = name + "-popup";
	div.style.position = "absolute";
	
	var leftpos = xy[0] + "px";
	var toppos  = xy[1] + "px";
	
	div.style.left = leftpos;
	div.style.top = toppos;
	div.style.zIndex = "100";
	contents = contents || "";
	message  = message || "";

	div.innerHTML = '<div id="' + name + '-title" class="popup-title">' + titlebar + '</div>' +
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

function toggleIntro(id, toggleid) {
	var obj = $(id);
	var toggle = $(toggleid);
	if (obj.className == 'introhide') {
		obj.className = "intro"
		toggle.innerHTML = "[-]";
	} else {
		obj.className = "introhide"
		toggle.innerHTML = "[+]";
	}
}

function tagsToggleStoryDiv(sidenc, is_admin) {
	var bodyid = 'toggletags-body-' + sidenc;
        var tagsbody = $(bodyid);
	if (tagsbody.className == 'tagshide') {
		tagsShowBody(sidenc, is_admin, '');
	} else {
		tagsHideBody(sidenc);
	}
}

function tagsHideBody(sidenc) {
	// Make the body of the tagbox vanish
	var tagsbodyid = 'toggletags-body-' + sidenc;
        var tagsbody = $(tagsbodyid);
	tagsbody.className = "tagshide"

	// Make the title of the tagbox change back to regular
	var titleid = 'tagbox-title-' + sidenc;
        var title = $(titleid);
	title.className = "tagtitleclosed";

	// Make the tagbox change back to regular.
	var tagboxid = 'tagbox-' + sidenc;
        var tagbox = $(tagboxid);
	tagbox.className = "tags";

	// Toggle the button back.
	var tagsbuttonid = 'toggletags-button-' + sidenc;
        var tagsbutton = $(tagsbuttonid);
	tagsbutton.innerHTML = "[+]";
}

function tagsShowBody(sidenc, is_admin, newtagspreloadtext) {
	// Toggle the button to show the click was received
	var tagsbuttonid = 'toggletags-button-' + sidenc;
        var tagsbutton = $(tagsbuttonid);
	tagsbutton.innerHTML = "[-]";

	// Make the tagbox change to the slashbox class
	var tagboxid = 'tagbox-' + sidenc;
        var tagbox = $(tagboxid);
	tagbox.className = "tags";

	// Make the title of the tagbox change to white-on-green
	var titleid = 'tagbox-title-' + sidenc;
        var title = $(titleid);
	title.className = "tagtitleopen";

	// Make the body of the tagbox visible
	var tagsbodyid = 'toggletags-body-' + sidenc;
        var tagsbody = $(tagsbodyid);
	
	tagsbody.className = "tagbody";
	
	// If the tags-user div hasn't been filled, fill it.
	var tagsuserid = 'tags-user-' + sidenc;
	var tagsuser = $(tagsuserid);
	if (tagsuser.innerHTML == "") {
		// The tags-user-123 div is empty, and needs to be
		// filled with the tags this user has already
		// specified for this story, and a reskey to allow
		// the user to enter more tags.
		tagsuser.innerHTML = "Retrieving...";
		var params = [];
		params['op'] = 'tags_get_user_story';
		params['sidenc'] = sidenc;
		params['newtagspreloadtext'] = newtagspreloadtext
		ajax_update(params, tagsuserid);

		// Also fill the admin div.  Note that if the user
		// is not an admin, this call will not actually
		// return the necessary form (which couldn't be
		// submitted anyway).  The is_admin parameter just
		// saves us an ajax call to find that out, if the
		// user is not actually an admin.
		if (is_admin) {
			var tagsadminid = 'tags-admin-' + sidenc;
			params = [];
			params['op'] = 'tags_get_admin_story';
			params['sidenc'] = sidenc;
			ajax_update(params, tagsadminid);
		}

	} else {
		if (newtagspreloadtext) {
			// The box was already open but it was requested
			// that we append some text to the user text.
			// We can't do that by passing it in, so do it
			// manually now.
			var textinputid = 'newtags-' + sidenc;
			var textinput = $(textinputid);
			textinput.value = textinput.value + ' ' + newtagspreloadtext;
		}
	}
}

function tagsOpenAndEnter(sidenc, tagname, is_admin) {
	// This does nothing if the body is already shown.
	tagsShowBody(sidenc, is_admin, tagname);
}

function reportError(request) {
	// replace with something else
	alert("error");
}

function tagsCreateForStory(sidenc) {
	var toggletags_message_id = 'toggletags-message-' + sidenc;
	var toggletags_message_el = $(toggletags_message_id);
	toggletags_message_el.innerHTML = 'Saving tags...';

	var params = [];
	params['op'] = 'tags_create_for_story';
	params['sidenc'] = sidenc;
	var newtagsel = $('newtags-' + sidenc);
	params['tags'] = newtagsel.value;
	var reskeyel = $('newtags-reskey-' + sidenc);
	params['reskey'] = reskeyel.value;

	ajax_update(params, 'tags-user-' + sidenc);

	// XXX How to determine failure here?
	toggletags_message_el.innerHTML = 'Tags saved.';
}

// helper functions
function ajax_eval(params, onsucc, onfail, url) {
	var h = $H(params);
	if (!url) {
		url = '/ajax.pl';
	}
	
	var ajax = new Ajax.Updater(
		{
			success: onsucc,
			failure: onfail
		},
		url,
		{
			method:		'post',
			parameters:	h.toQueryString(),
			evalScripts:	1
		}
	);
}


function ajax_update(params, onsucc, onfail, url) {
	var h = $H(params);
	if (!url) {
		url = '/ajax.pl';
	}
	
	var ajax = new Ajax.Updater(
		{
			success: onsucc,
			failure: onfail
		},
		url,
		{
			method:		'post',
			parameters:	h.toQueryString()
		}
	);
}

// function ajax_update_sync(params, onsucc, onfail, url) {
// 	var h = $H(params);
// 	if (!url) {
// 		url = '/ajax.pl';
// 	}
// 	
// 	var ajax = new Ajax.Updater(
// 		{
// 			success: onsucc,
// 			failure: onfail
// 		},
// 		url,
// 		{
// 			method:		'post',
// 			parameters:	h.toQueryString(),
// 			asynchronous:	false
// 		}
// 	);
// }

function ajax_periodic_update(secs, params, onsucc, onfail, url) {
	var h = $H(params);
	if (!url) {
		url = '/ajax.pl';
	}
	
	var ajax = new Ajax.PeriodicalUpdater(
		{
			success: onsucc,
			failure: onfail
		},
		url,
		{
			method:		'post',
			parameters:	h.toQueryString(),
			frequency:	secs
		}
	);
}

