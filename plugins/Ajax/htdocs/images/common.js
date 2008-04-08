// _*_ Mode: JavaScript; tab-width: 8; indent-tabs-mode: true _*_
// $Id$

function $dom( id ) {
	return document.getElementById(id);
}

jQuery.fn.extend({

	mapClass: function( map ) {
		map['?'] = map['?'] || [];
		return this.each(function() {
			var unique = {};
			var cl = [];
			$.each($.map(this.className.split(/\s+/), function(k){
				return k in map ? map[k] : ('*' in map ? map['*'] : k)
			}).concat(map['+']), function(i, k) {
				if ( k && !(k in unique) ) {
					unique[k] = true;
					cl.push(k);
				}
			});
			this.className = (cl.length ? cl : map['?']).join(' ');
		});
	},

	setClass: function( c1 ) {
		return this.each(function() {
			this.className = c1
		});
	},

	toggleClasses: function( c1, c2, force ) {
		var map = { '?': force };
		map[c1]=c2;
		map[c2]=c1;
		return this.mapClass(map);
	}

});

var reskey_static = '';

// global settings, but a firehose might use a local settings object instead
var firehose_settings = {};
  firehose_settings.startdate = '';
  firehose_settings.duration = '';
  firehose_settings.mode = '';
  firehose_settings.color = '';
  firehose_settings.orderby = '';
  firehose_settings.orderdir = '';

  firehose_settings.issue = '';
  firehose_settings.is_embedded = 0;
  firehose_settings.not_id = 0;
  firehose_settings.section = 0;
  firehose_settings.more_num = 0;

// Settings to port out of settings object
  firehose_item_count = 0;
  firehose_updates = Array(0);
  firehose_updates_size = 0;
  firehose_ordered = Array(0);
  firehose_before = Array(0);
  firehose_after = Array(0);
  firehose_removed_first = '0';
  firehose_removals = null;
  firehose_future = null;

  var firehose_cur = 0;

// globals we haven't yet decided to move into |firehose_settings|
var fh_play = 0;
var fh_is_timed_out = 0;
var fh_is_updating = 0;
var fh_update_timerids = Array(0);
var fh_is_admin = 0;
var console_updating = 0;
var fh_colorslider; 
var fh_ticksize;
var fh_colors = Array(0);
var fh_use_jquery = 0;
var vendor_popup_timerids = Array(0);
var vendor_popup_id = 0;
var fh_slider_init_set = 0;
var ua=navigator.userAgent;
var is_ie = ua.match("/MSIE/");


function createPopup(xy, titlebar, name, contents, message, onmouseout) {
	var body = document.getElementsByTagName("body")[0]; 
	var div = document.createElement("div");
	div.id = name + "-popup";
	div.style.position = "absolute";

	if (onmouseout) {
		div.onmouseout = onmouseout;
	}

	var leftpos = xy[0] + "px";
	var toppos  = xy[1] + "px";
	
	div.style.left = leftpos;
	div.style.top = toppos;
	div.style.zIndex = "100";
	contents = contents || "";
	message  = message || "";

	div.innerHTML = '<iframe></iframe><div id="' + name + '-title" class="popup-title">' + titlebar + '</div>' +
                        '<div id="' + name + '-contents" class="popup-contents">' + contents + '</div>' +
			'<div id="' + name + '-message" class="popup-message">' + message + '</div>';

	body.appendChild(div);
	div.className = "popup";
	return div;
}

function createPopupButtons() {
	return '<span class="buttons"><span>' + $.makeArray(arguments).join('</span><span>') + '</span></span>';
}

function closePopup(id, refresh) {
	$('#'+id).remove();
	if (refresh) {
		window.location.reload();
	}
}

function handleEnter(ev, func, arg) {
	if (!ev) {
		ev = window.event;
	}
	var code = ev.which || ev.keyCode;
	if (code == 13) { // return/enter
		func(arg);
		ev.returnValue = true;
		return true;
	}
	ev.returnValue = false;
	return false;
}


function moveByObjSize(div, addOffsetWidth, addOffsetHeight) {
	if (addOffsetWidth) {
		div.style.left = parseFloat(div.style.left || 0) + (addOffsetWidth * div.offsetWidth) + "px";
	}
	if (addOffsetHeight) {
		div.style.top = parseFloat(div.style.top || 0) + (addOffsetHeight * div.offsetHeight) + "px";
	}
}

function moveByXY(div, x, y) {
	if (x) {
		div.style.left = parseFloat(div.style.left || 0) + x + "px";
	}
	if (y) {
		div.style.top = parseFloat(div.style.top || 0) + y + "px";
	}
}

function getXYForId(id, addWidth, addHeight) {
	var div = $('#'+id);
	var offset = div.offset();
	if (addWidth) offset.left += div.attr('offsetWidth');
	if (addHeight) offset.top += div.attr('offsetHeight');
	return [ offset.left, offset.top ];
}

function firehose_toggle_advpref() {
	$('#fh_advprefs').toggleClass('hide');
}

function firehose_open_prefs() {
	$('#fh_advprefs').removeClass();
}

function toggleId(id, c1, c2) {
	$('#'+id).toggleClasses(c1, c2, c1);
}

function toggleIntro(id, toggleid) {
	var new_class = 'condensed';
	var new_html = '[+]';
	if ( $('#'+id).toggleClasses('introhide', 'intro').hasClass('intro') ) {
		new_class = 'expanded';
		new_html = '[-]';
	}
	$('#'+toggleid).setClass(new_class).html(new_html);
}

