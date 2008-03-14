// $Id$

function um_ajax(the_behaviors, the_events) {
	var params = {};
	params['op'] = 'um_ajax';
	params['behaviors'] = the_behaviors;
	params['events'] = the_events;
	ajax_update(params, 'links-vendors-content');
}

function um_fetch_settings() {
	var params = {};
	params['op'] = 'um_fetch_settings';
	ajax_update(params, 'links-vendors-content');
}

function um_set_settings(behavior) {
	var params = {};
	params['op'] = 'um_set_settings';
	params['behavior'] = behavior;
	ajax_update(params, 'links-vendors-content');
}

function admin_signoff(stoid, type, id) {
	var params = {};
	var reskeyel = $dom('signoff-reskey-' + stoid);
	params['op'] = 'admin_signoff';
	params['stoid'] = stoid;
	params['reskey'] = reskeyel.value;
	ajax_update(params, 'signoff_' + stoid);
	if (type == "firehose") {
		firehose_collapse_entry(id);
	}
}

function admin_neverdisplay(stoid, type, fhid) {
	var params = {};
	params['op'] = 'admin_neverdisplay';
	params['reskey'] = reskey_static;
	params['stoid'] = stoid;
	params['fhid'] = fhid;
	if (confirm("Set story to neverdisplay?")) {
		ajax_update(params, 'nvd-' + stoid);
		if (type == "firehose") {
			firehose_remove_entry(fhid);
		}
	}
}

function admin_submit_memory(fhid) {
	var params = {};
	params['op'] = 'admin_submit_memory';
	params['reskey'] = reskey_static;
	params['submatch'] = $dom('submatch-'+fhid).value;
	params['subnote'] = $dom('subnote-'+fhid).value;
	ajax_update(params, 'sub_mem_message-'+fhid);
}

function adminTagsCommands(id, type) {
	var toggletags_message_id = '#toggletags-message-' + id;
	var toggletags_message_el = jQuery(toggletags_message_id)[0];
	if (toggletags_message_el) {
		toggletags_message_el.innerHTML = 'Executing commands...';
	}

	var params = {};
	type = type || "stories";
	params['op'] = 'tags_admin_commands';
	if (type == "stories") {
		params['sidenc'] = id;
	} else if (type == "urls") {
		params['id'] = id;
	} else if (type == "firehose") {
		params['id'] = id;
	}
	params['type'] = type;
	var tags_admin_commands_el = $dom('tags_admin_commands-' + id);
	params['commands'] = tags_admin_commands_el.value;
	var reskeyel = $dom('admin_commands-reskey-' + id);
	params['reskey'] = reskeyel.value;
	ajax_update(params, 'tags-admin-' + id);

	toggletags_message_el.innerHTML = 'Commands executed.';
}

function tagsHistory(id, type) {
	var params = {};
	type = type || "stories";
	params['type'] = type;
	params['op'] = 'tags_history';
	if (type == "stories") {
		params['sidenc'] = id;
	} else if (type == "urls" || type == "firehose") {
		params['id'] = id;
	}
	var tagshistid = "taghist-" + id;
	var popupid    = "taghistory-" + id;
	var title      = "History ";
	var buttons    = createPopupButtons("<a href=\"#\" onclick=\"return false\">[?]</a></span><span><a href=\"#\" onclick=\"closePopup('" + popupid + "-popup'); return false\">[X]</a>");
	title = title + buttons;
	createPopup(getXYForId(tagshistid), title, popupid);
	ajax_update(params, "taghistory-" + id + "-contents");
}

function remarks_create() {
	var reskey = $dom('remarks_reskey');
	var remark = $dom('remarks_new');
	if (!remark || !remark.value || !reskey || !reskey.value) {
		return false;
	}

	var params = {};
	params['op']     = 'remarks_create';
	params['remark'] = remark.value;
	params['reskey'] = reskey.value;
	remarks_max = $dom('remarks_max');
	if (remarks_max && remarks_max.value) {
		params['limit'] = remarks_max.value;
	}
	ajax_update(params, 'remarks_whole');
}

function remarks_fetch(secs, limit) {
	var params = {};
	params['op'] = 'remarks_fetch';
	params['limit'] = limit;
	// run it every 30 seconds; don't need to call again
	ajax_periodic_update(secs, params, 'remarks_table');
}

function remarks_popup() {
	var params = {};
	params['op'] = 'remarks_config';
	var title = "Remarks Config ";
	var buttons = createPopupButtons('<a href="#" onclick="closePopup(\'remarksconfig-popup\', 1); return false">[X]</a>');
	title = title + buttons;
	createPopup(getXYForId('remarks_table'), title + buttons, 'remarksconfig');
	ajax_update(params, 'remarksconfig-contents');
	
}

