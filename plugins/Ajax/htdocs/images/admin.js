; // $Id$

function um_ajax(the_behaviors, the_events) {
	ajax_update({
		op:		'um_ajax',
		behaviors:	the_behaviors,
		events:		the_events
	}, 'links-vendors-content');
}

function um_fetch_settings() {
	ajax_update({ op: 'um_fetch_settings' }, 'links-vendors-content');
}

function um_set_settings(behavior) {
	ajax_update({
		op:		'um_set_settings',
		behavior:	behavior
	}, 'links-vendors-content');
}

function tagsHistory( selector_fragment, context ) {
	// Pop-up, admin-only, the history of tags applied to this item.

	// Where on the page shall we place the new pop-up?
	var $where, $item=$('[tag-server='+selector_fragment+']');
	if ( context == 'firehose' ) {
		// hang the pop-up from the first available of:
		var $W = $item.find('div.tag-widget.body-widget:first');
		$where = $W.find('.history-button').		// the history button
				add($related_trigger).		// whatever you clicked
				add($W.find('.edit-toggle')).	// the disclosure triangle
				add($item.find('#updown-'+selector_fragment));	// the nod/nix capsule
	} else {
		$where = $any('taghist-' + $item.id);
	}

	// Instantiate the pop-up at that position.
	var popup_id = "taghistory-" + $item.id;
	createPopup(
		$where,
		'History ' + createPopupButtons(
			'<a href="#" onclick="return false">[?]</a></span><span><a href="#" onclick="closePopup(' + "'" + popup_id + "-popup'" + '); return false">[X]</a>'
		),
		popup_id
	);

	// Ask the server to fill in the pop-up's content.
	var item_key = $item.article_info__key();
	ajax_update({
		op:		'tags_history',
		type:		$item.article_info('type'),
		key:		item_key.key,
		key_type:	item_key.key_type
	}, popup_id + '-contents');
}

//
// firehose + admin + tag_ui
//

function firehose_admin_context( display ){
	display.update_tags('extras history', { order: 'prepend' });
}

function firehose_handle_admin_commands( commands ){
	var entry=this, $entry=$(entry), id=$entry.attr('tag-server');

	return $.map(commands, function( cmd ){
		var user_cmd = null;
		switch ( cmd ) {
			case 'extras':
				firehose_get_admin_extras(id);
				break;

			case 'history':
				tagsHistory(id, 'firehose');
				break;

			case 'neverdisplay':
				if ( confirm("Set story to neverdisplay?") ) {
					non_admin_commands.push('neverdisplay');
					entry._ajax_request('', {
						op:	'admin_neverdisplay',
						stoid:	'',
						fhid:	id,
						ajax:	{ success: function(){ firehose_remove_entry(id); } }
					});
				}
				break;

			case 'signed':
			case 'signoff':
			case 'unsigned':
				if ( ! $entry.article_info('awaiting-thumbnail') ) {
					entry._ajax_request('', {
						op:	'admin_signoff',
						stoid:	$entry.article_info('stoid'),
						ajax:	{ success: function(){ $('[context=signoff]', entry).remove(); } }
					});
				}
				firehose_collapse_entry(id);
				break;

			case 'binspam':
				if ( $entry.is('[type=feed]') )
					break;
				/* else fall through */
			case 'hold':
				firehose_collapse_entry(id);
				/* fall through */
			default:
				user_cmd = cmd;
				break;
		}
		return user_cmd;
	});
}


function admin_neverdisplay(stoid, type, fhid) {
	if (confirm("Set story to neverdisplay?")) {
		ajax_update({
			op:	'admin_neverdisplay',
			reskey:	reskey_static,
			stoid:	stoid,
			fhid:	fhid
		}, 'nvd-' + stoid);
		if (type == "firehose") {
			firehose_remove_entry(fhid);
		}
	}
}

function admin_submit_memory(fhid) {
	ajax_update({
		op:		'admin_submit_memory',
		reskey:		reskey_static,
		submatch:	$('#submatch-'+fhid).val(),
		subnote:	$('#subnote-'+fhid).val()
	}, 'sub_mem_message-'+fhid);
}

function remarks_create() {
	var params = {
		op:	'remarks_create',
		reskey:	$('#remarks_reskey').val(),
		remark:	$('#remarks_new').val()
	};

	if ( !params.remark || !params.reskey ) {
		return;
	}

	var limit = $('#remarks_max').val();
	limit && (params.limit=limit);
	ajax_update(params, 'remarks_whole');
}

function remarks_fetch(secs, limit) {
	var params = {};
	params.op = 'remarks_fetch';
	params.limit = limit;
	// run it every 30 seconds; don't need to call again
	ajax_periodic_update(secs, params, 'remarks_table');
}

function remarks_popup() {
	var params = {};
	params.op = 'remarks_config';
	var title = "Remarks Config ";
	var buttons = createPopupButtons('<a href="#" onclick="closePopup(\'remarksconfig-popup\', 1); return false">[X]</a>');
	title = title + buttons;
	createPopup('remarks_table', title + buttons, 'remarksconfig');
	ajax_update(params, 'remarksconfig-contents');
	
}

