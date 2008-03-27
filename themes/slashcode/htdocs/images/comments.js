// $Id$

var comments;
var root_comments;
var noshow_comments;
var pieces_comments;
var placeholder_comments = [];
var placeholder_no_update = {};
var abbrev_comments = {};
var init_hiddens = [];
var fetch_comments = [];
var fetch_comments_pieces = {};
var update_comments = {};
var root_comments_hash = {};
var last_updated_comments = [];
var last_updated_comments_index = 0;
var reply_link_html = {};
var comments_started = 0;
var current_cid = 0;
var more_comments_num;
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

var ajaxCommentsWaitQueue = [];
var boxStatusQueue = [];
var comment_body_reply = [];
var root_comment = 0;
var discussion_id = 0;
var user_is_subscriber = 0;
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
var ctrl_down = 0;
var meta_down = 0;
var d2_seen = '';
var low_bandwidth = 0;

var adTimerSecs;
var adTimerClicks;
var adTimerInsert;
var adTimerSecsMax   = 120;
var adTimerClicksMax = 10;
var adTimerSeen = {};
var adTimerUrl  = '';
resetAdTimer();

var agt = navigator.userAgent.toLowerCase();
var is_firefox = (agt.indexOf("firefox") != -1);

/********************/
/* thread functions */
/********************/
function updateComment(cid, mode) {
	var existingdiv = fetchEl('comment_' + cid);
	var placeholder = 0;
	if (existingdiv && mode != displaymode[cid]) {
		var doshort = 0;
		if (viewmodevalue[mode] >= viewmodevalue[displaymode[cid]]) {
			var cl = fetchEl('comment_link_' + cid);
			if (!cl) {
				fetch_comments.push(cid);
				doshort = 1;
				if (comments[cid]['points'] == -2) // -2 is special case for placeholder-hiddens
					placeholder = 1;
			} else if (viewmodevalue[mode] >= viewmodevalue['full']) {
				var cd = fetchEl('comment_otherdetails_' + cid);
				if (!cd.innerHTML) {
					var cs = fetchEl('comment_sub_' + cid);
					if (cs)
						cs.innerHTML = '<span class="commentload">Loading...</span>';
					fetch_comments.push(cid);
					fetch_comments_pieces[cid] = 1;
					doshort = 1;
				}
			}
		}
//		if (doshort)
		setShortSubject(cid, mode, cl);
		var new_class = existingdiv.className.replace(/full|hidden|oneline/, mode);
		if (new_class != existingdiv.className) {
			existingdiv.className = new_class;
			var parentdiv = fetchEl('tree_' + cid);
			parentdiv.className = parentdiv.className.replace(' contain', '');
			if (mode == 'full')
				parentdiv.className = parentdiv.className + ' contain';
		}
		if (adTimerUrl) {
			var addiv = fetchEl('comment_ad_' + cid);
			if (addiv) {
				if (mode == 'hidden')
					addiv.style.display = 'none';
				else
					addiv.style.display = 'block';
			}
		}
	}

	if (placeholder)
		placeholder_comments.push(cid);
	else
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
			if (prehiddendisplaymode[cid] == 'oneline' || prehiddendisplaymode[cid] == 'full') {
				futuredisplaymode[cid] = 'full';
			} else {
				futuredisplaymode[cid] = 'hidden';
			}
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
		if (displaymode[cid] != futuredisplaymode[cid]) {
			update_comments[cid] = futuredisplaymode[cid];
		}
//	}

	var kidhiddens = 0;
	if (comment && comment['kids'] && comment['kids'].length) {
// 		if (!subexpand) {
// 			if (shift_down && !alt_down && futuredisplaymode[cid] == 'full') {
// 				subexpand = 1;
// 			} else if (shift_down && !alt_down && futuredisplaymode[cid] == 'oneline') {
// 				subexpand = 2;
// 				threshold = user_threshold;
// 			}
// 		}

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

	if (abscid == cid) { // expanding == selecting
		setCurrentComment(cid);
		checkAdTimer(cid);
	}


// this doesn't work
//	var statusdiv = $dom('comment_status_' + abscid);
//	statusdiv.innerHTML = 'Working ...';

//	doModifiers();
//	if (!user_is_admin) // XXX: for now, admins-only, for testing
//		mods = 1;

// 	if (!alone && mods) {
// 		if (mods == 1 || ((mods == 3) && (abscid == cid)) || ((mods == 4) && (abscid != cid))) {
// 			shift_down = 0;
// 			alt_down   = 0;
// 		} else if (mods == 2 || ((mods == 3) && (abscid != cid)) || ((mods == 4) && (abscid == cid))) {
// 			shift_down = 1;
// 			alt_down   = 0;
// 		} else if (mods == 5) {
// 			shift_down = 1;
// 			alt_down   = 1;
// 		}
// 	}
// 
// 	if (shift_down && alt_down)
// 		alone = 1;
// 
// 	resetModifiers();

	var was_hidden = 0;
	if (displaymode[abscid] == 'hidden' || prehiddendisplaymode[abscid] == 'hidden')
		was_hidden = 1;

	if (alone && alone == 1) {
		var thismode = abscid == cid ? 'full' : 'oneline';
		updateDisplayMode(abscid, thismode, 1);
	} else {
		refreshDisplayModes(cid);
	}
	updateCommentTree(abscid);
	finishCommentUpdates();

//	statusdiv.innerHTML = '';

	if (!commentIsInWindow(abscid, (cid != abscid)))
		scrollWindowTo(abscid);

	if (was_hidden)
		updateHiddens([abscid]);

	return false;
}

function changeTHT(t_delta, ht_delta) {
	if (!t_delta && !ht_delta)
		return void(0);

	user_threshold       += t_delta;
	user_highlightthresh += ht_delta;
	// limit to between -1 and 6
	user_threshold       = Math.min(Math.max(user_threshold,       -1), 6);
	user_highlightthresh = Math.min(Math.max(user_highlightthresh, -1), 6);

	// T cannot be higher than HT; this also modifies delta
	if (user_threshold > user_highlightthresh)
		user_threshold = user_highlightthresh;

	changeThreshold(user_threshold + ''); // needs to be a string value
}

function changeHT(delta) {
	if (!delta)
		return void(0);

	user_highlightthresh += delta;
	// limit to between -1 and 6
	user_highlightthresh = Math.min(Math.max(user_highlightthresh, -1), 6);

	// T cannot be higher than HT; this also modifies delta
	if (user_threshold > user_highlightthresh)
		user_threshold = user_highlightthresh;

	changeThreshold(user_threshold + ''); // needs to be a string value
}

function changeT(delta, skip_ht) {
	if (!delta)
		return void(0);

	var threshold = user_threshold + delta;
	// limit to between -1 and 6
	threshold = Math.min(Math.max(threshold, -1), 6);

	// HT moves with T, but that is taken care of by changeThreshold()
	changeThreshold(threshold + '', skip_ht); // needs to be a string value
}

function changeThreshold(threshold, skip_ht) {
	var threshold_num = parseInt(threshold);
	var t_delta = threshold_num + (user_highlightthresh - user_threshold);
	user_threshold = threshold_num;
	if (skip_ht) { // don't move highlightthresh with thresh
		if (user_threshold > user_highlightthresh)
			user_highlightthresh = user_threshold;
	} else {
		user_highlightthresh = Math.min(Math.max(t_delta, -1), 6);
	}

	for (var root = 0; root < root_comments.length; root++) {
		updateCommentTree(root_comments[root], threshold);
	}
	finishCommentUpdates(1);

	savePrefs();

	return void(0);
}


/*******************************/
/* thread kid/hidden functions */
/*******************************/
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
		if (comments[cid]['points'] == -2) // -2 is special case for placeholder-hiddens
			return kidhiddens;
		else
			return kidhiddens + 1;
	} else if (kidhiddens) {
		var kidstring = '<a href="#" onclick="revealKids(' + cid + '); return false">' + kidhiddens;
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
			if (comments[kid]['points'] == -2) { // -2 is special case for placeholder-hiddens
				revealKids(kid);
				continue;
			}
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
	// something wrong here, not always working -- pudge 2007-01-16
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
		setFocusComment(cid, (collapse ? 2 : 1));
		return false;
	} else {
		return true; // follow link
	}
	return false;
}

