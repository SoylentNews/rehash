// $Id$

var comments;
var root_comments;
var noshow_comments;
var init_hiddens = [];
var fetch_comments = [];
var update_comments = {};
var root_comments_hash = {};
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
var thresh_totals = {};

var boxStatusQueue = [];
var comment_body_reply = [];
var root_comment = 0;
var discussion_id = 0;
var user_is_admin = 0;
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

/* thread functions */
function updateComment(cid, mode) {
	var existingdiv = fetchEl('comment_' + cid);
	if (existingdiv && mode != displaymode[cid]) {
		var cl = fetchEl('comment_link_' + cid);
		if (!cl) { // be more selective?
			fetch_comments.push(cid);
		} else {
			setShortSubject(cid, mode, cl);
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
			futuredisplaymode[cid] = determineMode(cid, threshold, user_highlightthresh);
		}

		updateDisplayMode(cid, futuredisplaymode[cid], 1);
	}

//	if (subexpand && subexpand == 2) {
//		updateComment(cid, 'hidden');
//		prehiddendisplaymode[cid] = futuredisplaymode[cid];
//	} else if (futuredisplaymode[cid] && futuredisplaymode[cid] != displaymode[cid]) {
		//updateComment(cid, futuredisplaymode[cid]);
		if (displaymode[cid] != futuredisplaymode[cid])
			update_comments[cid] = futuredisplaymode[cid];
//	}

	var kidhiddens = 0;
	if (comment && comment['kids'] && comment['kids'].length) {
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
//	if (!user_is_admin) // XXX: for now, admins-only, for testing
//		mods = 1;

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
	finishCommentUpdates();

//	resetModifiers();

//	statusdiv.innerHTML = '';

	if (!commentIsInWindow(abscid)) {
		scrollWindowTo(abscid);
	}

	return false;
}

function changeTHT(t_delta, ht_delta) {
	if (!t_delta && !ht_delta)
		return void(0);

	user_threshold       += t_delta;
	user_highlightthresh += ht_delta;
	// limit to between -1 and 5
	user_threshold       = Math.min(Math.max(user_threshold,       -1), 5);
	user_highlightthresh = Math.min(Math.max(user_highlightthresh, -1), 5);

	// T cannot be higher than HT; this also modifies delta
	if (user_threshold > user_highlightthresh)
		user_threshold = user_highlightthresh;

	changeThreshold(user_threshold + ''); // needs to be a string value
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
	finishCommentUpdates();

	setPadding();
	savePrefs();

	return void(0);
}


/* thread kid/hidden functions */
function kidHiddens(cid, kidhiddens) {
	var hiddens_cid = fetchEl('hiddens_' + cid);
	if (! hiddens_cid) // race condition, probably: new comment added in between rendering, and JS data structure
		return 0;

	// silly workaround to hide noscript LI bullet
	var hidestring_cid = fetchEl('hidestring_' + cid);
	if (hidestring_cid)
		hidestring_cid.className = 'hide';

	// may not be changed yet, that's OK
	if (futuredisplaymode[cid] == 'hidden') {
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
	finishCommentUpdates();

	return void(0);
}

// update textual hidden counts
function updateHiddens(cids) {
	if (!cids || !cids.length)
		return;

	var seen = {};
	OUTER: for (var i = 0; i < cids.length; i++) {
		var cid = cids[i];
		while (cid && comments[cid] && comments[cid]['pid']) {
			cid = comments[cid]['pid'];
			if (seen[cid])
				continue OUTER;
			seen[cid] = 1;
		}
		updateCommentTree(cid);
	}
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

		if (was_hidden)
			updateHiddens([cid]);

		return false;
	} else {
		return true; // follow link
	}
	return false;
}

function setShortSubject(cid, mode, cl) {
	if (!cl)
		cl = fetchEl('comment_link_' + cid);

	// subject is there only if it is a "reply"
	// check pid to make sure parent is there at all ... check visibility too?
	if (comments[cid]['subject'] && comments[cid]['pid']) {
		var thisdiv = fetchEl('comment_' + comments[cid]['pid']);
		if (thisdiv) {
			setDefaultDisplayMode(comments[cid]['pid']);
			if (!mode)
				mode = displaymode[cid];
			if (mode == 'full' || (mode == 'oneline' && displaymode[comments[cid]['pid']] == 'hidden')) {
				cl.innerHTML = comments[cid]['subject'];
			} else if (mode == 'oneline') {
				cl.innerHTML = 'Re:';
			}
		}
	}
}


/* thread utility functions */
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

function getSliderTotals(thresh, hthresh) {
	// we are precalculating, so this code should never be used!
	// here for testing -- pudge
/*	if (!thresh_totals[thresh] || !thresh_totals[thresh][hthresh]) {
		if (!thresh_totals[thresh])
			thresh_totals[thresh]  = {};
		thresh_totals[thresh][hthresh] = {};
		thresh_totals[thresh][hthresh][ viewmodevalue['hidden']]  = 0;
		thresh_totals[thresh][hthresh][ viewmodevalue['oneline']] = 0;
		thresh_totals[thresh][hthresh][ viewmodevalue['full']]    = 0;

		for (var cid in comments) {
			var mode = determineMode(cid, thresh, hthresh);
			thresh_totals[thresh][hthresh][ viewmodevalue[mode] ]++;
		}
	}
*/

	return [
		thresh_totals[thresh][hthresh][viewmodevalue['hidden']],
		thresh_totals[thresh][hthresh][viewmodevalue['oneline']],
		thresh_totals[thresh][hthresh][viewmodevalue['full']]
	];
}

function determineMode(cid, thresh, hthresh) {
	if (!hthresh)
		hthresh = user_highlightthresh;

	if (comments[cid]['points'] < thresh && (user_is_anon || user_uid != comments[cid]['uid']))
		return 'hidden';
	else if (comments[cid]['points'] < (hthresh - (root_comments_hash[cid] ? 1 : 0)))
		return 'oneline';
	else
		return 'full';
}

function finishCommentUpdates() {
	for (var cid in update_comments) {
		updateComment(cid, update_comments[cid]);
	}

	ajaxFetchComments(fetch_comments);

	updateTotals();
	update_comments = {};
	fetch_comments = [];
}

// not currently used
function refreshCommentDisplays() {
	var roothiddens = 0;
	for (var root = 0; root < root_comments.length; root++) {
		roothiddens += updateCommentTree(root_comments[root]);
	}
	finishCommentUpdates();

	if (roothiddens) {
		$('roothiddens').innerHTML = roothiddens + ' comments are beneath your threshhold';
		$('roothiddens').className = 'show';
	} else {
		$('roothiddens').className = 'hide';
	}
	/* NOTE need to display note for hidden root comments */
	return void(0);
}


/* misc. functions */
function ajaxFetchComments(cids) {
	if (cids && !cids.length)
		return;

	var params = [];
	params['op']            = 'comments_fetch';
	params['cids']          = (cids || noshow_comments);
	params['cid']           = root_comment;
	params['discussion_id'] = discussion_id;
	params['reskey']        = reskey_static;

	var handlers = {
		onComplete: function (transport) {
			var response = eval_response(transport);
			json_update(response);
			updateHiddens(cids);
			for (var i = 0; i < cids.length; i++) {
				// this is needed for Firefox
				// better way to do automatically?
				loadNamedElement('comment_link_' + cids[i]);
				loadNamedElement('comment_shrunk_' + cids[i]);
				loadNamedElement('comment_sig_' + cids[i]);
				setShortSubject(cids[i]);
			}
			boxStatus(0);
		}
	};

	boxStatus(1);
	ajax_update(params, '', handlers);

	if (cids) {
		var remove = [];
		for (var i = 0; i < cids.length; i++) {
			// no Array.indexOf in Safari etc.
			for (var j = 0; j < noshow_comments.length; j++) {
				if (cids[i] == noshow_comments[j]) {
					remove.push(j);
				}
			}
		}
		for (var i = 0; i < remove.length; i++) {
			noshow_comments.splice(remove[i], 1, 0);
		}

		// remove zeroes added above
		for (var i = (noshow_comments.length-1); i >= 0; i--) {
			if (noshow_comments[i] == 0)
				noshow_comments.splice(i, 1);
		}

	} else {
		noshow_comments = [];
	}

	return false;
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
		params['reskey'] = reskey_static;
		ajax_update(params);

		user_threshold_orig = user_threshold;
		user_highlightthresh_orig = user_highlightthresh;
	}

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
	params['reskey'] = reskey_static;

	var handlers = {
		onComplete: json_handler
	};

	ajax_update(params, '', handlers);

	return false;
}