function tagsToggleStoryDiv(id, is_admin, type) {
	($('#toggletags-body-'+id).hasClass('tagshide') ? tagsShowBody : tagsHideBody)(id, is_admin, '', type);
}

function tagsHideBody(id) {
	$('#toggletags-body-'+id).setClass('tagshide');		// Make the body of the tagbox vanish
	$('#tagbox-title-'+id).setClass('tagtitleclosed');	// Make the title of the tagbox change back to regular
	$('#tagbox-'+id).setClass('tags');			// Make the tagbox change back to regular.
	$('#toggletags-button-'+id).html('[+]');		// Toggle the button back.
}

function tagsShowBody(id, is_admin, newtagspreloadtext, type) {

	type = type || "stories";

	if (type == "firehose") {
		setFirehoseAction();
		if (fh_is_admin) {
			firehose_get_admin_extras(id);
		}
	}

	//alert("Tags show body / Type: " + type );
	$('#toggletags-button-'+id).html("[-]");		// Toggle the button to show the click was received
	$('#tagbox-'+id).setClass("tags");			// Make the tagbox change to the slashbox class
	$('#tagbox-title-'+id).setClass("tagtitleopen");	// Make the title of the tagbox change to white-on-green
	$('#toggletags-body-'+id).setClass("tagbody");		// Make the body of the tagbox visible
	
	// If the tags-user div hasn't been filled, fill it.
	var tagsuser = $('#tags-user-' + id);
	if (tagsuser.html() == "") {
		// The tags-user-123 div is empty, and needs to be
		// filled with the tags this user has already
		// specified for this story, and a reskey to allow
		// the user to enter more tags.
		tagsuser.html("Retrieving...");
		var params = {};
		if (type == "stories") {
			params['op'] = 'tags_get_user_story';
			params['sidenc'] = id;
		} else if (type == "urls") {
			//alert('getting user urls ' + id);
			params['op'] = 'tags_get_user_urls';
			params['id'] = id;
		} else if (type == "firehose") {
			params['op'] = 'tags_get_user_firehose';
			params['id'] = id;
		}
		params['newtagspreloadtext'] = newtagspreloadtext;
		var handlers = {
			onComplete: function() { 
				$dom('newtags-'+id).focus();
			}
		}
		ajax_update(params, 'tags-user-' + id, handlers);
		//alert('after ajax_update ' + tagsuserid);

		// Also fill the admin div.  Note that if the user
		// is not an admin, this call will not actually
		// return the necessary form (which couldn't be
		// submitted anyway).  The is_admin parameter just
		// saves us an ajax call to find that out, if the
		// user is not actually an admin.
		if (is_admin) {
			var tagsadminid = 'tags-admin-' + id;
			params = {};
			if (type == "stories") {
				params['op'] = 'tags_get_admin_story';
				params['sidenc'] = id;
			} else if (type == "urls") {
				params['op'] = 'tags_get_admin_url';
				params['id'] = id;
			} else if (type == "firehose") {
				params['op'] = 'tags_get_admin_firehose';
				params['id'] = id;
			}
			ajax_update(params, tagsadminid);
		}

	} else {
		if (newtagspreloadtext) {
			// The box was already open but it was requested
			// that we append some text to the user text.
			// We can't do that by passing it in, so do it
			// manually now.
			var textinput = $dom('newtags-'+id);
			textinput.value += ' ' + newtagspreloadtext;
			textinput.focus();
		}
	}
}

function tagsOpenAndEnter(id, tagname, is_admin, type) {
	// This does nothing if the body is already shown.
	tagsShowBody(id, is_admin, tagname, type);
}

function completer_renameMenu( s, params ) {
	if ( s )
		params._sourceEl.innerHTML = s;
}

function completer_setTag( s, params ) {
	createTag(s, params._id, params._type);
	var tagField = document.getElementById('newtags-'+params._id);
	if ( tagField ) {
		var s = tagField.value.slice(-1);
		if ( s.length && s != " " )
			tagField.value += " ";
		tagField.value += s;
	}
}

function completer_handleNeverDisplay( s, params ) {
	if ( s == "neverdisplay" )
		admin_neverdisplay("", "firehose", params._id);
}

function completer_save_tab(s, params) {
	firehose_save_tab(params._id);
}

function clickCompleter( obj, id, is_admin, type, tagDomain, customize ) {
	return attachCompleter(obj, id, is_admin, type, tagDomain, customize);
}

function focusCompleter( obj, id, is_admin, type, tagDomain, customize ) {
	if ( navigator.vendor !== undefined ) {
		var vendor = navigator.vendor.toLowerCase();
		if ( vendor.indexOf("apple") != -1
				|| vendor.indexOf("kde") != -1 )
			return false;
	}

	return attachCompleter(obj, id, is_admin, type, tagDomain, customize);
}

function attachCompleter( obj, id, is_admin, type, tagDomain, customize ) {
	if ( customize === undefined )
		customize = new Object();
	customize._id = id;
	customize._is_admin = is_admin;
	customize._type = type;
	if ( tagDomain != 0 && customize.queryOnAttach === undefined )
		customize.queryOnAttach = true;
	
	if ( !YAHOO.slashdot.gCompleterWidget )
		YAHOO.slashdot.gCompleterWidget = new YAHOO.slashdot.AutoCompleteWidget();

	YAHOO.slashdot.gCompleterWidget.attach(obj, customize, tagDomain);
	return false;
}

