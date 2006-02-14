// $Id$

function admin_signoff(el) {
	var params = [];
	params['op'] = 'admin_signoff';
	params['stoid'] = el.value;
	ajax_update(params, 'signoff_' + el.value);
	
}

function adminTagsCommands(stoid) {
	var toggletags_message_id = 'toggletags-message-' + stoid;
	var toggletags_message_el = $(toggletags_message_id);
	toggletags_message_el.innerHTML = 'Executing commands...';

	var params = [];
	params['op'] = 'tags_admin_commands';
	params['stoid'] = stoid;
	var tags_admin_commands_el = $('tags_admin_commands-' + stoid);
	params['commands'] = tags_admin_commands_el.value;
	var reskeyel = $('admin_commands-reskey-' + stoid);
	params['reskey'] = reskeyel.value;
	ajax_update(params, 'tags-admin-' + stoid);

	toggletags_message_el.innerHTML = 'Commands executed.';
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
	remarks_max = $('remarks_max');
	if (remarks_max && remarks_max.value) {
		params['limit'] = remarks_max.value;
	}
	ajax_update(params, 'remarks_whole');
}

function remarks_fetch(secs, limit) {
	var params = [];
	params['op'] = 'remarks_fetch';
	// this not being used? -- pudge
	remarks_max = $('remarks_max');
	params['limit'] = limit;
	// run it every 30 seconds; don't need to call again
	ajax_periodic_update(secs, params, 'remarks_table');
}