function remarks_config_save() {
	var params = {};
	var reskey = $dom('remarks_reskey');
	var min_priority = $dom('remarks_min_priority');
	var limit = $dom('remarks_limit');
	var filter = $dom('remarks_filter');
	params['op'] = 'remarks_config_save';
	if (!reskey && !reskey.value) {
		return false;
	} 
	if (min_priority) {
		params['min_priority'] = min_priority.value;
	}
	if (limit) {
		params['limit'] = limit.value;
	}
	if (filter) {
		params['filter'] = filter.value;
	}
	var message = $dom('remarksconfig-message');
	if (message) {
		message.innerHTML = "Saving...";
	}
	ajax_update(params, 'remarksconfig-message');
}

function admin_slashdbox_fetch(secs) {
	var params = {};
	params['op'] = 'admin_slashdbox';
	ajax_periodic_update(secs, params, "slashdbox-content");
}

function admin_perfbox_fetch(secs) {
	var params = {};
	params['op'] = 'admin_perfbox';
	ajax_periodic_update(secs, params, "performancebox-content");
}

function admin_authorbox_fetch(secs) {
	var params = {};
	params['op'] = 'admin_authorbox';
	ajax_periodic_update(secs, params, "authoractivity-content");
}

function admin_storyadminbox_fetch(secs) {
	var params = {};
	params['op'] = 'admin_storyadminbox';
	ajax_periodic_update(secs, params, "storyadmin-content");
}

function admin_recenttagnamesbox_fetch(secs) {
	var params = {};
	params['op'] = 'admin_recenttagnamesbox';
	ajax_periodic_update(secs, params, "recenttagnames-content");
}

function console_update(use_fh_interval, require_fh_timeout) {
	use_fh_interval = use_fh_interval || 0;

	if (require_fh_timeout && !fh_is_timed_out) {
		return;
	}

	var params = {};
	params['op'] = 'console_update'
	var handlers = {
		onComplete: json_handler
	};
	ajax_update(params, '', handlers);
	var interval = 30000;
	if(use_fh_interval) {
		interval = getFirehoseUpdateInterval(); 
	}
	setTimeout("console_update(" + use_fh_interval + "," + fh_is_timed_out +")", interval);
}

function firehose_usage() {
	var params = {};
	params['op'] = 'firehose_usage'
	var interval = 300000;
	ajax_update(params, 'firehose_usage-content');
	setTimeout(firehose_usage, interval);
}

function make_spelling_correction(misspelled_word, form_element) {
	var selected_key   = "select_" + form_element + '_' + misspelled_word;
	var selected_index = document.forms.slashstoryform.elements[selected_key].selectedIndex;
	
	if (selected_index == 0) {
		return(0);
	}

	// Either learning a word or making a correction.
	if (selected_index >= 1) {
		if (selected_index == 1) {
			var params = {};
			params['op'] = 'admin_learnword';
			params['word'] = misspelled_word;
			ajax_update(params);
		}
		else {
                        // Try to weed out HREFs and parameters
                        var pattern = misspelled_word + "(?![^<]*>)";
                        var re = new RegExp(pattern, "g");
			var correction = document.forms.slashstoryform.elements[selected_key].value;
			document.forms.slashstoryform.elements[form_element].value =
				document.forms.slashstoryform.elements[form_element].value.replace(re, correction);
		}

		// Remove this row from the table.
		var rowname = misspelled_word + '_' + form_element + '_correction';
		var row = document.getElementById(rowname);
		row.parentNode.removeChild(row);

	}

	// Remove the table if we're done.
	var tablename = "spellcheck_" + form_element;
	var table = document.getElementById(tablename);
	var numrows = table.getElementsByTagName("TR");
	if (numrows.length == 1) {
		table.parentNode.removeChild(table);
	}	
}

function firehose_reject (el) {
	var params = {};
	var fh = $dom('firehose-' + el.value);
	params['op'] = 'firehose_reject';
	params['id'] = el.value;
	params['reskey'] = reskey_static;
	ajax_update(params, 'reject_' + el.value);
	firehose_remove_entry(el.value);
}

function firehose_open_note(id) {
	var nf = $dom('note-form-'+id);
	var nt = $dom('note-text-'+id);
	var ni = $dom('note-input-'+id);
	nf.className="";
	ni.focus();
	nt.className="hide";
}

function firehose_save_note(id) {
	var nf = $dom('note-form-'+id);
	var nt = $dom('note-text-'+id);
	var ni = $dom('note-input-'+id);
	var params = {};
	params['op'] = 'firehose_save_note';
	params['note'] = ni.value;
	params['id'] = id;
	ajax_update(params, 'note-text-'+id);
	nf.className = "hide";
	nt.className = "";
}

function firehose_get_admin_extras(id) {
	var params = {};
	params['id'] = id;
	params['op'] = 'firehose_get_admin_extras';
	var handlers = {
		onComplete: json_handler
	};
	ajax_update(params, '', handlers);
}

function firehose_get_and_post(id) {
	var params = {};
	params['id']  = id;
	params['op'] = 'firehose_get_form';
	firehose_collapse_entry(id);
	var handlers = {
		onComplete: function() { $dom('postform-'+id).submit();}
	};
	ajax_update(params, 'postform-'+id, handlers); 
}

function appendToBodytext(text) {
	var obj = $dom('admin-bodytext');
	if (obj) {
		obj.className = "show";
		obj.value = obj.value  + text;
	}
}