function reportError(request) {
	// replace with something else
	alert("error");
}

function createTag(tag, id, type) {
	var params = {};
	params['id'] = id;
	params['type'] = type;
	if ( fh_is_admin && ("_#)^*".indexOf(tag[0]) != -1) ) {
	  params['op'] = 'tags_admin_commands';
	  params['reskey'] = $('#admin_commands-reskey-' + id).val();
	  params['command'] = tag;
	} else {
	  params['op'] = 'tags_create_tag';
	  params['reskey'] = reskey_static;
	  params['name'] = tag;
	  if ( fh_is_admin && (tag == "hold") ) {
	    firehose_collapse_entry(id);
	  }
	}
	ajax_update(params, '');
}

function tagsCreateForStory(id) {
	var status = $('#toggletags-message-'+id).html('Saving tags...');

	ajax_update({
		op: 'tags_create_for_story',
		sidenc: id,
		tags: $('#newtags-'+id).val(),
		reskey: $('#newtags-reskey-'+id).val()
	}, 'tags-user-' + id);

	// XXX How to determine failure here?
	status.html('Tags saved.');
}

function tagsCreateForUrl(id) {
	var status = $('#toggletags-message-'+id).html('Saving tags...');

	ajax_update({
		op:	'tags_create_for_url',
		id:	id,
		tags:	$('#newtags-'+id).val(),
		reskey:	$('#newtags-reskey-'+id).val()
	}, 'tags-user-' + id);

	// XXX How to determine failure here?
	status.html('Tags saved.');
}

//Firehose functions begin
function setOneTopTagForFirehose(id, newtag) {
	ajax_update({
		op: 'firehose_update_one_tag',
		id: id,
		tags: newtag
	});
}

function tagsCreateForFirehose(id) {
	var status = $('#toggletags-message-'+id).html('Saving tags...');
	
	ajax_update({
		op:	'tags_create_for_firehose',
		id:	id,
		tags:	$('#newtags-'+id).val(),
		reskey:	$('#newtags-reskey-'+id).val()
	}, 'tags-user-'+id);

	status.html('Tags saved.');
}

function toggle_firehose_body(id, is_admin) {
	var params = {};
	setFirehoseAction();
	params['op'] = 'firehose_fetch_text';
	params['id'] = id;
	var fhbody = $dom('fhbody-'+id);
	var fh = $dom('firehose-'+id);
	var usertype = fh_is_admin ? " adminmode" : " usermode";
	if (fhbody.className == "empty") {
		var handlers = {
			onComplete: function() {
				if(firehoseIsInWindow(id)) { 
					scrollToWindowFirehose(id); 
				}
				firehose_get_admin_extras(id); 
			}
		};
		params['reskey'] = reskey_static;
		ajax_update(params, 'fhbody-'+id, is_admin ? handlers : null);
		fhbody.className = "body";
		fh.className = "article" + usertype;
		if (is_admin)
			tagsShowBody(id, is_admin, '', "firehose");
	} else if (fhbody.className == "body") {
		fhbody.className = "hide";
		fh.className = "briefarticle" + usertype;
		/*if (is_admin)
			tagsHideBody(id);*/
	} else if (fhbody.className == "hide") {
		fhbody.className = "body";
		fh.className = "article" + usertype;
		/*if (is_admin)
			tagsShowBody(id, is_admin, '', "firehose"); */
	}
}

function toggleFirehoseTagbox(id) {
	$('#fhtagbox-'+id).toggleClasses('tagbox', 'hide');
}

