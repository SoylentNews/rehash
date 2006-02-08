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

function tagsToggleStoryDiv(stoid) {
	var bodyid = 'toggletags-body-' + stoid;
        var tagsbody = $(bodyid);
	if (tagsbody.className == 'tagshide') {
		tagsShowBody(stoid);
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

function tagsShowBody(stoid) {
	var tagsbodyid = 'toggletags-body-' + stoid;
	var tagsbuttonid = 'toggletags-button-' + stoid;
	var tagsuserid = 'tags-user-' + stoid;
        var tagsbody = $(tagsbodyid);
        var tagsbutton = $(tagsbuttonid);
	var tagsuser = $(tagsuserid);
	tagsbody.className = "tags"
	tagsbutton.innerHTML = "[-]";
	if (tagsuser.innerHTML == "") {
		// The tags-user-123 div is empty, and needs to be
		// filled with the tags this user has already
		// specified for this story.
		tagsuser.innerHTML = "Retrieving...";
		var url = '/ajax.pl';
		var params = [];
		params['op'] = 'tagsGetUserStory';
		params['stoid'] = stoid;
		var h = $H(params);
		var ajax = new Ajax.Updater(
			{ success: tagsuserid },
			url,
			{ method: 'post', parameters: h.toQueryString(), onFailure: reportError }
		);
	}
}

function tagsOpenAndEnter(stoid, tagname) {
	var bodyid = 'toggletags-body-' + stoid;
	var buttonid = 'toggletags-button-' + stoid;
        var body = $(bodyid);
        var button = $(buttonid);
        if (body.className == 'tagshide') {
                body.className = "tags"
                button.innerHTML = "[-]";
        }

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
	toggletags_message_el.innnerHTML = 'Saving tags...';

	var params = [];
	params['op'] = 'tagsCreateForStory';
	params['stoid'] = stoid;
	var newtagsel = $('newtags-' + stoid);
	params['tags'] = newtagsel.value;

	ajax_update(params, toggletags_message_id);
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

