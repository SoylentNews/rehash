// $Id$

var comments;
var root_comments;
var root_comments_hash = {};
var authorcomments;
var behaviors = {
	'default': { ancestors: 'none', parent: 'none', children: 'none', descendants: 'none', siblings: 'none', sameauthor: 'none' }, 
	'focus': { ancestors: 'none', parent: 'none', children: 'prehidden', descendants: 'prehidden', siblings: 'none', sameauthor: 'none' }, 
	'collapse': { ancestors: 'none', parent: 'none', siblings: 'none', sameauthor: 'none', currentmessage: 'oneline', children: 'hidden', descendants: 'hidden'}
};
var displaymode = {};
var futuredisplaymode = {};
var prehiddendisplaymode = {};
var viewmodevalue = { full: 3, oneline: 2, hidden: 1};
var currents = { full: 0, oneline: 0, hidden: 0 };
var commentelements = {};

var root_comment = 0;
var discussion_id = 0;
var user_is_anon = 0;
var user_uid = 0;
var user_threshold = 0;
var user_highlightthresh = 0;
var user_threshold_orig = -9;
var user_highlightthresh_orig = -9;
var loaded = 0;
var shift_down = 0;
var alt_down = 0;


var agt = navigator.userAgent.toLowerCase();
var is_firefox = (agt.indexOf("firefox") != -1);


function updateComment(cid, mode) {
	var existingdiv = fetchEl('comment_'+cid);
	if (existingdiv) {
		if (comments[cid]['subject']) {
			if (mode == 'oneline') {
				fetchEl('comment_link_'+cid).innerHTML = 'Re:';
			} else if (mode == 'full') {
				fetchEl('comment_link_'+cid).innerHTML = comments[cid]['subject'];
			}
		}
		existingdiv.className = mode;
	}

	currents[displaymode[cid]]--;
	currents[mode]++;
	displaymode[cid] = mode;

	return void(0);
}

function updateCommentTree(cid, threshold, subexpand) {
	setDefaultDisplayMode(cid);
	var comment = comments[cid];

	// skip the root comment, if it exists; leave it full, but let user collapse
	// if he chooses, and leave it that way: this comment will not move with
	// T/HT changes
	if ((subexpand || threshold) && cid != root_comment) {
		if (subexpand && subexpand == 1) {
			if (prehiddendisplaymode[cid] == 'oneline' || prehiddendisplaymode[cid] == 'full')
				futuredisplaymode[cid] = 'full';
			else
				futuredisplaymode[cid] = 'hidden';
		} else {
			if (comment['points'] < threshold && (user_is_anon || user_uid != comment['uid']))
				futuredisplaymode[cid] = 'hidden';
			else if (comment['points'] < (user_highlightthresh - (root_comments_hash[cid] ? 1 : 0)))
				futuredisplaymode[cid] = 'oneline';
			else
				futuredisplaymode[cid] = 'full';
		}

		updateDisplayMode(cid, futuredisplaymode[cid], 1);
	}

//	if (subexpand && subexpand == 2) {
//		updateComment(cid, 'hidden');
//		prehiddendisplaymode[cid] = futuredisplaymode[cid];
//	} else if (futuredisplaymode[cid] && futuredisplaymode[cid] != displaymode[cid]) {
		updateComment(cid, futuredisplaymode[cid]);
//	}

	var kidhiddens = 0;
	if (comment['kids'].length) {
		if (!subexpand) {
			if (shift_down && !alt_down && futuredisplaymode[cid] == 'full') {
				subexpand = 1;
			} else if (shift_down && !alt_down && futuredisplaymode[cid] == 'oneline') {
				subexpand = 2;
				threshold = user_threshold;
			}
		}

		for (var kiddie = 0; kiddie < comment['kids'].length; kiddie++) {
			kidhiddens += updateCommentTree(comment['kids'][kiddie], threshold, subexpand);
		}
	}

	return kidHiddens(cid, kidhiddens);
}

function kidHiddens(cid, kidhiddens) {
	var hiddens_cid = fetchEl('hiddens_' + cid);
	if (! hiddens_cid) // race condition, probably: new comment added in between rendering, and JS data structure
		return 0;

	// silly workaround to hide noscript LI bullet
	var hidestring_cid = fetchEl('hidestring_' + cid);
	if (hidestring_cid)
		hidestring_cid.className = 'hide';

	if (displaymode[cid] == 'hidden') {
		hiddens_cid.className = 'hide';
		return kidhiddens + 1;
	} else if (kidhiddens) {
		var kidstring = '<a href="javascript:revealKids(' + cid + ')">' + kidhiddens;
		if (kidhiddens == 1) {
			kidstring += ' hidden comment</a>';
		} else {
			kidstring += ' hidden comments</a>';
		}
		hiddens_cid.innerHTML = kidstring; 
		hiddens_cid.className = 'show';
	} else {
		hiddens_cid.className = 'hide';
	} 

	return 0;
}

