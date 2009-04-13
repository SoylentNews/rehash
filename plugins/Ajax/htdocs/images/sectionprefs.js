; // $Id$

function configSectionPopup() { 
	var title = "<a href=\"#\" onclick=\"window.location.reload()\" style=\"color:#fff;\">Sectional&nbsp;Display&nbsp;Prefs</a>&nbsp;";
	var buttons = createPopupButtons("<a href=\"/faq/UI.shtml#ui500\">[?]</a>","<a href=\"#\" onclick=\"window.location.reload()\">[X]</a>");
	title = title + buttons;
	createPopup('links-sections-title', title, "sectionprefs", "", "Loading...");
	
	var url = 'ajax.pl';
	var params = {};
	params['op'] = 'getSectionPrefsHTML';

	ajax_update(params, 'sectionprefs-contents');

}

function masterChange(el) {
	swapClassColors('secpref_master','secpref_nexus_row');
	updateNexusAllTidPrefs(el);
	//postSectionPrefChanges(el);	
}

function individualChange(el) {
	swapClassColors('secpref_nexus_row','secpref_master');
	//postSectionPrefChanges(el);	
}

function postSectionPrefChanges(el) {
	var params = {};
	params['op'] = 'setSectionNexusPrefs';
	params[el.name] = el.value;
	
	$('#sectionprefs-message').text('Saving...');
	var url = 'ajax.pl';
	ajax_update(params, 'sectionprefs-message'); 
}

function swapClassColors(class_name_active, class_name_deactive) {
	$('tr').filter('.'+class_name_active).css({color:'#000', background:'#fff'}).
		end().
		filter('.'+class_name_deactive).css({color:'#999', background:'#ccc'});
}

function updateNexusAllTidPrefs(el) {
	var v = el.value;
	$('form#modal_prefs [name^=nexustid]').each(function(){
		this.checked = (this.value==v);
	});
}

function reportError(request) {
	// replace with something else
	alert("error");
}

;
