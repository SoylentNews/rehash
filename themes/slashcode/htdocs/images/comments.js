var comments;
var root_comments;
var authorcomments;
var behaviors = {
	'default': { ancestors: 'none', parent: 'none', children: 'none', descendants: 'none', siblings: 'none', sameauthor: 'none' }, 
	'focus': { ancestors: 'none', parent: 'none', children: 'full', descendants: 'none', siblings: 'none', sameauthor: 'none' }, 
	'collapse': { ancestors: 'none', parent: 'none', siblings: 'none', sameauthor: 'none', currentmessage: 'oneline', children: 'hidden', descendants: 'hidden'} };
var behaviorrange = ['none', 'full', 'oneline', 'hidden'];
var displaymode = { 0: 1};
var futuredisplaymode = { 0: 1};
var focalcids = [];
var focalcidshash = {};
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
//alert(cid);
	var comment = comments[cid];
	if ((futuredisplaymode[cid] != displaymode[cid]) || (focalcidshash[-1 * cid] == 1)) { 
//alert('updating');
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
//	refreshDisplayModes(); 
}


function faGetSetting(ctype, relation, prevview, canbelower) {
	var newview = behaviors[ctype][relation];

	


	if (newview == 'none') { return prevview; }
	if ((viewmodevalue[newview] > viewmodevalue[prevview]) || canbelower) {
		return newview;	
	} 

	return prevview; 
}

function getDescendants(cids) {
	var descs = cids;
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

	var pid = comment['pid'];
	if (pid) {
		futuredisplaymode[pid] = faGetSetting(type, 'parent', futuredisplaymode[pid], override);
	
		var parent = 0;
		while (pid) {
			parent = comments[pid];
			pid = parent['pid'];
			if (pid) {
				futuredisplaymode[pid] = faGetSetting(type, 'ancestors', futuredisplaymode[pid], override);
			}
		}
		pid = comment['pid'];
		var sibs = comments[pid]['kids'];
		for(var i = 0; i < sibs.length; i++) {
			var sib = sibs[i];
			futuredisplaymode[sib] = faGetSetting(type, 'siblings', futuredisplaymode[sib], override);
		}
	}
	
	var kids = comment['kids'];
	if (kids.length) {
		for (var i = 0; i < kids.length; i++) {
			var kid = kids[i];	
			futuredisplaymode[kid] = faGetSetting(type, 'children', futuredisplaymode[kid], override);
		}

		var descendants = getDescendants(kids);
		for (var i = 0; i < descendants.length; i++) {
			var desc = descendants[i];
			futuredisplaymode[desc] = faGetSetting(type, 'descendants', futuredisplaymode[desc], override);
		}
	}
}

function refreshDisplayModes(cid) {
	var fulls = Array();
	if (cid) {
		fulls.push(cid);
	} else {
		for (var mykey in comments) {
			if (futuredisplaymode[mykey] == 'full') {
				fulls.push(mykey);
			}
		}
	}

	/* decide mode based on basic functions */
	for (var i = 0; i < fulls.length; i++) {
		findAffected('default', fulls[i], 0); 
	}

	if (focalcids.length) {
		for (var i = 0; i < focalcids.length; i++) {
			var focalcid = focalcids[i];	
			if (focalcid > 0) {
				futuredisplaymode[focalcid] = 'full';
				findAffected('focus', focalcid, 0); 
			} else {
				focalcid = -1 * focalcid;
				futuredisplaymode[focalcid] = behaviors['collapse']['currentmessage'];
				findAffected('collapse', focalcid, 1);
			}
		}
	}
	return void(0);
}

function refreshCommentDisplays() {
	refreshDisplayModes(); 

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
	var alreadyfocused = -1;
	for (var i = 0; i < focalcids.length; i++) {
		if (focalcids[i] == cid || focalcids[i] == (-1 * cid)) {
			alreadyfocused = i;
		}
	}

	if (alreadyfocused != -1) {
		focalcids.splice(alreadyfocused, 1);
		focalcidshash[cid] = 0;
		focalcidshash[(cid * -1)] = 0;
	}
	focalcids.push(cid);	
	focalcidshash[cid] = 1;

	var abscid = Math.abs(cid);

	var comment_y = getOffsetTop($("comment_"+abscid));
//	refreshCommentDisplays();
refreshDisplayModes(); 
updateCommentTree(abscid);
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