function faGetSetting(cid, ctype, relation, prevview, canbelower) {
	var newview = behaviors[ctype][relation];
	if (newview == 'none') {
		return prevview;
	} else if (newview == 'prehidden') {
		return prehiddendisplaymode[cid];
	}

	if ((viewmodevalue[newview] > viewmodevalue[prevview]) || canbelower)
		return newview;

	return prevview; 
}

function getDescendants(cids, first) {
	// don't include first round of kids in descendants, redundant
	var descs = first ? [] : cids;

	for (var i = 0; i < cids.length; i++) {
		var cid = cids[i];
		var kids = comments[cid]['kids'];
		if (kids.length)
			descs = descs.concat(getDescendants(kids)); 
	}

	return descs;
}

function findAffected(type, cid, override) {
	if (!cid) { return }
	var comment = comments[cid];

	var kids = comment['kids'];
	if (kids.length) {
		for (var i = 0; i < kids.length; i++) {
			var kid = kids[i];
			updateDisplayMode(kid, faGetSetting(kid, type, 'children', futuredisplaymode[kid], override));
		}

		var descendants = getDescendants(kids, 1);
		for (var i = 0; i < descendants.length; i++) {
			var desc = descendants[i];
			var thistype = type;
			updateDisplayMode(desc, faGetSetting(desc, thistype, 'descendants', futuredisplaymode[desc], override));
		}
	}
}

function setDefaultDisplayMode(cid) {
	if (displaymode[cid]) { return }

	var comment = fetchEl('comment_' + cid);
	if (!comment) { return }

	var defmode = comment.className;
	if (!defmode) { return }

	futuredisplaymode[cid] = prehiddendisplaymode[cid] = displaymode[cid] = defmode;
}

function updateDisplayMode(cid, mode, newdefault) {
	setDefaultDisplayMode(cid);
	futuredisplaymode[cid] = mode;
	if (newdefault) {
		prehiddendisplaymode[cid] = mode;
	}
}

function refreshDisplayModes(cid) {
	if (cid > 0) {
		updateDisplayMode(cid, 'full', 1);
		findAffected('focus', cid, 0); 
	} else {
		cid = -1 * cid;
		updateDisplayMode(cid, behaviors['collapse']['currentmessage'], 1);
		findAffected('collapse', cid, 1);
	}

	return void(0);
}

function refreshCommentDisplays() {
	var roothiddens = 0;
	for (var root = 0; root < root_comments.length; root++) {
		roothiddens += updateCommentTree(root_comments[root]);
	}
	updateTotals();

	if (roothiddens) {
		$('roothiddens').innerHTML = roothiddens + ' comments are beneath your threshhold';
		$('roothiddens').className = 'show';
	} else {
		$('roothiddens').className = 'hide';
	}
	/* NOTE need to display note for hidden root comments */
	return void(0);
}

function setFocusComment(cid, alone, mods) {
	if (!loaded)
		return false;

	var abscid = Math.abs(cid);
	setDefaultDisplayMode(abscid);
	if ((alone && alone == 2) || (!alone && viewmodevalue[displaymode[abscid]] == viewmodevalue['full']))
		cid = '-' + abscid;

// this doesn't work
//	var statusdiv = $('comment_status_' + abscid);
//	statusdiv.innerHTML = 'Working ...';

//	doModifiers();
	if (!user_is_admin) // XXX: for now, admins-only, for testing
		mods = 1;

	if (!alone && mods) {
		if (mods == 1 || ((mods == 3) && (abscid == cid)) || ((mods == 4) && (abscid != cid))) {
			shift_down = 0;
			alt_down   = 0;
		} else if (mods == 2 || ((mods == 3) && (abscid != cid)) || ((mods == 4) && (abscid == cid))) {
			shift_down = 1;
			alt_down   = 0;
		} else if (mods == 5) {
			shift_down = 1;
			alt_down   = 1;
		}
	}

	if (shift_down && alt_down)
		alone = 1;

	if (alone && alone == 1) {
		var thismode = abscid == cid ? 'full' : 'oneline';
		updateDisplayMode(abscid, thismode, 1);
	} else {
		refreshDisplayModes(cid);
	}
	updateCommentTree(abscid);
	updateTotals();

//	resetModifiers();

//	statusdiv.innerHTML = '';

	if (!commentIsInWindow(abscid)) {
		scrollTo(abscid);
	}

	return false;
}