function firehose_set_options(name, value) {
	var pairs = [
		// name		value		curid		newid		newvalue 	title 
		["orderby", 	"createtime", 	"popularity",	"time",		"popularity"	],
		["orderby", 	"popularity", 	"time",		"popularity",	"createtime"	],
		["orderdir", 	"ASC", 		"asc",		"desc",		"DESC"],
		["orderdir", 	"DESC", 	"desc",		"asc",		"ASC"],
		["mode", 	"full", 	"abbrev",	"full",		"fulltitle"],
		["mode", 	"fulltitle", 	"full",		"abbrev",	"full"]
	];
	var params = {};
	params['op'] = 'firehose_set_options';
	params['reskey'] = reskey_static;
	var theForm = document.forms["firehoseform"];
	if (name == "firehose_usermode") {
		if (value ==  true) {
			value = 1;
		}
		if (value == false) {
			value = 0;
		}
		params['setusermode'] = 1;
		params[name] = value;
	}

	if (name == "nodates" || name == "nobylines" || name == "nothumbs" || name == "nocolors" || name == "mixedmode" || name == "nocommentcnt" || name == "nomarquee" || name == "noslashboxes") {
		value = value == true ? 1 : 0;
		params[name] = value;
		params['setfield'] = 1;
		var classname;
		if (name == "nodates") {
			classname = "date";
		} else if (name == "nobylines") {
			classname = "nickname";
		}

		if (classname) {
			$('#firehoselist .'+classname).setClass(classname + value ? ' hide' : '');
		}
	}

	if (name == "fhfilter" && theForm) {
		for (i=0; i< theForm.elements.length; i++) {
			if (theForm.elements[i].name == "fhfilter") {
				firehose_settings.fhfilter = theForm.elements[i].value;
			}
		}
		firehose_settings.page = 0;
		firehose_settings.more_num = 0;
	}
	if (name != "color") {
	for (i=0; i< pairs.length; i++) {
		var el = pairs[i];
		if (name == el[0] && value == el[1]) {
			firehose_settings[name] = value;
			if ($dom(el[2])) {
				$dom(el[2]).id = el[3];
				if($dom(el[3])) {
					var namenew = el[0];
					var valuenew = el[4];
					$dom(el[3]).firstChild.onclick = function() { firehose_set_options(namenew, valuenew); return false;}
				}
			}
		}
	}
	if (name == "mode" || name == "firehose_usermode" || name == "tab" || name == "mixedmode" || name == "nocolors" || name == "nothumbs") {
		// blur out then remove items
		if (name == "mode") {
			fh_view_mode = value;
		}
		if ($dom('firehoselist')) {
			// set page
			page = 0;
			
			if (!is_ie) {
				var attributes = { 
					opacity: { from: 1, to: 0 }
				};
				var myAnim = new YAHOO.util.Anim("firehoselist", attributes); 
				myAnim.duration = 1;
				myAnim.onComplete.subscribe(function() {
					$dom('firehoselist').style.opacity = "1";
				});
				myAnim.animate();
			}
			// remove elements
			setTimeout(firehose_remove_all_items, 600);
		}
	}
	}

	if (name == "color" || name == "tab" || name == "pause" || name == "startdate" || name == "duration" || name == "issue" || name == "pagesize") { 
		params[name] = value;
		if (name == "startdate") {
			firehose_settings.startdate = value;
		}
		if (name == "duration")  {
			firehose_settings.duration = value;
		}
		if (name == "issue") {
			firehose_settings.issue = value;
			firehose_settings.startdate = value;
			firehose_settings.duration = 1;
			firehose_settings.page = 0;
			firehose_settings.more_num = 0;
			var issuedate = firehose_settings.issue.substr(5,2) + "/" + firehose_settings.issue.substr(8,2) + "/" + firehose_settings.issue.substr(10,2);

			$('#fhcalendar, #fhcalendar_pag').each(function(){
				this._widget.setDate(issuedate, "day");
			});
		}
		if (name == "color") {
			firehose_settings.color = value;
		}
		if (name == "pagesize") {
			firehose_settings.page = 0;
			firehose_settings.more_num = 0;
		}
	}

	var handlers = {
		onComplete: function(transport) { 
			json_handler(transport);
			firehose_get_updates({ oneupdate: 1 });
		}
	};

	if (name == 'tabsection') {
		firehose_settings.section = value;
		params['tabtype'] = 'tabsection';
	}

	if (name == 'tabtype') {
		params['tabtype'] = value;
	}

	params['section'] = firehose_settings.section;
	for (i in firehose_settings) {
		params[i] = firehose_settings[i];
	}
	ajax_update(params, '', handlers);
}

function firehose_remove_all_items() {
	$('#firehoselist').children().remove();
}


function firehose_up_down(id, dir) {
	if (!check_logged_in()) return;

	setFirehoseAction();
	ajax_update({
		op:	'firehose_up_down',
		id:	id,
		reskey:	reskey_static,
		dir:	dir
	}, '', { onComplete: json_handler });

	$('#updown-'+id).setClass(dir=='+' ? 'votedup' : 'voteddown');

	if (dir == "-" && fh_is_admin) {
		firehose_collapse_entry(id);
	}
}

function firehose_remove_tab(tabid) {
	setFirehoseAction();
	ajax_update({
		op:		'firehose_remove_tab',
		tabid:		tabid,
		reskey:		reskey_static,
		section:	firehose_settings.section
	}, '', { onComplete: json_handler });

}


// firehose functions end

// helper functions
function ajax_update(request_params, id, handlers, request_url) {
	// make an ajax request to request_url with request_params, on success,
	//  update the innerHTML of the element with id

	var opts = {
		url: request_url || '/ajax.pl',
		data: request_params,
		type: 'POST',
		contentType: 'application/x-www-form-urlencoded'
	};

	if ( id ) {
		opts['success'] = function(html){
			$('#'+id).html(html);
		}
	}

	if ( handlers && handlers.onComplete ) {
		opts['complete'] = handlers.onComplete;
	}

	jQuery.ajax(opts);
}

function ajax_periodic_update(interval_in_seconds, request_params, id, handlers, request_url) {
	setInterval(function(){
		ajax_update(request_params, id, handlers, request_url);
	}, interval_in_seconds*1000);
}

function eval_response(transport) {
	var response;
	try {
		eval("response = " + transport.responseText)
	} catch (e) {
		//alert(e + "\n" + transport.responseText)
	}
	return response;
}

function json_handler(transport) {
	var response = eval_response(transport);
	json_update(response);
	return response;
}

function json_update(response) {
	if (response.eval_first) {
		try {
			eval(response.eval_first)
		} catch (e) {

		}
	}

	if (response.html) {
		for (el in response.html) {
			$('#'+el).html(response.html[el]);
		}
		
	} 

	if (response.value) {
		for (el in response.value) {
			$('#'+el).val(response.value[el]);
		}
	}

	if (response.html_append) {
		for (el in response.html_append) {
			$('#'+el).each(function(){
				this.innerHTML += response.html_append[el];
			});
		}
	}

	if (response.html_append_substr) {
		for (el in response.html_append_substr) {
			var found = $('#'+el);
			if (found.size()) {
				var this_html = found.html();
				var pos = this_html.search(/<span class="?substr"?> ?<\/span>[\s\S]*$/i);
				if ( pos != -1 )
					this_html = this_html.substr(0, pos);
				found.html(this_html + response.html_append_substr[el]);
			}
		}
	}		
	
	if (response.eval_last) {
		try {
			eval(response.eval_last)
		} catch (e) {

		}
	}
}