// not used yet
function replyTo(cid) {
	var replydiv = fetchEl('replyto_' + cid);

	replydiv.innerHTML = '';

	return false;
}

function quoteReply(pid) {
	$('postercomment').value = comment_body_reply[pid] + "\n\n" + $('postercomment').value;
}

/* utility functions */
function loadAllElements(tagname) {
	var elements = document.getElementsByTagName(tagname);

	for (var i = 0; i < elements.length; i++) {
		var e = elements[i];
		commentelements[e.id] = e;
	}

	return;
}

function loadNamedElement(name) {
	commentelements[name] = $(name);
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

	updateHiddens(init_hiddens);

	//window.onbeforeunload = function () { savePrefs() };
	//window.onunload = function () { savePrefs() };

	updateTotals();
	enableControls();

	//setTimeout('ajaxFetchComments()', 10*1000);
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


/* UI functions */
function resetModifiers () {
	shift_down = 0;
	alt_down   = 0;
}

function doModifiers () {
	return;
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

function boxStatus(bool) {
	var box = $('commentControlBoxStatus');
	if (bool) {
		boxStatusQueue.push(1);
		box.className = '';
	} else {
		boxStatusQueue.shift();
		if (!boxStatusQueue.length)
			box.className = 'hide';
	}
}

function enableControls() {
	boxStatus(0);
	setPadding();
	d2act();
	$('d2act').className = '';
	loaded = 1;
}

function floatButtons () {
	$('gods').className='thor';
}

function d2act () {
	Position.prepare();
	var xy = Position.cumulativeOffset($('commentwrap'));
	var gd = $('d2act'); 
	if (gd) {
		xy[1] = xy[1] - Position.deltaY;
		if ($('d2out').className == 'horizontal')
			xy[1] = xy[1] - gd.offsetHeight;

		if (xy[1] < -14) {
			gd.style.top      = '4px';
			gd.style.position = 'fixed';
			gd.style.left     = '1em';
		} else {
			gd.style.display  = 'inline';
			gd.style.position = 'fixed';
			gd.style.top      = xy[1] + 'px';
			gd.style.left     = '1em';
		} 
	}
}

function toggleDisplayOptions() {
	var gods  = $('gods');
	var d2opt = $('d2opt');
	var d2out = $('d2out');

	// update user prefs
	var params = [];

	if (gods.style.display == 'none') {
		d2act();
		d2opt.style.display = 'none';
		gods.style.display  = 'block';

		params['comments_control'] = 'vertical';

	} else if (d2out.className == 'horizontal') {
		gods.style.display  = 'none';
		d2opt.style.display = 'inline';

		d2out.className = '';
		gCommentControlWidget.setOrientation('Y');
		$('comment_full').className = '';
		$('comment_abbr').className = '';
		$('comment_hidden').className = '';
		$('comment_divider1').className = '';
		$('comment_divider2').className = '';
		$('comment_divider3').className = '';
		$('comment_divider4').className = '';
		$('com_arrow_up2').src   = $('com_arrow_up1').src   = $('com_arrow_up1').src.replace(/left/, 'up');
		$('com_arrow_down2').src = $('com_arrow_down1').src = $('com_arrow_down1').src.replace(/right/, 'down');

		setPadding();
		params['comments_control'] = '';

	} else { // vertical
		gods.style.display  = 'none';

		d2out.className = 'horizontal';
		gCommentControlWidget.setOrientation('X');
		$('comment_full').className = 'horizontal';
		$('comment_abbr').className = 'horizontal';
		$('comment_hidden').className = 'horizontal';
		$('comment_divider1').className = 'comment_divider horizontal';
		$('comment_divider2').className = 'comment_divider horizontal';
		$('comment_divider3').className = 'comment_divider horizontal';
		$('comment_divider4').className = 'comment_divider horizontal';
		$('com_arrow_up2').src   = $('com_arrow_up1').src   = $('com_arrow_up1').src.replace(/up/, 'left');
		$('com_arrow_down2').src = $('com_arrow_down1').src = $('com_arrow_down1').src.replace(/down/, 'right');

		setPadding();
		d2act();
		gods.style.display  = 'block';

		params['comments_control'] = 'horizontal';
	}

	params['op'] = 'comments_set_prefs';
	params['reskey'] = reskey_static;
	ajax_update(params);

	return false;
}

function setPadding() {
	var hidden_padding = ( user_threshold + 1 ) * 10;
	var abbr_padding = (user_highlightthresh - user_threshold) * 10; 
	var full_padding = 60 - hidden_padding - abbr_padding;
	abbr_padding = abbr_padding / 2;

	var com_hide = $('comment_hidden');
	var com_full = $('comment_full');
	var com_abbr = $('comment_abbr');

	if (com_hide) {
		if (com_hide.className == 'horizontal') {
			com_hide.style.paddingLeft = hidden_padding + 5 + 'px';
			com_hide.style.paddingTop  = 0;
		} else {
			com_hide.style.paddingTop  = hidden_padding + 'px';
			com_hide.style.paddingLeft = 0;
		}
	}
	if (com_full) {
		if (com_full.className == 'horizontal') {
			com_full.style.paddingRight  = full_padding + 5 + 'px';
			com_full.style.paddingBottom = 0;
		} else {
			com_full.style.paddingBottom = full_padding + 'px';
			com_full.style.paddingRight  = 0;
		}
	}
	if (com_abbr) {
		if (com_abbr.className == 'horizontal') {
			com_abbr.style.paddingRight = abbr_padding + 5 + 'px';
			com_abbr.style.paddingLeft  = abbr_padding + 5 + 'px';
		} else {
			com_abbr.style.paddingRight = abbr_padding + 'px';
			com_abbr.style.paddingLeft  = abbr_padding + 'px';
		}
	}
}

function updateTotals() {
	$('currentHidden' ).innerHTML = currents['hidden'];
	$('currentFull'   ).innerHTML = currents['full'];
	$('currentOneline').innerHTML = currents['oneline'];
}

function scrollWindowTo(cid) {
	var comment_y = getOffsetTop(fetchEl('comment_' + cid));
	if ($('comment_hidden').className == 'horizontal')
		comment_y -= 60;
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


/* code for the draggable threshold widget */

function partitionedRange( range, partitions ) {
	return [].concat(range[0], partitions, range[1]);
}

function pinToRange( range, partitions ) {
	var result = partitions.slice();
	var hi = range[0], lo = range[1];

	function pin( x ) {
		return hi = Math.min(Math.max(x, lo), hi);
	}

	for ( var i=0; i<partitions.length; ++i )
		result[i] = pin(partitions[i]);

	return result;
}

function boundsToSizes( bounds, scaleFactor ) {
	if ( scaleFactor === undefined )
		scaleFactor = 1;

	var sizes = new Array(bounds.length-1);
	for ( var i=0; i<sizes.length; ++i )
		sizes[i] = Math.abs(bounds[i+1]-bounds[i]) * scaleFactor;
	return sizes;
}

Y_UNITS_IN_PIXELS = 20;
X_UNITS_IN_EM = 4;

ABBR_BAR = 0;
HIDE_BAR = 1;


YAHOO.namespace("slashdot");

YAHOO.slashdot.ThresholdWidget = function( initialOrientation ) {
	this.PANEL_KINDS = [ "full", "abbr", "hide" ];
	this.displayRange = [6, -1];
	this.constraintRange = [5, -1];
	this.getEl_cache = new Object();

	this.orientations = new Object();
	this.orientations["Y"] = { axis: "Y", posAttr: "top", sizeAttr: "height", getPos: YAHOO.util.Dom.getY, units: "px", scale: Y_UNITS_IN_PIXELS };
	this.orientations["X"] = { axis: "X", posAttr: "left", sizeAttr: "width", getPos: YAHOO.util.Dom.getX, units: "em", scale: X_UNITS_IN_EM };
	this.orientations["X"].other = this.orientations["Y"];
	this.orientations["Y"].other = this.orientations["X"];

  	if ( initialOrientation === undefined )
		initialOrientation = "Y";
	this.orient = this.orientations[initialOrientation];

	function initBar( id, whichBar, parentWidget ) {
		id = "ccw-"+id+"-bar";

		var el = YAHOO.util.Dom.get(id+"-pos");

		var dd = new YAHOO.slashdot.ThresholdBar(el, "ccw", {scroll:false});
		dd.setOuterHandleElId(id+"-tab");
		dd.setHandleElId(id);
		dd.whichBar = whichBar;
		dd.parentWidget = parentWidget;

		return dd;
	}

	var abbrBar = initBar("abbr", ABBR_BAR, this);
	var hideBar = initBar("hide", HIDE_BAR, this);

	this.dragBars = [ abbrBar, hideBar ];
}

YAHOO.slashdot.ThresholdWidget.prototype = new Object();

YAHOO.slashdot.ThresholdWidget.prototype._getEl = function( id ) {
	var el = this.getEl_cache[id];
	if ( el === undefined )
		el = this.getEl_cache[id] = YAHOO.util.Dom.get(id);
	return el;
}

YAHOO.slashdot.ThresholdWidget.prototype.setTHT = function( T, HT ) {
	this._setTs(pinToRange(this.constraintRange, [HT, T]));
}

YAHOO.slashdot.ThresholdWidget.prototype.getTHT = function() {
	return this.displayedTs.slice().reverse();
}

YAHOO.slashdot.ThresholdWidget.prototype.setCounts = function( counts ) {
	// counts is an array: [ num-hidden, num-abbreviated, num-full ]
	if ( counts === undefined )
		counts = this._requestCounts();

	this._getEl("currentHidden").innerHTML = counts[0];
	this._getEl("currentOneline").innerHTML = counts[1];
	this._getEl("currentFull").innerHTML = counts[2];
}


YAHOO.slashdot.ThresholdWidget.prototype._requestCounts = function() {
	return getSliderTotals(this.displayedTs[HIDE_BAR], this.displayedTs[ABBR_BAR]);
}

YAHOO.slashdot.ThresholdWidget.prototype._onBarStartDrag = function( whichBar ) {
	YAHOO.util.Dom.addClass(this._getEl("ccw-control"), "ccw-active");
	this.preDragTs = this.displayedTs.slice();
}

YAHOO.slashdot.ThresholdWidget.prototype._onBarEndDrag = function( whichBar ) {
	YAHOO.util.Dom.removeClass(this._getEl("ccw-control"), "ccw-active");

	var deltas = this.displayedTs.slice();
	for ( var i=0; i<deltas.length; ++i )
		deltas[i] -= this.preDragTs[i];

	changeTHT(deltas[HIDE_BAR], deltas[ABBR_BAR]);
}

YAHOO.slashdot.ThresholdWidget.prototype.setOrientation = function( newAxis ) {
	if ( newAxis != this.orient.axis ) {
		this.orient = this.orientations[newAxis];
		this._setTs();
	}
}

YAHOO.slashdot.ThresholdWidget.prototype._emToPixels = function() {
	return this._getEl("ccw-one-em-wide").scrollWidth;
}

YAHOO.slashdot.ThresholdWidget.prototype._setTs = function( newTs, draggingBar ) {
	var w = this;
	var o = w.orient;
	var offset = 0;

	function fixPanel( id, newSize ) {
		var textPos = w._getEl("ccw-"+id+"-count-pos").style;
		var phrase = w._getEl("ccw-"+id+"-phrase").style;

		textPos.display = (newSize>0) ? "block" : "none";
		if ( o.axis == "Y" ) {
		  textPos.top = (newSize/2) + o.units;
		  phrase.display = "inline";
		} else {
		  textPos.top = "0";
		  phrase.display = (newSize>o.scale) ? "inline" : "none";
		}

		var panel = w._getEl("ccw-"+id+"-panel").style;
		panel[ o.posAttr ] = offset + o.units;
		panel[ o.other.posAttr ] = 0;
		panel[ o.sizeAttr ] = newSize + o.units;
		panel[ o.other.sizeAttr ] = "100%";

		offset += newSize;
	}

	if ( newTs === undefined )
		newTs = this.displayedTs;

	if ( draggingBar !== undefined ) {
		var pin = draggingBar==ABBR_BAR ? Math.min : Math.max;
		var other = 1-draggingBar;
		newTs[other] = pin(newTs[draggingBar], this.preDragTs[other]);
	}
	this.displayedTs = newTs;

	for ( i=ABBR_BAR; i<=HIDE_BAR; ++i )
		if ( i != draggingBar )
			this.dragBars[i].setPosFromT(newTs[i]);

	var sizes = boundsToSizes(partitionedRange(this.displayRange, newTs), o.scale);
	for ( var i=0; i<this.PANEL_KINDS.length; ++i )
		fixPanel(this.PANEL_KINDS[i], sizes[i]);

	this.setCounts(this._requestCounts());
    	return newTs;
}




YAHOO.slashdot.ThresholdBar = function( barElId, sGroup, config ) {
	if ( barElId )
		this.init(barElId, sGroup, config);
}

YAHOO.extend(YAHOO.slashdot.ThresholdBar, YAHOO.util.DD);

YAHOO.slashdot.ThresholdBar.prototype.posToT = function( pos ) {
	var el = this.getEl();
	if ( el.style.display != "block" )
		return null;

	var w = this.parentWidget;
	var o = w.orient;
	var widgetStart = o.getPos(w._getEl("ccw-control"));

	if ( pos === undefined )
	  pos = o.getPos(el);

	var scale = o.scale;
	if ( o.units == "em" )
		scale *= w._emToPixels();
	return w.displayRange[0] - Math.round((pos - widgetStart) / scale);
}

YAHOO.slashdot.ThresholdBar.prototype.setPosFromT = function( x ) {
	if ( this.posToT() != x ) {
		var w = this.parentWidget;
		var o = w.orient;
		var elStyle = this.getEl().style;
		elStyle[ o.posAttr ] = ((w.displayRange[0]-x) * o.scale) + o.units;
		elStyle[ o.other.posAttr ] = 0;
		elStyle.display = "block";
	}
}

YAHOO.slashdot.ThresholdBar.prototype.fixConstraints = function() {
	var w = this.parentWidget;
	var o = w.orient;

	var scale = o.scale;
	if ( o.units == "em" )
		scale *= w._emToPixels();

	this.resetConstraints();
	this[ "set" + o.other.axis + "Constraint" ](0, 0);

	var thisT = this.draggingTs[this.whichBar];
	var availableSpace = boundsToSizes(partitionedRange(w.constraintRange, [thisT]), scale);
	this[ "set" + o.axis + "Constraint" ](availableSpace[0], availableSpace[1], scale);
}

YAHOO.slashdot.ThresholdBar.prototype.startDrag = function( x, y ) {
	var w = this.parentWidget;
	w._onBarStartDrag(this.whichBar);
	this.draggingTs = w.displayedTs.slice();
	this.fixConstraints();
}

YAHOO.slashdot.ThresholdBar.prototype.onDrag = function( e ) {
	var newT = this.posToT();
	if ( this.draggingTs[this.whichBar] != newT ) {
		this.draggingTs[this.whichBar] = newT;
		this.draggingTs = this.parentWidget._setTs(this.draggingTs, this.whichBar);
	}
}

YAHOO.slashdot.ThresholdBar.prototype.endDrag = function( e ) {
	this.parentWidget._onBarEndDrag(this.whichBar);
}

YAHOO.slashdot.ThresholdBar.prototype.alignElWithMouse = function( el, iPageX, iPageY ) {
	var w = this.parentWidget;
	var o = w.orient;

	var oCoord = this.getTargetCoord(iPageX, iPageY);
	var newThreshold = this.posToT( oCoord[ o.axis.toLowerCase() ] );
	this.setPosFromT(newThreshold);

	var newPos = YAHOO.util.Dom.getXY(el);
	oCoord = { x:newPos[0], y:newPos[1] };

	this.cachePosition(oCoord.x, oCoord.y);
	this.autoScroll(oCoord.x, oCoord.y, el.offsetHeight, el.offsetWidth);
}
