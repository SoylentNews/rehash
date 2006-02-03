function adminStorySignoff(el) {
	url = '/ajax.pl';
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

	ajax_submit(params, 'remarks_table');

	remark.value = '';

	return false;
}

function remarks_fetch() {
	var reskey = $('remarks_reskey');
	if (!reskey || !reskey.value) {
		return false;
	}

	var params = [];
	params['op']     = 'remarks_fetch';
	params['reskey'] = reskey.value;

	ajax_submit(params, 'remarks_table');

	// reset timer
	run_timer('remarks_fetch()', 30);

	return false;
}

// put below in common.js? -- pudge

// call this once from your HTML, then again at end of JS routine being
// called, to have it continually refreshing
function run_timer(func, secs) {
	setTimeout(func, (secs * 1000));
}


function ajax_submit(params, div, url) {
	var h = $H(params);
	if (!url) {
		url = '/ajax.pl';
	}
	
	var ajax = new Ajax.Updater(
		{ success: div },
		url,
		{ method: 'post', parameters: h.toQueryString() }
	);
}