function firehose_handle_update() {
	if (firehose_updates.length > 0) {
		var el = firehose_updates.pop();
		var fh = 'firehose-' + el[1];
		var wait_interval = 800;
		if(el[0] == "add") {
			if (firehose_before[el[1]] && $('#firehose-' + firehose_before[el[1]]).size()) {
				$('#firehose-' + firehose_before[el[1]]).after(el[2]);
			} else if (firehose_after[el[1]] && $('#firehose-' + firehose_after[el[1]]).size()) {
				$('#firehose-' + firehose_after[el[1]]).before(el[2]);
			} else if (insert_new_at == "bottom") {
				$('#firehoselist').append(el[2]);
			} else {
				$('#firehoselist').prepend(el[2]);
			}
		
			var toheight = 50;
			if (fh_view_mode == "full") {
				toheight = 200;
			}

			var attributes = { 
				height: { from: 0, to: toheight }
			};
			if (!is_ie) {
				attributes.opacity = { from: 0, to: 1 };
			}
			var myAnim = new YAHOO.util.Anim(fh, attributes); 
			myAnim.duration = 0.7;

			if (firehose_updates_size > 10) {
				myAnim.duration = myAnim.duration / 2;
				wait_interval = wait_interval / 2;
			}
			if (firehose_updates_size > 20) {
				myAnim.duration = myAnim.duration / 2;
				wait_interval = wait_interval / 2;

			}
			if (firehose_updates_size > 30) {
				myAnim.duration = myAnim.duration / 1.5;
				wait_interval = wait_interval / 2;
			}

			myAnim.onComplete.subscribe(function() {
				if ($dom(fh)) {
					$dom(fh).style.height = "";
					if (fh_use_jquery) {
						jQuery("#" + fh + " h3 a[class!='skin']").click(
				                	function(){
                	        				jQuery(this).parent('h3').next('div.hide').toggle("fast");
				                        	jQuery(this).parent('h3').find('a img').toggle("fast");
                        			        	return false;
                        				}
                				);
					}
				}
			});
			myAnim.animate();
		} else if (el[0] == "remove") {
			var fh_node = $dom(fh);
			if (fh_is_admin && fh_view_mode == "fulltitle" && fh_node && fh_node.className == "article" ) {
				// Don't delete admin looking at this in expanded view
			} else {
				var attributes = { 
					height: { to: 0 }
				};
				
				if (!is_ie) {
					attributes.opacity = { to: 0};
				}
				var myAnim = new YAHOO.util.Anim(fh, attributes); 
				myAnim.duration = 0.4;
				wait_interval = 500;
				
				if (firehose_updates_size > 10) {
					myAnim.duration = myAnim.duration * 2;
					if (!firehose_removed_first) {
						wait_interval = wait_interval * 2;
					} else {
						wait_interval = 50;
					}
				}
				firehose_removed_first = 1;
				if (firehose_removals < 10 ) {
					myAnim.onComplete.subscribe(function() {
						var elem = this.getEl();
						if (elem && elem.parentNode) {
							elem.parentNode.removeChild(elem);
						}
					});
					myAnim.animate(); 
				} else {
					var elem = $dom(fh);
					wait_interval = 25;
					if (elem && elem.parentNode) {
						elem.parentNode.removeChild(elem);
					}
				}
			}
		}
		setTimeout(firehose_handle_update, wait_interval);
	} else {
		firehose_reorder();
		firehose_get_next_updates();
	}
}

function firehose_reorder() {
	if (firehose_ordered) {
		var fhlist = $('#firehoselist');
		if (fhlist) {
			firehose_item_count = firehose_ordered.length;
			for (i = 0; i < firehose_ordered.length; ++i) {
				if (!/^\d+$/.test(firehose_ordered[i])) {
					--firehose_item_count;
				}
				$('#firehose-'+firehose_ordered[i]).appendTo(fhlist);
				if ( firehose_future[firehose_ordered[i]] ) {
					$('#ttype-'+firehose_ordered[i]).setClass('future');
				} else {
					$('#ttype-'+firehose_ordered[i]+'.future').setClass('story');
				}
			}
			document.title = "[% sitename %] - " + (console_updating ? "Console" : "Firehose") + " (" + firehose_item_count + ")";
		}
	}

}

function firehose_get_next_updates() {
	var interval = getFirehoseUpdateInterval();
	//alert("fh_get_next_updates");
	fh_is_updating = 0;
	firehose_add_update_timerid(setTimeout(firehose_get_updates, interval));
}


function firehose_get_updates_handler(transport) {
	$('#busy').setClass('hide');
	var response = eval_response(transport);
	var processed = 0;
	firehose_removals = response.update_data.removals;
	firehose_ordered = response.ordered;
	firehose_future = response.future;
	firehose_before = Array(0);
	firehose_after = Array(0);
	for (i = 0; i < firehose_ordered.length; i++) {
		if (i > 0) {
			firehose_before[firehose_ordered[i]] = firehose_ordered[i - 1];
		}
		if (i < (firehose_ordered.length - 1)) {
			firehose_after[firehose_ordered[i]] = firehose_ordered[i + 1];
		}
	}
	if (response.html) {
		json_update(response);
		processed = processed + 1;
	}
	if (response.updates) {
		firehose_updates = response.updates;
		firehose_updates_size = firehose_updates.length;
		firehose_removed_first = 0;
		processed = processed + 1;
		firehose_handle_update();
	}
}