function vertBarClick (pid) {
	comments_started = 1;
	setCurrentComment(pid);
	return selectParent(pid, 2);
}

function setShortSubject(cid, mode, cl) {
	if (!cl)
		cl = fetchEl('comment_link_' + cid);

	// subject is there only if it is a "reply"
	// check pid to make sure parent is there at all ... check visibility too?
	if (cl && cl.innerHTML && comments[cid]['subject'] && comments[cid]['pid']) {
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

// XXX this CANNOT be called without then adjusting the fetchEl stuff for
// Firefox (see ajaxFetchComments) ... we may make that into a separate
// call later, as it has to be properly called AFTER addComment calls are
// all done -- pudge
function addComment(cid, comment, html, front) {
	if (!loaded || !cid || !comment)
		return false;


	if (comments[cid]) {
		var tmpkids = comments[cid]['kids'];
		for (var i = 0; i < comment['kids'].length; i++) {
			tmpkids.push(comment['kids'][i]);
		}
		comments[cid] = comment;
		comments[cid]['kids'] = tmpkids;
	} else {
		comments[cid] = comment;
	}
	var pid = comment['pid'];

	if ($dom('tree_' + cid)) {
		if (pid) {
			var parent = comments[pid];
			var seen = 0;
			for (var i = 0; i < parent['kids'].length; i++) {
				if (parent['kids'][i] == cid)
					seen = 1;
			}
			if (!seen)
				parent['kids'].push(cid);
		} else {
			var seen = 0;
			for (var i = 0; i < root_comments.length; i++) {
				if (root_comments[i] == cid)
					seen = 1;
			}
			if (!seen) {
				root_comments.push(cid);
				root_comments_hash[cid] = 1;
			}
		}

		return true;
	}

	html = html || dummyComment(cid);

	if (pid) {
		var tree = $dom('tree_' + pid);
		if (tree) {
			setDefaultDisplayMode(pid);
			var parent = comments[pid];
			if (front)
				parent['kids'].unshift(cid);
			else
				parent['kids'].push(cid);

			var commtree = $dom('commtree_' + pid);
			if (commtree) {
				if (front)
					commtree.innerHTML = html + commtree.innerHTML;
				else
					commtree.innerHTML = commtree.innerHTML + html;
			} else {
				tree.innerHTML = tree.innerHTML + '<ul id="commtree_' + pid + '">' + html + '</ul>';
			}
		}

	} else {
		var commlist = $dom('commentlisting');
		if (commlist) {
			root_comments.push(cid);
			root_comments_hash[cid] = 1;

			commlist.innerHTML = commlist.innerHTML.replace(/(<li id="roothiddens" class="hide".*?>)/i, html + "$1");
		}
	}

	return true;
}


/****************************/
/* thread utility functions */
/****************************/
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
		setDefaultDisplayMode(cid);
		return prehiddendisplaymode[cid];
	}

	if ((viewmodevalue[newview] > viewmodevalue[prevview]) || canbelower) {
		return newview;
	}

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

	var defmode = comment.className.match(/full|hidden|oneline/);
	if (!defmode) { return }

	futuredisplaymode[cid] = prehiddendisplaymode[cid] = displaymode[cid] = defmode;
}

function updateDisplayMode(cid, mode, newdefault) {
	if (!mode) { return }

	setDefaultDisplayMode(cid);
	futuredisplaymode[cid] = mode;
	if (newdefault)
		prehiddendisplaymode[cid] = mode;
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
	if (!thresh)
		thresh  = user_threshold;
	if (!hthresh)
		hthresh = user_highlightthresh;

	if (thresh >= 6 || (comments[cid]['points'] < thresh && (user_is_anon || user_uid != comments[cid]['uid'])))
		return 'hidden';
	else if (comments[cid]['points'] < (hthresh - (root_comments_hash[cid] ? 1 : 0)))
		return 'oneline';
	else
		return 'full';
}

function finishCommentUpdates(thresh) {
	for (var cid in update_comments) {
		setDefaultDisplayMode(cid);
		updateComment(cid, update_comments[cid]);
	}

	ajaxFetchComments(fetch_comments, 0, thresh);

	updateTotals();
	update_comments = {};
	fetch_comments = [];
	fetch_comments_pieces = {};
	placeholder_comments = [];
	placeholder_no_update = {};
}

