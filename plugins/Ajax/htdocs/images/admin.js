function adminStorySignoff(el) {
	url = "ajax.pl";
	var params = [];
	params['op'] = 'storySignOff';
	params['stoid'] = el.value;
	var h = $H(params);
	
	var ajax = new Ajax.Updater(
		{ success: 'signoff_' + el.value },
		url,
		{ method: 'post', parameters: h.toQueryString() }
	);
	
}