function firehose_get_item_idstring() {
	return $('#firehoselist > [id]').map(function(){
		return this.id.replace(/firehose-(\S+)/, '$1');
	}).get().join(',');
}


function firehose_get_updates(options) {
	options = options || {};
	run_before_update();
	if ((fh_play == 0 && !options.oneupdate) || fh_is_updating == 1) {
		firehose_add_update_timerid(setTimeout(firehose_get_updates, 2000));
	//	alert("wait loop: " + fh_is_updating);
		return;
	}
	if (fh_update_timerids.length > 0) {
		var id = 0;
		while(id = fh_update_timerids.pop()) { clearTimeout(id) };
	}
	fh_is_updating = 1
	var params = {
		op:		'firehose_get_updates',
		ids:		firehose_get_item_idstring(),
		updatetime:	update_time,
		fh_pageval:	firehose_settings.pageval,
		embed:		firehose_settings.is_embedded
	};

	for (i in firehose_settings) {
		params[i] = firehose_settings[i];
	}

	$('#busy').removeClass();
	ajax_update(params, '', { onComplete: firehose_get_updates_handler });
}


function setFirehoseAction() {
	var thedate = new Date();
	var newtime = thedate.getTime();
	firehose_action_time = newtime;
	if (fh_is_timed_out) {
		fh_is_timed_out = 0;
		firehose_play();
		firehose_get_updates();
		if (console_updating) {
			console_update(1, 0)
		}
	}
}

function getSecsSinceLastFirehoseAction() {
	var thedate = new Date();
	var newtime = thedate.getTime();
	var diff = (newtime - firehose_action_time) / 1000;
	return diff;
}

function getFirehoseUpdateInterval() {
	var interval = 45000;
	if (updateIntervalType == 1) {
		interval = 30000;
	}
	interval = interval + (5 * interval * getSecsSinceLastFirehoseAction() / inactivity_timeout);
	if (getSecsSinceLastFirehoseAction() > inactivity_timeout) {
		interval = 3600000;
	}

	return interval;
}

function run_before_update() {
	var secs = getSecsSinceLastFirehoseAction();
	if (secs > inactivity_timeout) {
		fh_is_timed_out = 1;
		$('#message_area').html("Automatic updates have been slowed due to inactivity")
		//firehose_pause();
	}
}

function firehose_play() {
	fh_play = 1;
	setFirehoseAction();
	firehose_set_options('pause', '0');
	$('#message_area').html('');
	$('#pauseorplay').html('Updated');
	$('#play').setClass('hide');
	$('#pause').setClass('show');
}

function is_firehose_playing() {
  return fh_play==1;
}

function firehose_pause() {
	fh_play = 0;
	$('#pause').setClass('hide');
	$('#play').setClass('show');
	$('#pauseorplay').html('Paused');
	firehose_set_options('pause', '1');
}

function firehose_add_update_timerid(timerid) {
	fh_update_timerids.push(timerid);		
}

function firehose_collapse_entry(id) {
	$('#fhbody-'+id+'.body').setClass('hide');
	$('#firehose-'+id).setClass('briefarticle');
	tagsHideBody(id)

}

function firehose_remove_entry(id) {
	var fh = $dom('firehose-' + id);
	if (fh) {
		var attributes = { 
			height: { to: 0 }
		};
		if (!is_ie) {
			attributes.opacity = { to: 0 };
		}
		var myAnim = new YAHOO.util.Anim(fh, attributes); 
		myAnim.duration = 0.5;
		myAnim.onComplete.subscribe(function() {
			var el = this.getEl();
			el.parentNode.removeChild(el);
		});
		myAnim.animate();
	}
}

var firehose_cal_select_handler = function(type,args,obj) { 
	var selected = args[0];
	firehose_settings.issue = '';
	firehose_set_options('startdate', selected.startdate);
	firehose_set_options('duration', selected.duration);
}; 


function firehose_calendar_init( widget ) {
	widget.changeEvent.subscribe(firehose_cal_select_handler, widget, true);
}

function firehose_slider_init() {
	if (!fh_slider_init_set) {
		fh_colorslider = YAHOO.widget.Slider.getHorizSlider("colorsliderbg", "colorsliderthumb", 0, 105, fh_ticksize);
		var fh_set_val_return = fh_colorslider.setValue(fh_ticksize * fh_colors_hash[fh_color] , 1);
		var fh_get_val_return = fh_colorslider.getValue();
		fh_colorslider.subscribe("slideEnd", firehose_slider_end);
	}
}	

function firehose_slider_end(offsetFromStart) {
	var newVal = fh_colorslider.getValue();
	if (newVal) {
		fh_slider_init_set = 1;
	}
	var color = fh_colors[ newVal / fh_ticksize ];
	$dom('fh_slider_img').title = "Firehose filtered to " + color;
	if (fh_slider_init_set) {
		firehose_set_options("color", color)
	}
}

function firehose_slider_set_color(color) {
	fh_colorslider.setValue(fh_ticksize * fh_colors_hash[color] , 1);
}

function firehose_change_section_anon(section) {
	window.location.href= window.location.protocol + "//" + window.location.host + "/firehose.pl?section=" + encodeURIComponent(section) + "&tabtype=tabsection";
}

