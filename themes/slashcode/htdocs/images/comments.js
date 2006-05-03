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
			existinglink.href = 'javascript:setFocusComment(' + plusminus + cid + ');';
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

	if (threshold) {
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
		var kidstring = '<a href="javascript:changeThreshold(-1,' + cid + ')">' + kidhiddens;
		if (kidhiddens == 1) {
			kidstring += ' comment is hidden.</a>';
		} else {
			kidstring += ' comments are hidden.</a>';
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

function setFocusComment(cid) {
	var abscid = Math.abs(cid);

// this doesn't work
//	var statusdiv = $('comment_status_' + abscid);
//	statusdiv.innerHTML = 'Working ...';

	refreshDisplayModes(cid);
	updateCommentTree(abscid);
	updateTotals();

//	statusdiv.innerHTML = '';

	var comment_y = getOffsetTop($('comment_' + abscid));
	var newcomment_y = getOffsetTop($('comment_' + abscid));
	if (comment_y != newcomment_y) {
		var diff = newcomment_y - comment_y;
		scroll(viewWindowLeft(), viewWindowTop() + diff);
	}
	return void(0);
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

function changeThreshold(threshold, cid) {
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

	if (!cid) {
		for (var root = 0; root < root_comments.length; root++) {
			updateCommentTree(root_comments[root], threshold);
		}
	} else {
		updateCommentTree(cid, threshold);
	}

	updateTotals();

	return void(0);
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
	return document.body.scrollLeft + screen.width; 
}

function viewWindowBottom() {
	return document.body.scrollTop + screen.height;
}


function replyTo(cid) {
	var replydiv = $('replyto_' + cid);
	replydiv.innerHTML = '<div class="generaltitle">\n	<div class="title">\n		<h3>\n			Post Comment\n			\n		</h3>\n	</div>\n</div>\n\n	<div class="generalbody">\n<!-- error message -->\n<!-- newdiscussion  form.newdiscussion  -->\n\n<!-- end error message -->\n<form action="//bourque.pudge.net:8080/comments.pl" method="post">\n    \n	<fieldset>\n	<legend>Edit Comment</legend>\n	<input type="hidden" name="sid" value="5">\n	<input type="hidden" name="pid" value="6">\n	\n<input type="hidden" name="formkey" value="uhsK8kRMWz">\n\n\n\n	\n	<p>\n<label >\n	Name\n</label>\n </p>\n		<a href="//bourque.pudge.net:8080/users.pl">pudge</a> [ <a href="//bourque.pudge.net:8080/login.pl?op=userclose">Log Out</a> ]\n	\n\n\n	<p>\n<label >\n	URL\n</label>\n </p>\n		<a href="http://homepage.mac.com/" rel="nofollow">http://homepage.mac.com/</a>\n\n\n	\n\n	<p>\n<label >\n	Subject\n</label>\n </p>\n		<input type="text" name="postersubj" value="Re:test me" size="50" maxlength="50">\n	\n	\n		<p>\n<label >\n	Comment\n</label>\n </p>\n		<textarea wrap="virtual" name="postercomment" rows="10" cols="50"></textarea>\n		<div class="note">\nUse the Preview Button! Check those URLs!\n</div>\n		<br>\n		\n\n	 \n\n\n		<input type="hidden" name="nobonus_present" value="1">\n		<input type="checkbox" name="nobonus"> No Karma Bonus\n\n		<input type="hidden" name="postanon_present" value="1">\n		<input type="checkbox" name="postanon"> Post Anonymously\n<br>\n\n\n\n\n<p>\n	\n\n<!-- start template: ID 234, select;misc;default -->\n\n<select name="posttype">\n	<option value="1">Plain Old Text</option>\n	<option value="2" selected>HTML Formatted</option>\n	<option value="3">Extrans (html tags to text)</option>\n	<option value="4">Code</option>\n</select>\n\n<!-- end template: ID 234, select;misc;default -->\n\n\n	<input type="submit" name="op" value="Preview" class="button">\n	\n	<input type="submit" name="op" value="Submit" class="button">\n	\n</p>\n\n			<div class="notes">\n				<b>Allowed HTML</b><br>\n				&lt;b&gt;			&lt;i&gt;			&lt;p&gt;			&lt;a&gt;			&lt;li&gt;			&lt;ol&gt;			&lt;ul&gt;			&lt;em&gt;			&lt;br&gt;			&lt;tt&gt;			&lt;strong&gt;			&lt;blockquote&gt;			&lt;div&gt;			&lt;ecode&gt;			&lt;dl&gt;			&lt;dt&gt;			&lt;dd&gt;			&lt;q&gt;\n				\n	\n				<br>	\n				<b>URLs</b><br>\n				<code>&lt;URL:http://example.com/&gt;</code> will auto-link a URL\n				<br>\n				<b>Important Stuff</b>\n				<ul>\n					<li>Please try to keep posts on topic.</li>\n					<li>Try to reply to other people\'s comments instead of starting new threads.</li>\n					<li>Read other people\'s messages before posting your own to avoid simply duplicating what has already been said.</li>\n					<li>Use a clear subject that describes what your message is about.</li>\n					<li>Offtopic, Inflammatory, Inappropriate, Illegal, or Offensive comments might be moderated. (You can read everything, even moderated posts, by adjusting your threshold on the User Preferences Page)</li>\n					\n				</ul>\n\n				<p>\n					Problems regarding accounts or comment posting should be sent to <a href="mailto:pudge@pobox.com">Slash Admin</a>.\n				</p>\n			</div>	\n	</fieldset>\n</form>\n	</div>\n';
	return false;
}


function readRest(cid) {
	var shrunkdiv = $('comment_shrunk_' + cid);
	if (!shrunkdiv)
		return void(0); // seems we shouldn't be here ...

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

	return void(0);
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