function changeHT(delta) {
	if (!delta)
		return void(0);

	user_highlightthresh += delta;
	// limit to between -1 and 5
	user_highlightthresh = Math.min(Math.max(user_highlightthresh, -1), 5);

	// T cannot be higher than HT; this also modifies delta
	if (user_threshold > user_highlightthresh)
		user_threshold = user_highlightthresh;

	changeThreshold(user_threshold + ''); // needs to be a string value
}

function changeT(delta) {
	if (!delta)
		return void(0);

	var threshold = user_threshold + delta;
	// limit to between -1 and 5
	threshold = Math.min(Math.max(threshold, -1), 5);

	// HT moves with T, but that is taken care of by changeThreshold()
	changeThreshold(threshold + ''); // needs to be a string value
}

function changeThreshold(threshold) {
	var threshold_num = parseInt(threshold);
	var t_delta = threshold_num + (user_highlightthresh - user_threshold);
	user_highlightthresh = Math.min(Math.max(t_delta, -1), 5);
	user_threshold = threshold_num;

	if ($('currentHT'))
		$('currentHT').innerHTML = user_highlightthresh;

	if ($('currentT'))
		$('currentT').innerHTML = user_threshold;

	if ($('threshold'))
		$('threshold').value = threshold;

	for (var root = 0; root < root_comments.length; root++) {
		updateCommentTree(root_comments[root], threshold);
	}

	updateTotals();
	setPadding();
	savePrefs();

	return void(0);
}

function savePrefs() {
	if ((user_threshold_orig != user_threshold)
		||
	    (user_highlightthresh_orig != user_highlightthresh)
	) {
		var params = [];
		params['op'] = 'comments_set_prefs';
		params['threshold'] = user_threshold;
		params['highlightthresh'] = user_highlightthresh;
		ajax_update(params);

		user_threshold_orig = user_threshold;
		user_highlightthresh_orig = user_highlightthresh;
	}

	return false;
}

function revealKids(cid) {
	if (!loaded)
		return false;

	setDefaultDisplayMode(cid);
	var comment = comments[cid];

	if (comment['kids'].length) {
		for (var kiddie = 0; kiddie < comment['kids'].length; kiddie++) {
			var kid = comment['kids'][kiddie];
			setDefaultDisplayMode(kid);
			if (displaymode[kid] == 'hidden') {
				futuredisplaymode[kid] = 'oneline';
				updateDisplayMode(kid, futuredisplaymode[kid], 1);
				updateComment(kid, futuredisplaymode[kid]);
			}
		}
	}

	updateCommentTree(cid);
	updateTotals();

	return void(0);
}

function scrollTo(cid) {
	var comment_y = getOffsetTop(fetchEl('comment_' + cid));
	scroll(viewWindowLeft(), comment_y);
}

function getOffsetLeft (el) {
	var ol = el.offsetLeft;
	while ((el = el.offsetParent) != null)
		ol += el.offsetLeft;
	return ol;
}

