; // $Id$

$(function(){
var $fhs=$any('firehose-sections'), $md=$fhs.children('script[type=data]');
if ( $md.length ) {
	$fhs.metadata({ type:'elem', name:'script' });	// force metadata initialization
	$md.remove();	// and delete the element that delivered it to us
}


$fhs.sortable({				// make sections sortable...
		axis: 'y',
		containment: '#links-sections',
		opacity: 0.8,
		//start: function(event, ui) { return check_logged_in() },
		update: saveFirehoseSectionMenu	// ...and save their new order
	});
});

function saveFirehoseSectionMenu(){
	if (! check_logged_in()) {
		return false;
	}

	// tell the server our current (ordered) list of sections
	ajax_update({
		op:	'firehose_save_section_menu',
		reskey:	reskey_static,
		fsids:	$('#firehose-sections > li').
				map(function(){
					var id = this.id.slice(10);	// slice off leading 'fhsection-'
					if ( id !== 'unsaved' ) {
						return id;
					}
				}).
				get().
				join(',')
	});
}

function firehose_delete_section(id,undo) {
	if (undo == undefined ) {
		undo = 0;
	}
	ajax_update({
		op:	'firehose_delete_section_menu',
		reskey:	reskey_static,
		undo:	undo,
		id: 	id
	});
}


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
