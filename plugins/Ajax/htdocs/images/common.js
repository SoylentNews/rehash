// $Id$

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

function tagsToggleStoryDiv(stoid, is_admin) {
	var bodyid = 'toggletags-body-' + stoid;
        var tagsbody = $(bodyid);
	if (tagsbody.className == 'tagshide') {
		tagsShowBody(stoid, is_admin);
	} else {
		tagsHideBody(stoid);
	}
}

function tagsHideBody(stoid) {
	var tagsbodyid = 'toggletags-body-' + stoid;
	var tagsbuttonid = 'toggletags-button-' + stoid;
        var tagsbody = $(tagsbodyid);
        var tagsbutton = $(tagsbuttonid);
	tagsbody.className = "tagshide"
	tagsbutton.innerHTML = "[+]";
}

function tagsShowBody(stoid, is_admin) {
	// Toggle the button to show the click was received
	var tagsbuttonid = 'toggletags-button-' + stoid;
        var tagsbutton = $(tagsbuttonid);
	tagsbutton.innerHTML = "[-]";

	// Make the body of the tagbox visible
	var tagsbodyid = 'toggletags-body-' + stoid;
        var tagsbody = $(tagsbodyid);
	tagsbody.className = "tags";

	// If the tags-user div hasn't been filled, fill it.
	var tagsuserid = 'tags-user-' + stoid;
	var tagsuser = $(tagsuserid);
	if (tagsuser.innerHTML == "") {
		// The tags-user-123 div is empty, and needs to be
		// filled with the tags this user has already
		// specified for this story, and a reskey to allow
		// the user to enter more tags.
		tagsuser.innerHTML = "Retrieving...";
		var url = '/ajax.pl';
		var params = [];
		params['op'] = 'tags_get_user_story';
		params['stoid'] = stoid;
		ajax_update(params, tagsuserid);

		// Also fill the admin div.  Note that if the user
		// is not an admin, this call will not actually
		// return the necessary form (which couldn't be
		// submitted anyway).  The is_admin parameter just
		// saves us an ajax call to find that out, if the
		// user is not actually an admin.
		if (is_admin) {
			var tagsadminid = 'tags-admin-' + stoid;
			params = [];
			params['op'] = 'tags_get_admin_story';
			params['stoid'] = stoid;
			ajax_update(params, tagsadminid);
		}

	}
}

function tagsOpenAndEnter(stoid, tagname) {
	// This does nothing if the body is already shown.
	tagsShowBody(stoid);

	var textinputid = 'newtags-' + stoid;
	var textinput = $(textinputid);
	textinput.value = textinput.value + ' ' + tagname;
}

function reportError(request) {
	// replace with something else
	alert("error");
}

function tagsCreateForStory(stoid) {
	var toggletags_message_id = 'toggletags-message-' + stoid;
	var toggletags_message_el = $(toggletags_message_id);
	toggletags_message_el.innerHTML = 'Saving tags...';

	var params = [];
	params['op'] = 'tags_create_for_story';
	params['stoid'] = stoid;
	var newtagsel = $('newtags-' + stoid);
	params['tags'] = newtagsel.value;
	var reskeyel = $('newtags-reskey-' + stoid);
	params['reskey'] = reskeyel.value;

	ajax_update(params, 'tags-user-' + stoid);

	// XXX How to determine failure here?
	toggletags_message_el.innerHTML = 'Tags saved.';
}


// helper functions

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