function pausePopVendorStory(id) {
	vendor_popup_id=id;
	closePopup('vendorStory-26-popup');
	vendor_popup_timerids[id] = setTimeout(vendorStoryPopup, 500);
}

function clearVendorPopupTimers() {
	clearTimeout(vendor_popup_timerids[26]);
}

function vendorStoryPopup() {
	id = vendor_popup_id;
	var title = "<a href='//intel.vendors.slashdot.org' onclick=\"javascript:pageTracker._trackPageview('/vendor_intel-popup/intel_popup_title');\">Intel's Opinion Center</a>";
	var buttons = createPopupButtons("<a href=\"#\" onclick=\"closePopup('vendorStory-" + id + "-popup')\">[X]</a>");
	title = title + buttons;
	var closepopup = function (e) {
	if (!e) var e = window.event;
	var relTarg = e.relatedTarget || e.toElement;
	if (relTarg && relTarg.id == "vendorStory-26-popup") {
		closePopup("vendorStory-26-popup");
	}
	};
	createPopup(getXYForId('sponsorlinks', 0, 0), title, "vendorStory-" + id, "Loading", "", closepopup );
	var params = {};
	params['op'] = 'getTopVendorStory';
	params['skid'] = id;
	ajax_update(params, "vendorStory-" + id + "-contents");
}

function pausePopVendorStory2(id) {
	vendor_popup_id=id;
	closePopup('vendorStory-26-popup');
	vendor_popup_timerids[id] = setTimeout(vendorStoryPopup2, 500);
}

function vendorStoryPopup2() {
	id = vendor_popup_id;
	var title = "<a href='//intel.vendors.slashdot.org' onclick=\"javascript:pageTracker._trackPageview('/vendor_intel-popup/intel_popup_title');\">Intel's Opinion Center</a>";
	var buttons = createPopupButtons("<a href=\"#\" onclick=\"closePopup('vendorStory-" + id + "-popup')\">[X]</a>");
	title = title + buttons;
	var closepopup = function (e) {
		if (!e) var e = window.event;
		var relTarg = e.relatedTarget || e.toElement;
		if (relTarg && relTarg.id == "vendorStory-26-popup") {
			closePopup("vendorStory-26-popup");
		}
	};
	createPopup(getXYForId('sponsorlinks2', 0, 0), title, "vendorStory-" + id, "Loading", "", closepopup );
	var params = {};
	params['op'] = 'getTopVendorStory';
	params['skid'] = id;
	ajax_update(params, "vendorStory-" + id + "-contents");
}

function logToDiv(id, message) {
	$('#'+id).append(message + '<br>');
}


function firehose_open_tab(id) {
	$('#tab-form-'+id).removeClass();
	$dom('tab-input-'+id).focus();
	$('#tab-text-'+id).setClass('hide');
}

function firehose_save_tab(id) {
	ajax_update({
		op:		'firehose_save_tab',
		tabname:	$('#tab-input-'+id).val(),
		section:	firehose_settings.section,
		tabid:		id
	}, '',  { onComplete: json_handler });
	$('#tab-form-'+id).setClass('hide');
	$('#tab-text-'+id).removeClass();
}


var logged_in   = 1;
var login_cover = 0;
var login_box   = 0;
var login_inst  = 0;

function init_login_divs() {
	login_cover = $dom('login_cover');
	login_box   = $dom('login_box');
}

function install_login() {
	if (login_inst)
		return;

	if (!login_cover || !login_box)
		init_login_divs();

	if (!login_cover || !login_box)
		return;

	login_cover.parentNode.removeChild(login_cover);
	login_box.parentNode.removeChild(login_box);

	var top_parent = document.getElementById('top_parent');
	top_parent.parentNode.insertBefore(login_cover, top_parent);
	top_parent.parentNode.insertBefore(login_box, top_parent);
	login_inst = 1;
}

function show_login_box() {
	if (!login_inst)
		install_login();

	if (login_cover && login_box) {
		login_cover.style.display = '';
		login_box.style.display = '';
	}

	return;
}

function hide_login_box() {
	if (!login_inst)
		install_login();

	if (login_cover && login_box) {
		login_box.style.display = 'none';
		login_cover.style.display = 'none';
	}

	return;
}

function check_logged_in() {
	if (!logged_in) {
		show_login_box();
		return 0;
	}
	return 1;
}

var modal_cover = 0;
var modal_box   = 0;
var modal_inst  = 0;

function init_modal_divs() {
	modal_cover = $dom('modal_cover');
	modal_box   = $dom('modal_box');
}

function install_modal() {
	if (modal_inst)
		return;

	if (!modal_cover || !modal_box)
		init_modal_divs();

	if (!modal_cover || !modal_box)
		return;

	modal_cover.parentNode.removeChild(modal_cover);
	modal_box.parentNode.removeChild(modal_box);

	var modal_parent = $dom('top_parent');
	modal_parent.parentNode.insertBefore(modal_cover, modal_parent);
	modal_parent.parentNode.insertBefore(modal_box, modal_parent);
	modal_inst = 1;
}

function show_modal_box() {
	if (!modal_inst)
		install_modal();

	if (modal_cover && modal_box) {
		modal_cover.style.display = '';
		modal_box.style.display = '';
	}

	return;
}

function hide_modal_box() {
	if (!modal_inst)
		install_modal();

	if (modal_cover && modal_box) {
		modal_box.style.display = 'none';
		modal_cover.style.display = 'none';
	}

	return;
}

