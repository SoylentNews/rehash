function configSectionPopup() {

var body = document.getElementsByTagName("body")[0];
var div = document.createElement("div");
div.style.position = "absolute";
div.style.top = "225px";
//div.style.left = "123px";
div.style.zIndex = "30";
div.style.fontSize = "80%";
div.style.background = "#fff";
div.style.color = "#000";
//div.style.height = "650px";
div.style.width = "auto";
div.style.border = "solid 2px #066";
div.padding = "5px";
div.innerHTML = "<div id=\"sectionprefs_hdr\">Section Prefs</div><div id='sectionprefs'></div>";
body.appendChild(div);
	
	var url = 'ajax.pl?op=getSectionPrefsHTML';
	var params = '';
	var ajax = new Ajax.Updater(
	{success: 'sectionprefs'},
	url,
	{method: 'post', parameters: params, onFailure: reportError});

}

function masterChange(el) {

	swapClassColors('secpref_master','secpref_nexus_row');
	updateNexusAllTidPrefs(el);
	postSectionPrefChanges(el);	
}

function individualChange(el) {
	swapClassColors('secpref_nexus_row','secpref_master');
	postSectionPrefChanges(el);	
}

function postSectionPrefChanges(el) {
	var params = [];
	params['op'] = 'setSectionNexusPrefs';
	params[el.name] = el.value;
	var h = $H(params);
	
	var sec_pref_msg = document.getElementById("sectionprefs_message");
	sec_pref_msg.innerHTML = "Updating...";
	var url = 'ajax.pl';
	var ajax = new Ajax.Updater(
	{success: 'sectionprefs_message'},
	url,
	{method: 'post', parameters: h.toQueryString(), onFailure: reportError});
}

function swapClassColors(class_name_active, class_name_deactive) {
	for (i=0; i <document.getElementsByTagName("tr").length; i++) {
		if (document.getElementsByTagName("tr").item(i).className == class_name_active){
			document.getElementsByTagName("tr").item(i).style.color = "#000";
			document.getElementsByTagName("tr").item(i).style.background = "#fff";
		} else if (document.getElementsByTagName("tr").item(i).className == class_name_deactive){
			document.getElementsByTagName("tr").item(i).style.color = "#999";
			document.getElementsByTagName("tr").item(i).style.background = "#ccc";
		}
	}
}
function updateNexusAllTidPrefs(el) {
	theForm = document.forms["sectionprefs"];
	for(i=0; i<theForm.elements.length; i++){
		var regex = /^nexustid\d+$/;
		if (regex.test(theForm.elements[i].name)) {
			if (theForm.elements[i].value == el.value) {
				theForm.elements[i].checked = true;
			} else {
				theForm.elements[i].checked = false;
			}
		}
	}
}

function reportError(request) {
	// replace with something else
	alert("error");
}