// not currently used
function refreshCommentDisplays() {
	var roothiddens = 0;
	for (var root = 0; root < root_comments.length; root++) {
		roothiddens += updateCommentTree(root_comments[root]);
	}
	finishCommentUpdates();

	if (roothiddens) {
		$dom('roothiddens').innerHTML = roothiddens + ' comments are beneath your threshhold';
		$dom('roothiddens').className = 'show';
	} else {
		$dom('roothiddens').className = 'hide';
	}
	/* NOTE need to display note for hidden root comments */
	return void(0);
}

/*******************/
/* misc. functions */
/*******************/
function numsort (a, b) { return (a - b) }

function map_hash( hash, f ) {
	var result = [];
	jQuery.each(hash, function(k, v) {
		result.push(f([k, v]));
	});
	return result;
}

function toHash(thisobject) {
	return map_hash(thisobject, function (pair) {
		return jQuery.map(pair, encodeURIComponent).join(',');
	}).join(';');
}

function ajaxFetchComments(cids, option, thresh, highlight) {
	if (cids && !cids.length)
		return;

	if (!cids && ajaxCommentsWait())
		return;

	if (option)
		thresh = 1;

	var params = {};
	params['op']              = 'comments_fetch';

	var newoldstuff = cids ? 0 : 1;

	if (cids) {
		params['cids']    = cids;
	} else {
		cids              = [];
		if (option && d2_seen)
			params['d2_seen']  = d2_seen;
		else
			params['cids']    = noshow_comments;
	}
	if (thresh) {
		params['threshold']       = user_threshold;
		params['highlightthresh'] = user_highlightthresh;
	}

	params['cid']             = root_comment;
	params['discussion_id']   = discussion_id;
//	params['reskey']          = reskey_static;

	var abbrev = {};
	for (var i = 0; i < cids.length; i++) {
		if (abbrev_comments[cids[i]] >= 0)
			abbrev[cids[i]] = abbrev_comments[cids[i]];
	}
	params['abbreviated'] = toHash(abbrev);

	params['pieces'] = toHash(cids ? fetch_comments_pieces : pieces_comments);

	if (placeholder_comments.length) {
		params['placeholders'] = placeholder_comments;
		params['d2_seen_ex']   = d2_seen;
	}

	var handlers = {
		onComplete: function (transport) {
			var response = eval_response(transport);

			if (!response) {
				ajaxCommentsStatus(0);
				return;
			}

			var update = response.update_data;
			var do_update = (update && update.new_cids_order) ? 1 : 0;
			if (do_update) {
				var root;
				var pids = {};
				for (var i = 0; i < update.new_cids_order.length; i++) {
					var this_cid = update.new_cids_order[i];
					cids.push(this_cid);
					addComment(this_cid, update.new_cids_data[i]);
					if (!comments[this_cid]['pid']) {
						root = 1;
					} else {
						pids[comments[this_cid]['pid']] = 1;
					}
				}

				// for some reason the modification done in addComment
				// invalidates the linkage fetchEl() uses to get
				// an element, so we need to refetch them
				// for now, trying on-demand
				if (is_firefox) {
 					if (root) {
 						reloadForFirefox('commentlisting');
 					} else {
						for (var pid in pids) {
 							reloadForFirefox('tree_' + pid);
 						}
 					}
				}
			}

			json_update(response);

			for (var i = 0; i < cids.length; i++) {
				reloadCommentForFirefox(cids[i]);
				setShortSubject(cids[i]);
			}

			if (do_update) {
				if (newoldstuff) {
					for (var i = 0; i < last_updated_comments.length; i++) {
						var this_cid = last_updated_comments[i];
						var this_id  = fetchEl('comment_top_' + this_cid);
						if (this_id)
							this_id.className = this_id.className.replace(' newcomment', ' oldcomment');
					}
				}
				last_updated_comments_index = last_updated_comments.length - 1;

				for (var i = 0; i < update.new_cids_order.length; i++) {
					var this_cid = update.new_cids_order[i];
					if (!placeholder_no_update[this_cid]) {
						var mode = determineMode(this_cid);
						updateDisplayMode(this_cid, mode, 1);
						currents[displaymode[this_cid]]++;
						updateComment(this_cid, mode);
					}

					var this_id  = fetchEl('comment_top_' + this_cid);
					if (this_id) {
						this_id.className = this_id.className.replace(' oldcomment', ' newcomment');
						last_updated_comments.push(this_cid);
					}
				}

				// later we may need to find a known point and scroll
				// to it, but for now we don't want to do this -- pudge
				//if (!commentIsInWindow(update.new_cids_order[0])) {
				//	scrollWindowTo(update.new_cids_order[0]);
				//}
			}

			if (update && update.new_thresh_totals) {
				for (var thresh in update.new_thresh_totals) {
					for (var hthresh in update.new_thresh_totals[thresh]) {
						for (var mode in update.new_thresh_totals[thresh][hthresh]) {
							thresh_totals[thresh][hthresh][mode] += update.new_thresh_totals[thresh][hthresh][mode];
						}
					}
				}
				$dom('titlecountnum').innerHTML = thresh_totals[6][6][1]; // total
				updateTotals();
			}

			updateHiddens(cids);
			if (do_update && highlight && last_updated_comments.length) {
				var next_cid = commTreeNextComm(0, 0, 1);
				if (next_cid) {
					if (highlight > 1)
						setFocusComment('-' + current_cid, 1);
					setCurrentComment(next_cid);
					setFocusComment(next_cid, 1);
				}
			}
			ajaxCommentsStatus(0);

			if (adTimerInsert) {
				var tree = $dom('tree_' + adTimerInsert);
				if (tree) {
					var adcall = '<iframe src="' + adTimerUrl + '" height="110" width="740" frameborder="0" border="0" scrolling="no" marginwidth="0" marginheight="0"></iframe>';
					var html = '<li id="comment_ad_' + adTimerInsert + '" class="inlinead"> ' + adcall +'  </li>';

					var commtree = $dom('commtree_' + adTimerInsert);
					if (commtree) {
						commtree.innerHTML = html + commtree.innerHTML;
					} else {
						tree.innerHTML = tree.innerHTML + '<ul id="commtree_' + adTimerInsert + '">' + html + '</ul>';
					}
					resetAdTimer();
				}
			}
		}
	};

	ajaxCommentsStatus(1);
	ajax_update(params, '', handlers);

	if (cids) {
		for (var cid in fetch_comments_pieces) {
			pieces_comments[cid] = 0;
		}

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
		pieces_comments = [];
	}
}

