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

function storyInfo( selector_fragment ) {
	// Pop-up, admin-only, the signoff history for this story.

	// Where on the page shall we place the new pop-up?
	var $where, $item=$('[data-fhid='+selector_fragment+']');
		// hang the pop-up from the first available of:
	var $W = $item.find('div.tag-widget.body-widget:first');
	$where = $related_trigger.		// whatever you clicked
			add($W.find('.edit-toggle')).	// the disclosure triangle
			add($item.find('#updown-'+selector_fragment));	// the nod/nix capsule

	// Instantiate the pop-up at that position.
	var popup_id = "storyinfo-" + selector_fragment;
	var popup = createPopup(
		$where,
		'Story Info ' + createPopupButtons(
			'<a href="#" onclick="return false">[?]</a></span><span><a href="#" onclick="closePopup(' + "'" + popup_id + "-popup'" + '); return false">[X]</a>'
		),
		popup_id
	);
	$(popup).draggable();

	// Ask the server to fill in the pop-up's content.
	ajax_update({
		op:			'admin_signoffbox',
		stoid:		fhitem_info($item, 'stoid')
	}, popup_id + '-contents');
}

function tagsHistory( selector_fragment, context ) {
	// Pop-up, admin-only, the history of tags applied to this item.

	// Where on the page shall we place the new pop-up?
	var $where, $item=$('[data-fhid='+selector_fragment+']');
	if ( context == 'firehose' ) {
		// hang the pop-up from the first available of:
		var $W = $item.find('div.tag-widget.body-widget:first');
		$where = $W.find('.history-button').		// the history button
				add($related_trigger).		// whatever you clicked
				add($W.find('.edit-toggle')).	// the disclosure triangle
				add($item.find('#updown-'+selector_fragment));	// the nod/nix capsule
	} else {
		$where = $any('taghist-' + selector_fragment);
	}

	// Instantiate the pop-up at that position.
	var popup_id = "taghistory-" + selector_fragment;
	var popup = createPopup(
		$where,
		'History ' + createPopupButtons(
			'<a href="#" onclick="return false">[?]</a></span><span><a href="#" onclick="closePopup(' + "'" + popup_id + "-popup'" + '); return false">[X]</a>'
		),
		popup_id
	);
	$(popup).draggable();

	// Ask the server to fill in the pop-up's content.
	var item_key = fhitem_key($item);
	ajax_update({
		op:		'tags_history',
		type:		fhitem_info($item, 'type'),
		key:		item_key.key,
		key_type:	item_key.key_type
	}, popup_id + '-contents');
}

//
// firehose + admin + tag_ui
//

function signoff( $fhitem, id ){
	$.ajax({type:'POST',
		dataType:'text',
		data:{	op:'admin_signoff',
			stoid:fhitem_info($fhitem, 'stoid'),
			reskey:reskey_static,
			limit_fetch:''
		},
		success: function( server_response ){
			$fhitem.find('a.signoff-button').remove();
		}
	});
	firehose_collapse_entry(id || $fhitem.attr('data-fhid'));
}

$('a.signoff-button').live('click', function( e ){
	signoff($(e.originalEvent.target).closest('.fhitem'));
});

function firehose_handle_admin_commands( commands ){
	var entry=this, $entry=$(entry), id=$entry.attr('data-fhid');

	return $.map(commands, function( cmd ){
		var user_cmd = null;
		switch ( cmd ) {
			case 'extras':
				firehose_get_admin_extras(id);
				break;

			case 'history':
				tagsHistory(id, 'firehose');
				break;

			case 'info':
				storyInfo(id);
				break;

			case 'neverdisplay':
				if ( confirm("Set story to neverdisplay?") ) {
					user_cmd = cmd;
					$.ajax({type:'POST',
						dataType:'text',
						data:{	op:'admin_neverdisplay',
							stoid:'',
							fhid:id,
							reskey:reskey_static,
							limit_fetch:''
						},
						success: function( server_response ){
							firehose_remove_entry(id);
						}
					});
				}
				break;

			case 'signed':
			case 'signoff':
			case 'unsigned':
				signoff($entry, id);
				break;
			case 'betaedit':
				show_submit_box_after(id);
				break;
			case 'oldedit':
				var loc = document.location + '';
				var match = loc.match('https?://[^/]*');
				openInWindow(match + '/firehose.pl?op=edit&amp;id=' + id);
                                break;

				break;
			case 'binspam':
				if ( $entry.is('.fhitem-feed') )
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
		filter:		$('#remarks_filter').val()
	};
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
	var selected_key = "select_" + form_element + '_' + misspelled_word;
	var selected_index = document.forms.slashstoryform.elements[selected_key].selectedIndex;

	if (selected_index === 0) {
		return(0);
	}

	if (selected_index >= 1) {
		if (selected_index === 1) {
			var params = {};
			params.op = 'admin_learnword';
			params.word = misspelled_word;
			ajax_update(params);
		} else {
			var pattern = misspelled_word + "(?![^<]*>)";
			var re = new RegExp(pattern, "g");
			var correction = document.forms.slashstoryform.elements[selected_key].value;
			document.forms.slashstoryform.elements[form_element].value = document.forms.slashstoryform.elements[form_element].value.replace(re,correction);
		}

		var corrected_id = misspelled_word + '_' + form_element+'_correction';
		$('#' + corrected_id).remove();
	}

	var correction_parent = "spellcheck_" + form_element;
	if ($('#' + correction_parent).children().length === 1) {
		$('#' + correction_parent).remove();
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

function firehose_init_note_flags( limit ){
	var $items = $('div.fhitem:not(:has(>h3>span.note-flag))');
	limit && ($items = $items.filter(':lt('+limit+')'));

	return $items.
		each(function(){
			var	$item			= $(this),
				$flag_parent	= $item.find('>h3:first'),
				$note			= $item.find('.note-wrapper'),
				has_note		= $note.length && !$note.is('.no-note'),
				text			= has_note ? $.trim($note.find('.admin-note a').text()) : '';

			$('<span class="note-flag">note</a>').
				prependTo($flag_parent).
				attr('title', text).
				toggleClass('no-note', !has_note).
				click(firehose_open_note);
		});
}

function firehose_open_note( o ) {
	$(!o && this || o.target || o.originalTarget || o).closest('div.fhitem').
		each(function(){
			var $item=$(this), fhid=this.id.replace(FHID_PREFIX, '');
			toggle_firehose_body($item, void(0), toggle_firehose_body.SHOW);
			$item.find('.note-wrapper').removeClass('no-note');
			$item.find('#note-form-'+fhid).removeClass('hide');
			$item.find('#note-input-'+fhid).focus();
			$item.find('#note-text-'+fhid).addClass('hide');
		});
	// allow other click-handlers to run (by returning nothing)
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