function remarks_config_save() {
	var params = {
		op:	'remarks_config_save',
		reskey:	$('#remarks_reskey').val()
	};
	if ( !params.reskey ) {
		return;
	}

	var optional_params = {
		min_priority:	$('#remarks_min_priority').val(),
		limit:		$('#remarks_limit').val(),
		filter:		$('#remarks_filter').val(),
	}
	$.each(optional_params, function(k, v){ v && (params[k]=v); });

	$('#remarksconfig-message').text('Saving...');
	ajax_update(params, 'remarksconfig-message');
}

function admin_slashdbox_fetch(secs) {
	ajax_periodic_update(secs, { op: 'admin_slashdbox' }, "slashdbox-content");
}

function admin_perfbox_fetch(secs) {
	ajax_periodic_update(secs, { op: 'admin_perfbox' }, "performancebox-content");
}

function admin_authorbox_fetch(secs) {
	ajax_periodic_update(secs, { op: 'admin_authorbox' }, "authoractivity-content");
}

function admin_storyadminbox_fetch(secs) {
	ajax_periodic_update(secs, { op: 'admin_storyadminbox' }, "storyadmin-content");
}

function admin_recenttagnamesbox_fetch(secs) {
	ajax_periodic_update(secs, { op: 'admin_recenttagnamesbox' }, "recenttagnames-content");
}

function console_update(use_fh_interval, require_fh_timeout) {
	use_fh_interval = use_fh_interval || 0;

	if (require_fh_timeout && !fh_is_timed_out) {
		return;
	}

	ajax_update({ op: 'console_update' }, '', { onComplete: json_handler });
	var interval = 30000;
	if(use_fh_interval) {
		interval = getFirehoseUpdateInterval(); 
	}
	setTimeout(function(){console_update(use_fh_interval, fh_is_timed_out);}, interval * 2);
}

function firehose_usage() {
	var interval = 300000;
	ajax_update({ op: 'firehose_usage' }, 'firehose_usage-content');
	setTimeout(firehose_usage, interval);
}

function make_spelling_correction(misspelled_word, form_element) {
	var selected_key   = "select_" + form_element + '_' + misspelled_word;
	var selected_index = document.forms.slashstoryform.elements[selected_key].selectedIndex;
	
	if (selected_index === 0) {
		return(0);
	}

	// Either learning a word or making a correction.
	if (selected_index >= 1) {
		if (selected_index == 1) {
			var params = {};
			params.op = 'admin_learnword';
			params.word = misspelled_word;
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
	ajax_update({
		op:	'firehose_reject',
		id:	el.value,
		reskey:	reskey_static
	}, 'reject_' + el.value);
	firehose_remove_entry(el.value);
}

function firehose_init_note_flags(){
	var $entries = $(document).article_info__find_articles(':not(:has(> h3 > span.note-flag))');

	// set up the "note flag"
	return $entries.each(function(){
		var $entry = $(this);
		var $note = $entry.find('.note-wrapper');
		var note_text='', no_note = ! $note.length || $note.hasClass('no-note');
		if ( ! no_note ) {
			note_text = $.trim($note.find('.admin-note a').text());
		}

		var $note_flag = $entry.find('> h3').
			append('<span class="note-flag">note</span>').
			find('.note-flag').
				attr('title', note_text).
				click(function(){
					firehose_open_note($entry)
				});

		if ( no_note ) {
			$note_flag.addClass('no-note');
		}
	});
}

function firehose_open_note( expr ) {
	if ( typeof expr === 'string' || typeof expr === 'number' ) {
		expr = '#firehose-' + expr;
	}
	return $(expr).
		each(function(){
			var $entry = $(this), id = fhid(this);
			if ( $entry.is('[class^=brief]') ) {
				toggle_firehose_body(id, true);
			}
			$entry.find('.note-wrapper').removeClass('no-note');
			$entry.find('#note-form-'+id).removeClass('hide');
			$entry.find('#note-input-'+id).each(function(){this.focus();});
			$entry.find('#note-text-'+id).addClass('hide');
		});
}

function firehose_save_note(id) {
	var $entry = $('#firehose-'+id);

	var note_text = $.trim($entry.find('#note-input-'+id).val());
	$entry.find('.note-flag, .note-wrapper').
		toggleClass('no-note', !note_text).
		filter('.note-flag').
			attr('title', note_text);

	ajax_update({
		op:	'firehose_save_note',
		note:	note_text,
		id:	id
	});
	$entry.find('#note-form-'+id).addClass('hide');
	$entry.find('#note-text-'+id).text(note_text || 'Note').removeClass('hide');

	return $entry;
}

function firehose_get_admin_extras(id) {
	ajax_update({
		op:	'firehose_get_admin_extras',
		id:	id
	}, '', {
		onComplete: function(transport) {
			json_handler(transport);
			view('firehose-' + id);
		}
	});
}

function firehose_get_and_post(id) {
	ajax_update({
		op:	'firehose_get_form',
		id:	id
	}, 'postform-'+id, {
		onComplete: function() {
			$('#postform-'+id).submit();
		}
	});
}

function appendToBodytext(text) {
	$('#admin-bodytext').each(function(){
		this.className = "show";
		this.value += text;
	});
}

function appendToMedia(text) {
	$('#admin-media').each(function(){
		this.className = "show";
		this.value += text;
	});
}

$(function(){
	// edit icons positioning fix
	if( $.browser.safari || $.browser.opera ) {
		$('.edit a').css('margin-top','0pt');
	}
});
