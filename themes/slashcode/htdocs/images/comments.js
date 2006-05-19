var comments;
var root_comments;
var authorcomments;
var behaviors = {
	'default': { ancestors: 'none', parent: 'none', children: 'none', descendants: 'none', siblings: 'none', sameauthor: 'none' }, 
	'focus': { ancestors: 'none', parent: 'none', children: 'prehidden', descendants: 'prehidden', siblings: 'none', sameauthor: 'none' }, 
	'collapse': { ancestors: 'none', parent: 'none', siblings: 'none', sameauthor: 'none', currentmessage: 'oneline', children: 'hidden', descendants: 'hidden'} };
var behaviorrange = ['none', 'full', 'oneline', 'hidden'];
var displaymode = { 0: 1 };
var futuredisplaymode = {};
var prehiddendisplaymode = {};
var defaultdisplaymode = {};
var viewmodevalue = { full: 3, oneline: 2, hidden: 1};
var currents = { full: 0, oneline: 0, hidden: 0 };

var root_comment = 0;
var discussion_id = 0;
var user_is_anon = 0;
var user_uid = 0;
var user_threshold = 0;
var user_highlightthresh = 0;

function updateComment(cid, mode) {
	var existingdiv = $('comment_' + cid);
	if (existingdiv) {
		existingdiv.className = mode;
		var existinglink = $('comment_link_' + cid);
		if (existinglink) {
			var plusminus = (mode == 'full') ? '-' : ''; 
			existinglink.onclick = function() { return setFocusComment(plusminus + cid) };
		}
	}

	currents[displaymode[cid]]--;
	currents[mode]++;
	displaymode[cid] = mode;

	return void(0);
}

function updateCommentTree(cid, threshold) {
	setDefaultDisplayMode(cid);
	var comment = comments[cid];

	// skip the root comment, if it exists; leave it full, but let user collapse
	// if he chooses, and leave it that way: this comment will not move with
	// T/HT changes
	if (threshold && cid != root_comment) {
		if (comment['points'] < threshold && (user_is_anon || user_uid != comment['uid'])) {
			futuredisplaymode[cid] = 'hidden';
		} else if (comment['points'] < user_highlightthresh) {
			futuredisplaymode[cid] = 'oneline';
		} else {
			futuredisplaymode[cid] = 'full';
		}
		updateDisplayMode(cid, futuredisplaymode[cid], 1);
	}

	if (futuredisplaymode[cid] != displaymode[cid]) { 
		updateComment(cid, futuredisplaymode[cid]);
	}

	var kidhiddens = 0;
	if (comment['kids'].length) {
		for (var kiddie = 0; kiddie < comment['kids'].length; kiddie++) {
			kidhiddens += updateCommentTree(comment['kids'][kiddie], threshold);
		}
	}

	return kidHiddens(cid, kidhiddens);
}

function kidHiddens(cid, kidhiddens) {
	var hiddens_cid = $('hiddens_' + cid);
	if (! hiddens_cid) // race condition, probably: new comment added in between rendering, and JS data structure
		return 0;

	// silly workaround to hide noscript LI bullet
	var hidestring_cid = $('hidestring_' + cid);
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

	var comment = $('comment_' + cid);
	if (!comment) { return }

	var defmode = comment.className;
	if (!defmode) { return }

	futuredisplaymode[cid] = prehiddendisplaymode[cid] = defaultdisplaymode[cid] = displaymode[cid] = defmode;
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

function setFocusComment(cid, alone) {
	var abscid = Math.abs(cid);

// this doesn't work
//	var statusdiv = $('comment_status_' + abscid);
//	statusdiv.innerHTML = 'Working ...';

	if (!alone)
		refreshDisplayModes(cid);
	updateCommentTree(abscid);
	updateTotals();

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

	return void(0);
}

function revealKids(cid) {
	var comment = comments[cid];

	if (comment['kids'].length) {
		for (var kiddie = 0; kiddie < comment['kids'].length; kiddie++) {
			var kid = comment['kids'][kiddie];
			if (displaymode[kid] == 'hidden') {
				futuredisplaymode[kid] = 'oneline';
				updateDisplayMode(kid, futuredisplaymode[kid], 1);
				updateComment(kid, futuredisplaymode[kid]);
			}
		}
	}

	kidHiddens(cid, 0);
	updateTotals();

	return void(0);
}

function scrollTo(cid) {
	var comment_y = getOffsetTop($('comment_' + cid));
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
	return isInWindow($('comment_' + cid));
}

function isInWindow(obj) {
	var y = getOffsetTop(obj);

	if (y > viewWindowTop() && y < viewWindowBottom()) {
		return 1;
	}
	return 0;
}


function replyTo(cid) {
	var replydiv = $('replyto_' + cid);

	replydiv.innerHTML = '';

	return false;
}


function readRest(cid) {
	var shrunkdiv = $('comment_shrunk_' + cid);
	if (!shrunkdiv)
		return false; // seems we shouldn't be here ...

	var params = [];
	params['op']  = 'comments_read_rest';
	params['cid'] = cid;
	params['sid'] = discussion_id;

	var handlers = {
		onLoading: function() {
			shrunkdiv.innerHTML = 'Loading...';
		},
		onComplete: function() {
			shrunkdiv.innerHTML = '';
			var sigdiv = $('comment_sig_' + cid);
			if (sigdiv) {
				sigdiv.className = 'sig'; // show
			}
		}
	};

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

function enableControls() {
	var controls = ['ht_worse', 'ht_better', 't_more', 't_less'];
	for (var i = 0; i < controls.length; i++) {
		$(controls[i]).disabled = false;
	}
}

function selectParent(cid) {
	var comment = comments[cid];
	if (comment && $('comment_' + cid)) {
		updateDisplayMode(cid, 'full', 1);
		setFocusComment(cid, 1);

		return false;
	} else {
		return true; // follow link
	}
	return false;
}
