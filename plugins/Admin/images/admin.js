; // $Id$

function toggle_visibility(id) {
	var e = document.getElementById(id);
	if(e.style.display == 'table-row')
		e.style.display = 'none';
	else
		e.style.display = 'table-row';
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
	if ($('#' + correction_parent).children().children().length === 1) {
		$('#' + correction_parent).remove();
	}
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
