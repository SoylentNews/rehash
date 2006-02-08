// $Id$

function adminStorySignoff(el) {
	var params = [];
	params['op'] = 'storySignOff';
	params['stoid'] = el.value;
	ajax_update(params, 'signoff_' + el.value);
	
}

function adminTagsCommands(stoid) {
	var params = [];
	params['op'] = 'adminTagsCommands';
	params['stoid'] = stoid;
	ajax_update(params, 'toggletags-message-' + stoid);
}


function remarks_create() {
	var reskey = $('remarks_reskey');
	var remark = $('remarks_new');
	if (!remark || !remark.value || !reskey || !reskey.value) {
		return false;
	}

	var params = [];
	params['op']     = 'remarks_create';
	params['remark'] = remark.value;
	params['reskey'] = reskey.value;

	ajax_update(params, 'remarks_whole');
}

function remarks_fetch(secs) {
	var params = [];
	params['op'] = 'remarks_fetch';
	// run it every 30 seconds; don't need to call again
	ajax_periodic_update(secs, params, 'remarks_table');
}

