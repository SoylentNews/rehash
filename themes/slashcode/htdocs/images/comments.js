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
var prerendered = 0;
var user_uid = 0;

function updateComment(cid, mode) {
	var existingdiv = $('comment_'+cid);
	if (existingdiv) {
		existingdiv.className = mode;
		var existinglink = $('comment_link_' + cid);
		if (existinglink) {
			if (mode == 'full') {
				existinglink.href = 'javascript:setFocusComment(-' + cid + ');';
			} else {
				existinglink.href = 'javascript:setFocusComment(' + cid + ');';
			}
		}
	}
	displaymode[cid] = mode;
	return void(0);
}


function updateCommentTree(cid) {
	var comment = comments[cid];
	if (futuredisplaymode[cid] != displaymode[cid]) { 
		updateComment(cid, futuredisplaymode[cid]);
	}

	var kidhiddens = 0;
	if (comment['kids'].length) {
		for (var kiddie = 0; kiddie < comment['kids'].length; kiddie++) {
			kidhiddens += updateCommentTree(comment['kids'][kiddie]);
		}	
	}

	var hiddens_cid = $("hiddens_"+cid);
	if (! hiddens_cid) { // race condition, probably: new comment added in between rendering, and JS data structure
		return 0;
	}

	if (displaymode[cid] == 'hidden') {
		hiddens_cid.className = "hide";
		return kidhiddens + 1 ;
	} else if (kidhiddens) {
		hiddens_cid.innerHTML = kidhiddens+" comments are hidden."; 
		hiddens_cid.className = "show";
	} else {
		hiddens_cid.className = "hide";
	} 

	return 0;
}

function renderRoots(element) {
	for (var cid in displaymode) {
		futuredisplaymode[cid] = prehiddendisplaymode[cid] = defaultdisplaymode[cid] = displaymode[cid];
	}
}


function faGetSetting(cid, ctype, relation, prevview, canbelower) {
	var newview = behaviors[ctype][relation];

	if (newview == 'none') {
		return prevview;
	} else if (newview == 'prehidden') {
		return prehiddendisplaymode[cid];
	}

	if ((viewmodevalue[newview] > viewmodevalue[prevview]) || canbelower) {
		return newview;	
	} 

	return prevview; 
}

function getDescendants(cids, first) {
	// don't include first round of kids in descendants, redundant
	var descs = first ? [] : cids;

	for (var i = 0; i < cids.length; i++) {
		var cid = cids[i];
		var kids = comments[cid]['kids'];
		if (kids.length) {
			descs = descs.concat(getDescendants(kids)); 
		}
	}

	return descs;
}

function findAffected(type, cid, override) {
	if (!cid) { return; }
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
			if (type == 'focus') {
				if (viewmodevalue[futuredisplaymode[comments[desc]['pid']]] < viewmodevalue['full']) {
					thistype = 'collapse';
				}
			}
			updateDisplayMode(desc, faGetSetting(desc, thistype, 'descendants', futuredisplaymode[desc], override));
		}
	}
}

function updateDisplayMode(cid, mode, newdefault) {
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
	if (roothiddens) {
		$('roothiddens').innerHTML = roothiddens + " comments are beneath your threshhold";
		$('roothiddens').className = "show";
	} else {
		$('roothiddens').className = "hide";
	}
	/* NOTE need to display note for hidden root comments */
	return void(0);
}

function setFocusComment(cid) {
	var abscid = Math.abs(cid);

	var statusdiv = $('comment_status_' + abscid);
	statusdiv.innerHTML = 'Working ...';

	refreshDisplayModes(cid); 
	updateCommentTree(abscid);

	statusdiv.innerHTML = '';

	var comment_y = getOffsetTop($("comment_"+abscid));
	var newcomment_y = getOffsetTop($("comment_"+abscid));
	if (comment_y != newcomment_y) {
		var diff = newcomment_y - comment_y;
		scroll(viewWindowLeft(), viewWindowTop() + diff);
	}
	return void(0);
}

var _tpNS = (document.all)?false:true;

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


function readRest(cid) {
	var shrunkdiv = $('comment_shrunk_' + cid);
	if (!shrunkdiv) {
		return false; // seems we shouldn't be here ...
	}

	var params = [];
	params['op']  = 'comments_read_rest';
	params['cid'] = cid;

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