function savePrefs() {
	if (!user_is_anon
		&&
	    ((user_threshold_orig != user_threshold)
		||
	    (user_highlightthresh_orig != user_highlightthresh))
	) {
		var params = {};
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

	var params = {};
	params['op']  = 'comments_read_rest';
	params['cid'] = cid;
	params['sid'] = discussion_id;
//	params['reskey'] = reskey_static;

	var handlers = {
		onComplete: function() {
			shrunkdiv.innerHTML = '';
			var sigdiv = fetchEl('comment_sig_' + cid);
			if (sigdiv) {
				sigdiv.className = 'sig'; // show
			}
		}
	};

	shrunkdiv.innerHTML = '<span class="loading">Loading...</span>';
	ajax_update(params, 'comment_body_' + cid, handlers);

	return false;
}

function doModerate(el) {
	if (user_is_anon)
		return false;

	var matches = el.name.match(/_(\d+)$/);
	var cid = matches[1];

	if (!cid)
		return true;

	el.disabled = 'true';
	var params = {};
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

function cancelReply(pid) {
	var replydiv = $dom('replyto_' + pid);
	replydiv.innerHTML = '';
	if (pid) { // XXX
		var reply_link = $dom('reply_link_' + pid);
		reply_link.innerHTML = reply_link_html[pid];
		reply_link_html[pid] = '';
	}
}

function editReply(pid) {
	var replydiv = $dom('replyto_' + pid);
	var reply = $dom('replyto_reply_' + pid);
	var preview = $dom('replyto_preview_' + pid);
	if (!replydiv || !reply || !preview)
		return false;

	setReplyMsg(pid, '');
	preview.style.display = 'none';
	reply.style.display   = 'block';

	$dom('replyto_buttons_2_' + pid).style.display  = 'none';
	$dom('replyto_buttons_1_' + pid).style.display = 'inline';
}

function setReplyMsg(pid, msg) {
	if (!pid)
		return;
	var msgdiv = $('#replyto_msg_' + pid);
	if (!msgdiv)
		return;

	msgdiv.html(msg);
	if (msg)
		msgdiv.show();
	else
		msgdiv.hide();
}

function replyPreviewOrSubmit (pid, op, handlers) {
	var replydiv = $dom('replyto_' + pid);
	var reply = $dom('replyto_reply_' + pid);
	var preview = $dom('replyto_preview_' + pid);
	var this_reskey = $dom('reskey_reply_' + pid);
	var msgdiv = 'replyto_msg_' + pid;

	if (!replydiv || !reply || !preview || !this_reskey)
		return false;

	var params = {};
	params['op']  = op;
	params['pid'] = pid;
	params['sid'] = discussion_id;
	params['reskey'] = this_reskey.value;
	params['msgdiv'] = msgdiv;
	params['gotmodwarning'] = $dom('gotmodwarning_' + pid).value;
	params['postersubj'] = $dom('postersubj_' + pid).value;
	params['postercomment'] = $dom('postercomment_' + pid).value;

	var hcanswer = $dom('hcanswer_' + pid);
	if (hcanswer)
		params['hcanswer'] = hcanswer.value;

	var postanon = $dom('postanon_' + pid);
	if (postanon && postanon.checked)
		params['postanon'] = postanon.value;

	setReplyMsg(pid, '<span class="loading">Loading...</span>');
	ajax_update(params, '', handlers);
}

function submitReply(pid) {
	return replyPreviewOrSubmit(pid, 'comments_submit_reply', {
		onComplete: function(transport) {
			setReplyMsg(pid, '');
			var response = json_handler(transport);
			var cid = response.cid;
			if (response.error)
				setReplyMsg(pid, response.error);
			else if (cid) {
				cancelReply(pid);
				addComment(cid, { pid: pid, kids: [] }, '', 1);
				setFocusComment(cid, 1);
			}
		}
	});

}

function previewReply(pid) {
	return replyPreviewOrSubmit(pid, 'comments_preview_reply', {
		onComplete: function(transport) {
			setReplyMsg(pid, '');
			var response = json_handler(transport);
			if (response.error)
				setReplyMsg(pid, response.error);
			if (response.html) {
				$('#replyto_reply_' + pid).hide();
				$('#replyto_preview_' + pid).show();
				$('#replyto_buttons_1_' + pid).hide();
				$('#replyto_buttons_2_' + pid).show();
			}
		}
	});
}

function replyTo(pid) {
	var replydiv = $dom('replyto_' + pid);
	if (!replydiv)
		return false; // seems we shouldn't be here ...

	var postercomment = $dom('postercomment_' + pid);
	if (postercomment) {
		postercomment.focus(); // already have one, bail
		return false;
	}

	var params = {};
	params['op']  = 'comments_reply_form';
	params['pid'] = pid;
	params['sid'] = discussion_id;

	replydiv.innerHTML = '<span class="loading">Loading...</span>';

	var handlers = {
		onComplete: function(transport) {
			json_handler(transport);
			if (pid) { // XXX
				var reply_link = $dom('reply_link_' + pid);
				reply_link_html[pid] = reply_link.innerHTML;
				reply_link.innerHTML = '<p><b><a href="#" onclick="cancelReply(' + pid + '); return false;">Cancel Reply</a></b></p>';
			}
			$dom('postercomment_' + pid).focus();
		}
	};

	ajax_update(params, '', handlers);

	return false;
}

function quoteReply(pid) {
	var this_reply = getQuotedText(comment_body_reply[pid]);
	var postercomment = $dom('postercomment_' + pid) || $dom('postercomment');
	if (postercomment)
		postercomment.value = this_reply + postercomment.value;
	return false;
}

function getQuotedText(this_reply) {
	// tailor whitespace to postmode
	if (!$dom('posttype') || $dom('posttype').value != 2) {
		this_reply = this_reply.replace(/<br>/g, "\n");
	} else {
		this_reply = this_reply.replace(/<br>\n*/g, "<br>\n");
		this_reply = this_reply.replace(/\n*<p>/g, "\n\n<p>");
		this_reply = this_reply.replace(/<\/p>\n*/g, "</p>\n\n");
		this_reply = this_reply.replace(/<\/p>\n\n\n*<p>/g, "</p>\n\n<p>");
	}
	// <quote> parse code takes care of whitespace
	this_reply = this_reply.replace(/\n*<quote>/g, "\n\n<quote>");
	this_reply = this_reply.replace(/^\n+/g, "");
	this_reply = this_reply.replace(/<\/quote>\n*/g, "</quote>\n\n");

	return this_reply;
}


/*********************/
/* utility functions */
/*********************/
function loadAllElements(tagname, parent) {
	if (!parent)
		parent = document;
	var elements = parent.getElementsByTagName(tagname);

	for (var i = 0; i < elements.length; i++) {
		var e = elements[i];
		commentelements[e.id] = e;
	}

	return;
}

function reloadForFirefox(obj_name) {
	if (is_firefox) {
		var obj = $dom(obj_name);
		loadAllElements('span', obj);
		loadAllElements('div', obj);
		loadAllElements('li', obj);
		loadAllElements('a', obj);
	}
}

function reloadCommentForFirefox(cid) {
	if (is_firefox) {
		loadNamedElement('comment_link_' + cid);
		loadNamedElement('comment_shrunk_' + cid);
		loadNamedElement('comment_sig_' + cid);
		loadNamedElement('comment_otherdetails_' + cid);
		loadNamedElement('comment_sub_' + cid);
		loadNamedElement('comment_top_' + cid);
	}
}

function loadNamedElement(name) {
	commentelements[name] = $dom(name);
	return;
}

function fetchEl(str) {
	var obj;

	if (loaded && is_firefox) {
		obj = commentelements[str];
		// any other special cases to ignore? -- pudge
		if (!str.match(/^hidestring_/))
			if (!obj || !grepCommentNode(obj, str))
				obj = commentelements[str] = $dom(str);
	} else {
		obj = $dom(str);
	}

	return obj;
}

// this is a generalized fix for Firefox, to find orphaned nodes
// maybe more than we need? keep this around in case we need,
// but maybe don't use it for now -- pudge
function grepNode(obj, id) {
	if (!id)
		id = '^commentlisting$';
	var parent = obj.parentNode;
	if (!parent)
		return false;
//	if (parent.nodeName == '#document')
	if (parent.id.match(id))
		return parent;
	return grepNode(parent);
}

function grepCommentNode(obj, str) {
	var results = str.match(/^(tree|comment)_(\w+_)?\d+$/);
	if (results)
		return grepNode(obj)
	return true;
}


function finishLoading() {
	if (is_firefox) {
		loadAllElements('span');
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

	var noshow_comments_hash = {};
	for (var i = 0; i < noshow_comments.length; i++) { noshow_comments_hash[noshow_comments[i]] = 1 }
	for (var cid in comments) {
		if (!noshow_comments_hash[cid])
			last_updated_comments.push(cid);
	}
	last_updated_comments = last_updated_comments.sort(numsort);
	//root_comments = root_comments.sort(numsort);

	if (1 || user_is_admin) {
		if (window.addEventListener) // DOM method for binding an event
			window.addEventListener('keydown', keyHandler, false);
		else if (window.attachEvent) // IE exclusive method for binding an event
			window.attachEvent('onkeydown', keyHandler)
		else if (document.getElementById) // support older modern browsers
			document.body.onkeydown = keyHandler;
	}

	setCurrentComment(last_updated_comments[last_updated_comments_index]);

	if (more_comments_num)
		updateMoreNum(more_comments_num);
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


/****************/
/* UI functions */
/****************/
function resetModifiers () {
	shift_down = 0;
	alt_down   = 0;
	ctrl_down  = 0;
	meta_down  = 0;
}

function doModifiers (e) {
	e = e || window.event;
	resetModifiers();

	if (e) {
		if (e.modifiers) {
			if (e.modifiers & Event.SHIFT_MASK)
				shift_down = 1;
			if (e.modifiers & Event.ALT_MASK)
				alt_down = 1;
			if (e.modifiers & Event.CTRL_MASK)
				ctrl_down = 1;
			if (e.modifiers & Event.META_MASK)
				meta_down = 1;
		} else {
			if (e.shiftKey)
				shift_down = 1;
			if (e.altKey)
				alt_down = 1;
			if (e.ctrlKey)
				ctrl_down = 1;
			if (e.metaKey)
				meta_down = 1;
		}
	}
}

function ajaxCommentsWait() {
	return ajaxCommentsWaitQueue.length ? 1 : 0;
}

function ajaxCommentsStatus(bool) {
	boxStatus(bool);

	if (bool)
		ajaxCommentsWaitQueue.push(1);
	else
		ajaxCommentsWaitQueue.shift();

	return true;
}

function boxStatus(bool) {
	var box = $dom('commentControlBoxStatus');
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
	var morelink = $dom('more_comments_num_a');
	if (morelink)
		morelink.className = 'show';

	d2act();
	loaded = 1;
}

function floatButtons () {
	$dom('gods').className='thor';
}

function d2act () {
	var gd = $dom('d2act');
	if (gd) {
		var targetTop = YAHOO.util.Dom.getY('commentwrap');
		var vOffset = 0;
		if ( typeof window.pageYOffset == 'number' )
			vOffset = window.pageYOffset;
		else if ( document.body && document.body.scrollTop )
			vOffset = document.body.scrollTop;
		else if ( document.documentElement && document.documentElement.scrollTop )
			vOffset = document.documentElement.scrollTop;
  
		var oldpos = gd.style.position;

		var mode = $dom('d2out').className;
		if (mode=='horizontal rooted' || targetTop>vOffset) {
			gd.style.position = 'absolute';
			gd.className      = 'rooted';
			gd.style.top      = '0px';
		} else {
			gd.style.position = 'fixed';
			gd.className      = '';
			gd.style.top      = '0px';
		}

		// for Safari and maybe others, force redraw on change
		if ( oldpos != gd.style.position ) {
			gd.style.display = 'none';
			setTimeout("$dom('d2act').style.display = 'inline'", 1);
			// gd.style.display = 'inline';
		}
	}
}

function toggleDisplayOptions() {
	var gods  = $dom('gods');
	var d2out = $dom('d2out');

	// update user prefs
	var newMode = '';

	var isHidden = gods.style.display == 'none';
	gods.style.display = 'none';

	// none -> ( vertical -> horizontal -> rooted )
	if ( d2out.className == 'vertical' ) { // vertical->horizontal
		newMode = d2out.className = 'horizontal';
		gCommentControlWidget.setOrientation('X');
	} else if ( d2out.className == 'horizontal' ) { // horizontal->rooted
		newMode = 'rooted';
		d2out.className = 'horizontal rooted';
	} else {
		if (!low_bandwidth) { // (rooted, none)->vertical
			newMode = d2out.className = 'vertical';
			gCommentControlWidget.setOrientation('Y');
		} else { // vertical not happy in low-bandwidth
			newMode = d2out.className = 'horizontal';
			gCommentControlWidget.setOrientation('X');
		}
	}

	d2act();
	gods.style.display = 'block';

	if (!user_is_anon) {
		var params = {};
		params['comments_control'] = newMode;
		params['op'] = 'comments_set_prefs';
		params['reskey'] = reskey_static;
		ajax_update(params);
	}

	return false;
}


function updateTotals() {
	$dom('currentHidden' ).innerHTML = currents['hidden'];
	$dom('currentFull'   ).innerHTML = currents['full'];
	$dom('currentOneline').innerHTML = currents['oneline'];
}

function updateMoreNum(num) { // should be an integer, or empty string
	if (num == 0)
		num = '';

	var num_a;
	if (!num)
		num_a = 'Check for more';
	else {
		if (num == 1)
			num_a = 'Retrieve the 1 remaining comment';
		else
			num_a = 'Retrieve more of the ' + num + ' remaining comments';
	}

	var a = $dom('more_comments_num_a');
	var b = $dom('more_comments_num_b');
	var c = $dom('more_comments_num_c');

	if (a)
		a.innerHTML = num_a;
	if (b)
		b.innerHTML = num;
	if (c)
		c.innerHTML = num;
}


function scrollWindowTo(cid) {
	var comment_y = getOffsetTop(fetchEl('comment_' + cid));
	if ($dom('d2out').className == 'horizontal')
		comment_y -= 60;
	scroll(viewWindowLeft(), comment_y);
}

function getOffsetLeft (el) {
	if (!el)
		return false;
	var ol = el.offsetLeft;
	while ((el = el.offsetParent) != null)
		ol += el.offsetLeft;
	return ol;
}

function viewWindowRight() {
	return viewWindowLeft() + (window.innerWidth || document.documentElement.clientWidth);
}

function commentIsInWindow(cid, just_head) {
	var in_window = isInWindow(fetchEl('comment_' + cid));
	if (in_window && !just_head && fetchEl('comment_sub_' + cid))
		in_window = isInWindow(fetchEl('comment_sub_' + cid));
	return in_window;
}


/* code for the draggable threshold widget */

function showPrefs( category ) {
	var panel = $dom("d2prefs");
	panel.className = category;
	panel.style.display = "block";
}

function hidePrefs() {
	var panel = $dom("d2prefs");
	panel.className = "";
	panel.style.display = "none";
}

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

function boundsToDimensions( bounds, scaleFactor ) {
	if ( scaleFactor === undefined )
		scaleFactor = 1;

	var sizes = new Array(bounds.length-1);
	for ( var i=0; i<sizes.length; ++i )
		sizes[i] = { size: Math.abs(bounds[i+1]-bounds[i]) * scaleFactor };

	var left = 0;
	var right = 0;

	for ( var L=0, R=sizes.length-1; R>=0; ++L, --R ) {
		sizes[L].start = left; left += sizes[L].size;
		sizes[R].stop = right; right += sizes[R].size;
	}

	return sizes;
}

Y_UNITS_IN_PIXELS = 20;

ABBR_BAR = 0;
HIDE_BAR = 1;


YAHOO.namespace("slashdot");

YAHOO.slashdot.ThresholdWidget = function( initialOrientation ) {
	this.PANEL_KINDS = [ "full", "abbr", "hide" ];
	this.displayRange = [6, -1];
	this.constraintRange = [6, -1];
	this.getEl_cache = new Object();

	this.orientations = new Object();
	this.orientations["Y"] = { axis:"Y", startPos:"top", endPos:"bottom", getPos:YAHOO.util.Dom.getY, units:"px", scale:Y_UNITS_IN_PIXELS };
	this.orientations["X"] = { axis:"X", startPos:"left", endPos:"right", getPos:YAHOO.util.Dom.getX, units:"%", scale:(100.0 / (this.displayRange[0]-this.displayRange[1])) };
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

YAHOO.slashdot.ThresholdWidget.prototype.stepTHT = function( threshold, step ) {
	var ts = this.displayedTs.slice();
	ts[threshold] += step;
	this._setTs(pinToRange(this.constraintRange, ts));
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
		var o = this.orient = this.orientations[newAxis];
		for ( var i=0; i<this.PANEL_KINDS.length; ++i ) {
			var prefix = "ccw-"+this.PANEL_KINDS[i];
			var panel = this._getEl(prefix+"-panel").style;
			if ( i != 0 ) panel[ o.other.startPos ] = 0;
			if ( i != this.PANEL_KINDS.length-1 ) panel[ o.other.endPos ] = 0;

			this._getEl(prefix+"-phrase").style.display = "inline";
			this._getEl(prefix+"-count-pos").style.top = 0;
		}
		this._setTs();
	}
}

YAHOO.slashdot.ThresholdWidget.prototype._scaleToPixels = function() {
	return this._getEl("ccw-control").scrollWidth / 100.0;
}

YAHOO.slashdot.ThresholdWidget.prototype._setTs = function( newTs, draggingBar ) {
	var w = this;
	var o = w.orient;

	function fixPanel( id, newDims ) {
		var prefix = "ccw-"+id;
		var countText = w._getEl(prefix+"-count-text").style;
		if ( newDims.size == 0 )
			countText.display = "none";
		else {
			countText.display = "block";
			if ( o.axis == "Y" )
				w._getEl(prefix+"-count-pos").style.top = (newDims.size/2) + o.units;
			else
				w._getEl(prefix+"-phrase").style.display = (newDims.size>o.scale) ? "inline" : "none";
		}

		var panel = w._getEl(prefix+"-panel").style;
		if ( newDims.start !== undefined ) panel[ o.startPos ] = newDims.start + o.units;
		if ( newDims.stop !== undefined ) panel[ o.endPos ] = newDims.stop + o.units;
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

	var dims = boundsToDimensions(partitionedRange(this.displayRange, newTs), o.scale);
	delete dims[0].start;
	delete dims[ dims.length-1 ].stop;

	for ( var i=0; i<this.PANEL_KINDS.length; ++i )
		fixPanel(this.PANEL_KINDS[i], dims[i]);

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
	if ( o.units != "px" )
		scale *= w._scaleToPixels();
	return w.displayRange[0] - Math.round((pos - widgetStart) / scale);
}

YAHOO.slashdot.ThresholdBar.prototype.setPosFromT = function( x ) {
	if ( this.posToT() != x ) {
		var w = this.parentWidget;
		var o = w.orient;
		var elStyle = this.getEl().style;
		elStyle[ o.startPos ] = ((w.displayRange[0]-x) * o.scale) + o.units;
		elStyle[ o.other.startPos ] = 0;
		elStyle.display = "block";
	}
}

YAHOO.slashdot.ThresholdBar.prototype.fixConstraints = function() {
	var w = this.parentWidget;
	var o = w.orient;

	var scale = o.scale;
	if ( o.units != "px" )
		scale *= w._scaleToPixels();

	this.resetConstraints();
	this[ "set" + o.other.axis + "Constraint" ](0, 0);

	var thisT = this.draggingTs[this.whichBar];
	var availableSpace = boundsToDimensions(partitionedRange(w.constraintRange, [thisT]), scale);
	this[ "set" + o.axis + "Constraint" ](availableSpace[0].size+1, availableSpace[1].size+1, scale);
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


function checkAdTimer (cid) {
	if (!adTimerUrl)
		return;

	clickAdTimer();

	if (cid && adTimerSeen[cid])
		return 0;

	var ad = 0;
	if (adTimerClicks >= adTimerClicksMax) {
		ad = 1;
	} else {
		var secs = getSeconds() - adTimerSecs;
		if (secs >= adTimerSecsMax)
			ad = 1;
	}

	if (!ad)
		return 0;

	adTimerInsert = cid;
}

function resetAdTimer () {
	if (adTimerInsert) {
		adTimerSeen[adTimerInsert] = 1;
	}
	adTimerInsert = 0;
	adTimerSecs   = getSeconds();
	adTimerClicks = 0;
}

function clickAdTimer () {
	adTimerClicks = adTimerClicks + 1;
}

function getSeconds () {
	return new Date().getTime()/1000;
}


function setCurrentComment (cid) {
	if (!cid)
		return false;

	var this_id;
	if (current_cid) {
		if (cid == current_cid)
			return;

		this_id = $('#comment_top_' + current_cid);
		this_id.removeClass('newcomment');
		this_id.addClass('oldcomment');

		this_id = $('#comment_' + current_cid);
		this_id.removeClass('currcomment');
		$('.current').remove();
	}


	this_id = $('#comment_' + cid);
	this_id.addClass('currcomment');
	this_id.before('<span class="current">&rsaquo;</span>');

	current_cid = cid;
}


/* keys
prev comment: A, H
next comment: D, L
prev thread: W, J
next thread: S, K
prev comm chrono: Q
next comm chrono: E
next unread comm: F
reply to current comment: R
parent of current comment: P
history (modlog) of current comment: M
skip to end (last): V
skip to top (first): T
get more comments: G
lower top threshold: [
raise top threshold: ]
lower bottom threshold: ,
raise bottom threshold: .
toggle d2 widget: / XXX
hide_modal_box(): esc XXX
*/

var validkeys = {
	A: { thread : 1, prev: 1, comment: 1 },
	D: { thread : 1, next: 1, comment: 1 },
	W: { thread : 1, prev: 1 },
	S: { thread : 1, next: 1 },
	Q: { chrono : 1, prev: 1, comment: 1 },
	E: { chrono : 1, next: 1, comment: 1 },
	F: { thread : 1, next: 1, comment: 1, unread: 1 },

	R: { current : 1, reply   : 1 },
	P: { current : 1, parent  : 1 },
	M: { current : 1, history : 1 },

	G: { nav: 1, more : 1 },
	T: { nav: 1, skip : 1, top    : 1 }, 
	V: { nav: 1, skip : 1, bottom : 1 }, 

	// these do not work, different codes coming through
	'[' : { thresh : 1, top    : 1, down: 1 },
	']' : { thresh : 1, top    : 1, up  : 1 },
	',' : { thresh : 1, bottom : 1, down: 1 },
	'.' : { thresh : 1, bottom : 1, up  : 1 },

};

validkeys['H'] = validkeys['A'];
validkeys['L'] = validkeys['D'];
validkeys['J'] = validkeys['S'];
validkeys['K'] = validkeys['W'];

//testing
//validkeys['1'] = validkeys['['];
//validkeys['2'] = validkeys[']'];
//validkeys['3'] = validkeys[','];
//validkeys['4'] = validkeys['.'];


function keyHandler(e, k) {
	if (!k)
		e = e || window.event;

	if (k || e) {
		// don't handle for forms ... "type" should handle all our cases here
		if (!k && e.target && e.target.type)
			return;

		var c;
		if (e)
			c = e.keyCode;
		if (k || c) {
			if (!k)
				doModifiers(e);
			var collapseCurrent = shift_down;
			var getNextUnread   = ctrl_down; // not working right, and interfering anyway -- pudge
			var skipit = 0;
			if (meta_down || alt_down || ctrl_down)
				skipit = 1;
			if (!k)
				resetModifiers();
			if (skipit)
				return;

			var update = 0;
			var next_cid = 0;
			var key = k || String.fromCharCode(c);
			var keyo = validkeys[key];
			if (keyo) {
				// keys that rely on current comment
				if (keyo['current'] && current_cid) {
					if (keyo['reply'] && !user_is_anon) // XXX will be anon too
						replyTo(current_cid);

					else if (keyo['history'])
						getModalPrefs('modcommentlog', 'Moderation Comment Log', current_cid);

					else if (keyo['parent']) {
						if (current_cid && comments[current_cid] && comments[current_cid]['pid'])
							selectParent(comments[current_cid]['pid']);
					}


				// misc. navigation keys
				} else if (keyo['nav']) {
					if (keyo['more'])
						ajaxFetchComments(0, 1);

					else if (keyo['skip']) { // XXX how to find top/bottom?
						if (keyo['top']) {
							next_cid = commTreeFirstComm();
							update = 1;
						} else if (keyo['bottom']) {
							next_cid = commTreeLastComm();
							update = 1;
						}
					}

				// threshold keys keys
				} else if (keyo['thresh']) {
					if (keyo['top'])
						changeHT(keyo['up'] ? 1 : -1);
					if (keyo['bottom'])
						changeT((keyo['up'] ? 1 : -1), 1);
					gCommentControlWidget.setTHT(user_threshold, user_highlightthresh);


				// forward and back between comments, in order of how they were loaded
				} else if (keyo['chrono']) {
					var i = last_updated_comments_index;
					var l = last_updated_comments.length - 1;
					update = 1;

					if (keyo['prev']) {
						if (i <= 0) {
							// this did go back to end; nothing, for now
							//i = l;
						} else
							i = i - 1;
					} else if (keyo['next']) {
						if (i >= l) {
							if (ajaxCommentsWait())
								return;
							update = 2;
							ajaxFetchComments(0, 1, '', 1);
						} else {
							if (!i && noSeeFirstComment(last_updated_comments[i]))
								comments_started = 1; // only come here once
							else
								i = i + 1;
						}
					}

					if (update == 1) {
						last_updated_comments_index = i;
						next_cid = last_updated_comments[i];
					}
				}

				// forward and back between threads, and comments within each thread
				else if (keyo['thread']) {
					update = 1;
					if (keyo['next']) {
						if (noSeeFirstComment(current_cid))
							next_cid = current_cid;
						else {
							if (keyo['unread'])
								getNextUnread = 1;
							if (keyo['comment']) {
								next_cid = commTreeNextComm(current_cid, 0, getNextUnread);
								if (!next_cid) { // && getNextUnread) {
									if (ajaxCommentsWait())
										return;
									update = 2;
									var highlight = 1 + collapseCurrent;
									ajaxFetchComments(0, 1, '', highlight);
								}
							} else
								next_cid = commTreeNextComm(comments[current_cid].pid, current_cid, getNextUnread);
						}
					}
	
					else if (keyo['prev'] && keyo['comment'])
						next_cid = commTreePrevComm(current_cid);
	
					else if (keyo['prev'])
						next_cid = commTreePrevComm(current_cid, 1);
				}
			}

			if (update && next_cid) {
				comments_started = 1;
				if (collapseCurrent && current_cid)
					setFocusComment('-' + current_cid, 1);
				if (update == 1)
					setFocusComment(next_cid, 1);
			}
		}
	}
}

// at first comment, and comment is not in window OR comment is not full
function noSeeFirstComment (cid) {
	setDefaultDisplayMode(cid);
	if (!comments_started && (!commentIsInWindow(cid) || (viewmodevalue[displaymode[cid]] < viewmodevalue['full']))) {
		return 1;
	}
	return 0;
}

// XXX somehow sync this with the prev/next by load order?  might require
// a quick grep to find the position
function commTreeNextComm (cid, old_cid, getNextUnread) {
	var kids;
	if (cid)
		kids = sortKids(cid);
	else
		kids = rootSort();

	var seen = 0;
	for (var i = 0; i < kids.length; i++) {
		var this_cid;
		if (!old_cid) {
			this_cid = kids[i];
		} else if ((kids[i] == old_cid) || seen) {
			this_cid = kids[i+1];
			seen = 1;
		}

		if (this_cid) {
			if (!getNextUnread || (this_cid = getNextUnreadCid(this_cid)))
				return this_cid;
			continue;
		}
	}

	if (!cid)
		return 0; // at the end, stay where we are

	// we can't continue here, go back up a level
	return commTreeNextComm(comments[cid].pid, cid, getNextUnread);
}

function commTreeLastComm () {
	var this_cid = current_cid;
	if (!current_cid)
		this_cid = last_updated_comments[0];
	for (;;) {
		var new_cid = commTreeNextComm(this_cid);
		if (!new_cid)
			return this_cid;
		this_cid = new_cid;
	}
}

function commTreeFirstComm () {
	var this_cid = current_cid;
	if (!current_cid)
		this_cid = last_updated_comments[0];
	for (;;) {
		var new_cid = commTreePrevComm(this_cid, 2);
		if (!new_cid)
			return this_cid;
		this_cid = new_cid;
	}
}

function commTreePrevComm (cid, to_parent) {
	var root_kids = rootSort();
	var comm = comments[cid];
	var pid = comm.pid;

	if (to_parent == 1) {
		if (pid)
			return pid;
		else // if in roots, then just climb up roots
			return commTreePrevComm(cid, 2);
	}

	var kids;
	if (pid)
		kids = sortKids(pid);
	else
		kids = root_kids;

	for (var i = 0; i < kids.length; i++) {
		if (cid == kids[i]) {
			if (i == 0) // go up
				return pid;
			else if (to_parent)
				return kids[i - 1];
			else 
				return getLastChild(kids[i - 1]);
		}
	}
}

function rootSort() { // maybe cache later
	return root_comments; //.sort(numsort);
}

function sortKids(cid) { // maybe cache later
	return comments[cid].kids; //.sort(numsort);
}

function isUnread(cid) {
	var this_id  = fetchEl('comment_top_' + cid);
	if (this_id)
		if (this_id.className.match(' newcomment'))
			return 1;
		else
			return 0;
}

// XXX should we climb all the way back up the tree if we find nothing?
function getNextUnreadCid(cid) {
	if (isUnread(cid))
		return cid;
	var kids = sortKids(cid);
	for (var i = 0; i < kids.length; i++) {
		var next_cid = getNextUnreadCid(kids[i]);
		if (next_cid)
			return next_cid;
	}
	return 0;
}

function getLastChild(cid) {
	var kids = sortKids(cid);
	if (kids.length)
		return getLastChild(kids[kids.length - 1]);
	else
		return cid;
}


function dummyComment(cid) {
	var html = '<li id="tree_--CID--" class="comment">\
<div id="comment_status_--CID--" class="commentstatus"></div>\
<div id="comment_--CID--" class="hidden">\
</div>\
\
<div id="replyto_--CID--"></div>\
\
<ul id="group_--CID--">\
	<li id="hiddens_--CID--" class="hide"></li>\
</ul>\
</li>';

	return(html.replace(/\-\-CID\-\-/g, cid));
}
