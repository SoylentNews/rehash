function toggleIntro(id, toggleid) {
	var obj = document.getElementById(id);
	var toggle = document.getElementById(toggleid);
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
        var tagsbody = document.getElementById(bodyid);
	if (tagsbody.className == 'tagshide') {
		tagsShowBody(stoid);
	} else {
		tagsHideBody(stoid);
	}
}

function tagsHideBody(stoid) {
	var tagsbodyid = 'toggletags-body-' + stoid;
	var tagsbuttonid = 'toggletags-button-' + stoid;
        var tagsbody = document.getElementById(tagsbodyid);
        var tagsbutton = document.getElementById(tagsbuttonid);
	tagsbody.className = "tagshide"
	tagsbutton.innerHTML = "[+]";
}

function tagsShowBody(stoid) {
	var tagsbodyid = 'toggletags-body-' + stoid;
	var tagsbuttonid = 'toggletags-button-' + stoid;
	var tagsuserid = 'tags-user-' + stoid;
        var tagsbody = document.getElementById(tagsbodyid);
        var tagsbutton = document.getElementById(tagsbuttonid);
	var tagsuser = document.getElementById(tagsuserid);
	tagsbody.className = "tags"
	tagsbutton.innerHTML = "[-]";
	if (tagsuser.innerHTML == "") {
		// The tags-user-123 div is empty, and needs to be
		// filled with the tags this user has already
		// specified for this story.
		tagsuser.innerHTML = "Retrieving...";
		var url = 'ajax.pl';
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
        var body = document.getElementById(bodyid);
        var button = document.getElementById(buttonid);
        if (body.className == 'tagshide') {
                body.className = "tags"
                button.innerHTML = "[-]";
        }

	var textinputid = 'newtags-' + stoid;
	var textinput = document.getElementById(textinputid);
	textinput.value = textinput.value + ' ' + tagname;
}

function reportError(request) {
	// replace with something else
	alert("error");
}

function tagsCreateForStory(stoid) {
	url = "ajax.pl";

	var toggletags_message_id = 'toggletags-message-' + stoid;
	var toggletags_message_el = document.getElementById(toggletags_message_id);
	toggletags_message_el.innnerHTML = 'Saving tags...';

	var params = [];
	params['op'] = 'tagsCreateForStory';
	params['stoid'] = stoid;
	var newtagsel = document.getElementById('newtags-' + stoid);
	params['tags'] = newtagsel.value;
	var h = $H(params);
	
	var ajax = new Ajax.Updater(
		{ success: toggletags_message_id },
		url,
		{ method: 'post', parameters: h.toQueryString() } );
}