function getModalPrefs(section, title, tabbed) {
	if (!reskey_static)
		return show_login_box();
	$('#preference_title').html(title);
	ajax_update({
		op:		'getModalPrefs',
		section:	section,
		reskey:		reskey_static,
		tabbed:		tabbed
	}, 'modal_box_content', { onComplete: show_modal_box });
}

function firehose_get_media_popup(id) {
	$('#preference_title').html('Media');
	show_modal_box();
	$('#modal_box_content').html("<h4>Loading...</h4><img src='/images/spinner_large.gif'>");
	ajax_update({
		op:	'firehose_get_media',
		id:	id
	}, 'modal_box_content');
}

function saveModalPrefs() {
	var params = {};
	params['op'] = 'saveModalPrefs';
	params['data'] = jQuery("#modal_prefs").serialize();
	params['reskey'] = reskey_static;
	var handlers = {
		onComplete: function() {
			hide_modal_box();
			if (document.forms['modal_prefs'].refreshable.value)
				document.location=document.URL;
		}
	};
	ajax_update(params, '', handlers);
}

function ajaxSaveSlashboxes() {
	ajax_update({
		op:	'page_save_user_boxes',
		reskey:	reskey_static,
		bids:	$('#slashboxes div.title').map(function(){
				return this.id.slice(0,-6);
			}).get().join(',')
	});
}

function ajaxRemoveSlashbox( id ) {
	if ( $('#slashboxes > #'+id).remove().size() ) {
		ajaxSaveSlashboxes();
	}
}

function displayModalPrefHelp(id) {
	var el = $('#'+id);
	el.css('display', el.css('display')!='none' ? 'none' : 'block');
}

function toggle_filter_prefs() {
	var fps = $dom('filter_play_status');
	var fp  = $dom('filter_prefs');
	if (fps) {
		if (fps.className == "") {
			fps.className = "hide";
			if (fp) {
				fp.className = "";
				setTimeout(firehose_slider_init,500);
			} 
		} else if (fps.className == "hide") {
			fps.className = "";
			if (fp) {
				fp.className = "hide";
			}
		}
	}

}

function admin_signoff(stoid, type, id) {
	var params = {};
	params['op'] = 'admin_signoff';
	params['stoid'] = stoid;
	params['reskey'] = reskey_static;
	ajax_update(params, 'signoff_' + stoid);
	if (type == "firehose") {
		firehose_collapse_entry(id);
	}
}


function scrollWindowToFirehose(fhid) {
	var firehose_y = getOffsetTop($('firehose-' + fhid));
	scroll(viewWindowLeft(), firehose_y);
}

function viewWindowLeft() {
	if (self.pageXOffset) // all except Explorer
	{
		return self.pageXOffset;
	}
	else if (document.documentElement && document.documentElement.scrollTop)
		// Explorer 6 Strict
	{
		return document.documentElement.scrollLeft;
	}
	else if (document.body) // all other Explorers
	{
		return document.body.scrollLeft;
	}
}

function getOffsetTop (el) {
	if (!el)
		return false;
	var ot = el.offsetTop;
	while((el = el.offsetParent) != null)
		ot += el.offsetTop;
	return ot;
}

function firehoseIsInWindow(fhid, just_head) {
	var in_window = isInWindow($('firehose-' + fhid));
	return in_window;
}

function isInWindow(obj) {
	var y = getOffsetTop(obj);

	if (y > viewWindowTop() && y < viewWindowBottom()) {
		return 1;
	}
	return 0;
}

function viewWindowTop() {
	if (self.pageYOffset) // all except Explorer
	{
		return self.pageYOffset;
	}
	else if (document.documentElement && document.documentElement.scrollTop)
		// Explorer 6 Strict
	{
		return document.documentElement.scrollTop;
	}
	else if (document.body) // all other Explorers
	{
		return document.body.scrollTop;
	}
	return;
}

function viewWindowBottom() {
	return viewWindowTop() + (window.innerHeight || document.documentElement.clientHeight);
}

function firehose_get_cur() {
	if (!firehose_cur) {
		firehose_cur = firehose_ordered[0];
		firehose_set_cur(firehose_cur);
	}
	return firehose_cur;
}

function firehose_set_cur(id) {
	firehose_cur = id;
}

function firehose_get_pos_of_id(id) {
	var ret;
	for (var i=0; i< firehose_ordered.length; i++) {
		if (firehose_ordered[i] == id) {
			ret = i;
		}
	}
	return ret;
}

function firehose_go_next() {
	var cur = firehose_get_cur();
	var pos = firehose_get_pos_of_id(cur);
	if (pos < (firehose_ordered.length - 1)) {
		pos++;
	} else {
	}
	firehose_set_cur(firehose_ordered[pos]);
	scrollWindowToFirehose(firehose_cur);
}

function firehose_go_prev() {
	var cur = firehose_get_cur();
	var pos = firehose_get_pos_of_id(cur);
	if (pos>0) {
		pos--;
	}
	firehose_set_cur(firehose_ordered[pos]);
	scrollWindowToFirehose(firehose_cur);

}

function firehose_more() {
	var increment_by = 10;
	firehose_settings.more_num = firehose_settings.more_num + increment_by;
	
	if (((firehose_item_count + increment_by) >= 200) && !fh_is_admin) {
		$('#firehose_more').hide();
	}
	firehose_set_options('more_num', firehose_settings.more_num);
}