function getOffsetTop (el) {
	var ot = el.offsetTop;
	while((el = el.offsetParent) != null)
		ot += el.offsetTop;
	return ot;
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

function viewWindowRight() {
	return viewWindowLeft() + (window.innerWidth || document.documentElement.clientWidth);
}

function viewWindowBottom() {
	return viewWindowTop() + (window.innerHeight || document.documentElement.clientHeight);
}

function commentIsInWindow(cid) {
	return isInWindow(fetchEl('comment_' + cid));
}

function isInWindow(obj) {
	var y = getOffsetTop(obj);

	if (y > viewWindowTop() && y < viewWindowBottom()) {
		return 1;
	}
	return 0;
}


function replyTo(cid) {
	var replydiv = fetchEl('replyto_' + cid);

	replydiv.innerHTML = '';

	return false;
}


function readRest(cid) {
	var shrunkdiv = fetchEl('comment_shrunk_' + cid);
	if (!shrunkdiv)
		return false; // seems we shouldn't be here ...

	var params = [];
	params['op']  = 'comments_read_rest';
	params['cid'] = cid;
	params['sid'] = discussion_id;

	var handlers = {
// these sometimes go out of order ... ?
//		onLoading: function() {
//			shrunkdiv.innerHTML = 'Loading...';
//		},
		onComplete: function() {
			shrunkdiv.innerHTML = '';
			var sigdiv = fetchEl('comment_sig_' + cid);
			if (sigdiv) {
				sigdiv.className = 'sig'; // show
			}
		}
	};

	shrunkdiv.innerHTML = 'Loading...';
	ajax_update(params, 'comment_body_' + cid, handlers);

	return false;
}

// don't want to actually use this -- pudge
function calcTotals() {
	var currentFull = 0;
	var currentOneline = 0;

	for (var mode in currents) {
		if (currents[mode])
			currents[mode] = 0;
	}

	for (var cid in comments) {
		setDefaultDisplayMode(cid);
		currents[displaymode[cid]]++;
	}
}

function updateTotals() {
	$('currentHidden' ).innerHTML = currents['hidden'];
	$('currentFull'   ).innerHTML = currents['full'];
	$('currentOneline').innerHTML = currents['oneline'];

}


function setPadding() {
	var hidden_padding = ( user_threshold + 1 ) * 10;
	var abbr_padding = (user_highlightthresh - user_threshold) * 10; 
	var full_padding = 60 - hidden_padding - abbr_padding;
	abbr_padding = abbr_padding / 2;


	if ($('comment_hidden')) {
		if($('comment_hidden').className == "horizontal") {
			$('comment_hidden').style.paddingLeft= hidden_padding + 5 + "px";
		} else {
			$('comment_hidden').style.paddingTop= hidden_padding + "px";
		}
	}
	if ($('comment_full')) {
		if($('comment_full').className == "horizontal") {
			$('comment_full').style.paddingRight = full_padding + 5 +"px";
		} else {
			$('comment_full').style.paddingBottom = full_padding + "px";
		}
	}
	if ($('comment_abbr')) {
		if($('comment_abbr').className == "horizontal") {
			$('comment_abbr').style.paddingRight = abbr_padding + 5 +"px";
			$('comment_abbr').style.paddingLeft = abbr_padding + 5 +"px";
		} else {
			$('comment_abbr').style.paddingRight = abbr_padding + "px";
			$('comment_abbr').style.paddingLeft = abbr_padding + "px";
		}
	}
}

function enableControls() {
	$('commentControlBoxStatus').className = 'hide';
	loaded = 1;
}

function selectParent(cid, collapse) {
	if (!loaded)
		return false;

	var comment = comments[cid];
	if (comment && fetchEl('comment_' + cid)) {
		var was_hidden = 0;
		if (displaymode[cid] == 'hidden')
			was_hidden = 1;

		setFocusComment(cid, (collapse ? 2 : 1));

		// update textual hidden counts
		if (was_hidden) {
			var parent = comments[cid]['pid'];
			if (parent) {
				while (comments[parent]['pid']) {
					parent = comments[parent]['pid'];
				}

				updateCommentTree(parent);
			}
		}

		return false;
	} else {
		return true; // follow link
	}
	return false;
}

function cloneObject(what) {
	for (i in what) {
		if (typeof what[i] == 'object') {
			this[i] = new cloneObject(what[i]);
		} else {
			this[i] = what[i];
		}
	}
}

function loadAllElements(tagname) {
	var elements = document.getElementsByTagName(tagname);

	for (var i = 0; i < elements.length; i++) {
		var e = elements[i];
		commentelements[e.id] = e;
	}

	return;
}

function fetchEl(str) {
	return loaded
		? (is_firefox ? commentelements[str] : $(str))
		: $(str);
}

function finishLoading() {
	if (is_firefox) {
		loadAllElements('div');
		loadAllElements('li');
		loadAllElements('a');
	}

	if (root_comment)
		currents['full'] += 1;

	for (var i = 0; i < root_comments.length; i++) {
		root_comments_hash[ root_comments[i] ] = 1;
	}

	if (user_threshold_orig == -9 || user_highlightthresh_orig == -9) {
		user_threshold_orig = user_threshold;
		user_highlightthresh_orig = user_highlightthresh;
	}

	//window.onbeforeunload = function () { savePrefs() };
	//window.onunload = function () { savePrefs() };

	updateTotals();
	setPadding();
	enableControls();
}

function floatButtons () {
	$('gods').className='thor';
}

function resetModifiers () {
	shift_down = 0;
	alt_down   = 0;
}

function doModifiers () {
	var ev = window.event;
	shift_down = 0;
	alt_down   = 0;

	if (ev) {
		if (ev.modifiers) {
			if (e.modifiers & Event.SHIFT_MASK)
				shift_down = 1;
			if (e.modifiers & Event.ALT_MASK)
				alt_down = 1;
		} else {
			if (ev.shiftKey)
				shift_down = 1;
			if (ev.altKey)
				alt_down = 1;
		}
	}
}

function doModerate(el) {
	var matches = el.name.match(/_(\d+)$/);
	var cid = matches[1];

	if (!cid)
		return true;

	el.disabled = 'true';
	var params = [];
	params['op']  = 'comments_moderate_cid';
	params['cid'] = cid;
	params['sid'] = discussion_id;
	params['msgdiv'] = 'reasondiv_' + cid;
	params['reason'] = el.value;
	params['reskey'] = comments_moderate_reskey;

	var handlers = {
		onComplete: json_handler
	};

	ajax_update(params, '', handlers);

	return false;
}

