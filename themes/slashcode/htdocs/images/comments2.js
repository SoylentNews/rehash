var comments;
var root_comments;
var authorcomments;
var threshhold = 4;
var fullthreshhold = 4;
var promotedepth = 1;
var behaviors = {
	'default': { ancestors: 'none', parent: 'none', children: 'none', descendants: 'none', siblings: 'none', sameauthor: 'none' }, 
	'focus': { ancestors: 'none', parent: 'none', children: 'none', descendants: 'none', siblings: 'none', sameauthor: 'none' }, 
	'collapse': { ancestors: 'none', parent: 'none', siblings: 'none', sameauthor: 'none', currentmessage: 'oneline', children: 'hidden', descendants: 'hidden'} };
var behaviorrange = ['none', 'full', 'oneline', 'hidden'];
var authorcids = {};
var displaymode = { 0: 1};
var futuredisplaymode = { 0: 1};
var focalcids = [];
var currentdepth = 1;
var pointsums = [];

var remainingroots = [];
var allroothiddens = 0;
var rootpe;

function togglevis(nr)
{
	var vista = (document.getElementById(nr).style.display == 'none') ? 'block' : 'none';
	document.getElementById(nr).style.display = vista;
}

function blocking(nr) 
{
	togglevis(nr + "_oneline");	
	togglevis(nr + "_full");	
}

function divit(id, content) {
	return '<div id="' +id+ '">'+content+'</div>'; 
}

/* hocked from javascript.internet.com */
function stripHTML(Word) {
	a = Word.indexOf("<");
	b = Word.indexOf(">");
	len = Word.length;
	c = Word.substring(0, a);
	if(b == -1) b = a;
	d = Word.substring((b + 1), len);
	Word = c + d;
	tagCheck = Word.indexOf("<");
	if(tagCheck != -1) Word = stripHTML(Word);
	return Word;
}

function wordbreak(content, maxlen) {
	content = stripHTML(content);
	var words = content.split(' ');
	var retval = "";
	for (var w = 0; w < words.length; w++) {
		var newretval = retval +' '+ words[w];
		if (newretval.length < maxlen) {
			retval = newretval;
		} else {
			return retval + '...';
		}
	}
	return retval + '...';
}

function replyTo() {
	return '[ <a href="//ask.slashdot.org/comments.pl?sid=175930&amp;op=Reply&amp;threshold=1&amp;commentsort=0&amp;mode=thread&amp;pid=14620800">Reply to This</a> ]';
}

function flipLink(cid, mode) {
	var newmode = mode=='full'?'oneline':'full';
	var classa = newmode=='full'?'dwns':'ups';
	var polarity = newmode=='full'?'':'-';

	
	return '<span class="'+classa+'" onClick="setFocusComment('+polarity+cid+'); void(0); return false;">&nbsp;</span>';
}


function renderCommentOneLine(cid) { 
	var comment = comments[cid];
	var retval = flipLink(cid, 'oneline') + '<a href="javascript:setFocusComment('+cid+');">';

	retval = retval + comment['subject']+'</a> by '+comment['nickname'];

	retval = retval +' (Score:'+comment['points']+') ';

 	return retval + wordbreak(comment['comment'], 45);
}

function renderCommentFull(cid) {
	var comment = comments[cid];
	return '<div class="commentTop"> '+flipLink(cid,'full')+'<div class="title"><h4><a name="14620800">'+comment['subject']+'</a></h4>                    (Score: '+comment['points']+', XXXXX) </div> <div class="details">                    by '+comment['nickname']+ ' on '+comment['date']+' (<a href="javascript:setFocusComment('+cid+');">'+cid+'</a>) </div></div>            <div class="commentBody">  '+comment['comment']+'  </div>'+ replyTo(cid);
}

function renderComment(cid, mode) {
	if (mode == 'oneline') {
		displaymode[cid] = 'oneline'; 
		return renderCommentOneLine(cid);
	} else if (mode == 'full') {
		 displaymode[cid] = 'full'; 
		return renderCommentFull(cid);
	} 
	displaymode['cid'] = 'hidden';
	return ""; /*this is when it's hidden*/
}

function updateComment(cid, mode) {
	var existingdiv = $(cid + '_comment');
	if (existingdiv) {
		existingdiv.innerHTML = renderComment(cid, mode);
		/* if (displaymode['cid'] == 'hidden') {
			$(cid + "_tree").className = "hide";
		} else {
			$(cid + "_tree").className = "comment";
		} */
	}
	displaymode[cid] = mode;
	return void(0);
}


function decideMode(cid) {
	var comment = comments[cid];
	if (comment['points'] < threshhold) { 
		return 'hidden'; 
	} 
	if (comment['points'] >= fullthreshhold) { return 'full'; }
	if (promotedepth && comment['depth'] == currentdepth) { return 'full'; } 
	return 'oneline';
}

function renderCommentTree(cid) {
	var comment = comments[cid];
	var retval;
	/* if (futuredisplaymode[cid] == 'hidden') {
		retval = '<li id="'+cid+'_tree" class="hide">';
	} else { */
		retval = '<li id="'+cid+'_tree" class="comment">';
	/* } */
	retval = retval + divit(cid + '_comment', renderComment(cid, futuredisplaymode[cid]));
	retval = retval + '<ul id="'+cid+'_group">';
	var hiddens = 0;
	if (comment['kids'].length) {
		for (var kiddie = 0; kiddie < comment['kids'].length; kiddie++) {
			var kidrets =  renderCommentTree(comment['kids'][kiddie]);
			retval = retval + kidrets[0];
			hiddens += kidrets[1];
			if (futuredisplaymode[comment['kids'][kiddie]] == 'hidden') {
				hiddens++;			
			}
		}
	}

	if (futuredisplaymode[cid] == 'hidden') {
		retval = retval + '<li id="'+cid+'_hiddens" class="hide"></li>';
		hiddens += 1;
	} else if (hiddens) {
		retval = retval + '<li id="'+cid+'_hiddens">'+hiddens+" reply beneath your current threshhold.</li>";
	} else {
		retval = retval + '<li id="'+cid+'_hiddens" class="hide"></li>';
	} 
		
	retval = retval + '</ul>';
	retval = retval + '</li>';
	
	return [retval, hiddens];
}

function updateCommentTree(cid) {
	var comment = comments[cid];
	if (futuredisplaymode[cid] != displaymode[cid]) 
		updateComment(cid, futuredisplaymode[cid]);

	var kidhiddens = 0;
	if (comment['kids'].length) {
		for (var kiddie = 0; kiddie < comment['kids'].length; kiddie++) {
			kidhiddens += updateCommentTree(comment['kids'][kiddie]);
		}	
	}

	if (displaymode[cid] == 'hidden') {
		$(cid+"_hiddens").className = "hide";
		return kidhiddens + 1 ;

	} else if (kidhiddens) {
		$(cid+"_hiddens").innerHTML = kidhiddens+" reply are hidden."; 
		$(cid+"_hiddens").className = "show";
	} else {
		$(cid+"_hiddens").className = "hide"; 
	} 
	return 0;
}

function renderRootsAsync() {
	if (!remainingroots.length) { return void(0); }
	var step = 2;
	var i = 0;
	var root;
	var element = 'commentlisting';

	while (remainingroots.length && i < step) {
		root = remainingroots.shift();
		rootret = renderCommentTree(root);
		$(element).innerHTML = $(element).innerHTML + rootret[0];
		allroothiddens += rootret[1];
		i++;
	}

	if (remainingroots.length) { return void(0); }
	if (allroothiddens) {
		$(element).innerHTML = $(element).innerHTML + '<li id="roothiddens">'+allroothiddens+' comments are beneath your threshhold</li>'
	} else {
		$(element).innerHTML = $(element).innerHTML + '<li id="roothiddens" class="hide"></li>'
	}

	rootpe.currentlyExecuting = true;
}

function renderRoots(element) {

	threshhold = Math.floor(Math.random() * 7)-1;	
	fullthreshhold = threshhold + Math.floor(Math.random() * (6-threshhold));

	renderThreshholdWidget();
	/*randomizeBehaviors('default');*/
	renderBehaviorWidget('default', 'defaultbehaviors');
	/*randomizeBehaviors('focus');*/
	renderBehaviorWidget('focus', 'focusbehaviors');
	refreshDisplayModes(); 

	remainingroots = root_comments.concat([]); 
	rootpe = new PeriodicalExecuter(renderRootsAsync, .5);
}

function getComments(sid, element) {
	var params = [];
	params['op'] = 'get_comments';
	params['sid'] = sid;
	ajax_update(params, '', { evalScripts: 1 }, 'http://use.perl.org/ajax.pl');
}

function randomizeBehaviors(ctype) {
	for (var relation in behaviors[ctype]) {
		ind = Math.floor(Math.random() * behaviorrange.length);
		behaviors[ctype][relation]=behaviorrange[ind];
	}
}

function renderBehaviorWidget(ctype, elementname) {
	var newhtml = "";

	for (var relation in behaviors[ctype]) {
		newhtml = newhtml + '<li style="display: inline; padding: .2em 1em;"><label>' + relation +
			'<select id="' + ctype + '_' + relation + '">';
		for (var i = 0; i < behaviorrange.length; i++) {
			newhtml = newhtml + '<option value="' +behaviorrange[i] + '"';
			if (behaviors[ctype][relation] == behaviorrange[i]) {
				newhtml = newhtml + " selected";
			}
			newhtml = newhtml + ">" + behaviorrange[i] + "</option>";
		}
		newhtml = newhtml + "</select></label></li>";
	}

	$(elementname).innerHTML = newhtml;

	return void(0);
}

function renderThreshholdWidget() {
   if (pointsums.length) {
       return void(0);
   } else {
	   pointsums[0] = 0;
	   pointsums[1] = 0;
	   pointsums[2] = 0;
	   pointsums[3] = 0;
	   pointsums[4] = 0;
	   pointsums[5] = 0;
	   pointsums[6] = 0;
	   /* there's a better way to do this i hope? */
   }	

	for (var cid in comments) {
		pointsums[comments[cid]['points']+1]++;
	}
	
	var sum = 0;
	for (var i=6; i >= 0; i--) {
		pointsums[i] = pointsums[i] + sum;
		sum = pointsums[i] + sum;
	}
	
	$('threshholdselect').length = 0;
	$('fullthreshholdselect').length = 0;
	var retval = "";
	for (var i = 0; i <= 6; i++) {
		$('threshholdselect').options[i] = new Option((i-1)+": "+pointsums[i]+" comments", i-1); 
		$('fullthreshholdselect').options[i] = new Option((i-1)+": "+pointsums[i]+" comments", i-1); 
	}

	$('threshholdselect').value = threshhold;
	$('fullthreshholdselect').value = fullthreshhold;

	return void(0);
}

function faGetSetting(ctype, relation, prevview, canbelower) {
	var newview = behaviors[ctype][relation];

	if ((viewmodevalue[newview] > newmodevalue[preview]) || canbelower) {
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
		if (faGetSetting(type, 'parent') != 'none') {
			if (override || futuredisplaymode[pid] != 'full') {
			futuredisplaymode[pid] = faGetSetting(type, 'parent', futuredisplaymode[pid], override);
			}
		}
		if (faGetSetting(type, 'ancestors') != 'none') {
			var parent = 0;
			while (pid) {
				parent = comments[pid];
				pid = parent['pid'];
				if (pid && (override || futuredisplaymode[pid] != 'full')) {
					futuredisplaymode[pid] = faGetSetting(type, 'ancestors');
			 	}
			}
		}
		pid = comment['pid'];
		if (faGetSetting(type, 'siblings') != 'none') {
			var sibs = comments[pid]['kids'];
			for(var i = 0; i < sibs.length; i++) {
				var sib = sibs[i];
				if (override || futuredisplaymode[sib] != 'full') {
					futuredisplaymode[sib] = faGetSetting(type, 'siblings');
				}
			}
		}
	}
	
	var kids = comment['kids'];
	if (kids.length) {
		if (faGetSetting(type, 'children') != 'none') {
			for (var i = 0; i < kids.length; i++) {
				var kid = kids[i];	
				if (override || futuredisplaymode[kid] != 'full') {
					futuredisplaymode[kid] = faGetSetting(type, 'children');
				}
			}
		}

		if (faGetSetting(type, 'descendants') != 'none') {
			var descendants = getDescendants(kids);
			for (var i = 0; i < descendants.length; i++) {
				var desc = descendants[i];
				if (override || futuredisplaymode[desc] != 'full') {
					futuredisplaymode[desc] = faGetSetting(type, 'descendants');
				}
			}
		}
	}

	var uid = comment['uid'];
	if (faGetSetting(type, 'sameauthor') != 'none') {
		var sameauthor = authorcids[uid];	
		for (var i = 0; i < sameauthor.length; i++) {
			var sacid = sameauthor[i];
			if (override || futuredisplaymode[sacid] != 'full') {
				futuredisplaymode[sacid] = faGetSetting(type, 'sameauthor');
			}
		} 
	}

}

function refreshDisplayModes() {
	var fulls = Array();
	authorcids = {};
	for (var mykey in comments) {
		uid = comments[mykey]['uid'];
		if (!authorcids[uid]) {
			authorcids[uid] = new Array(mykey);	
		} else {
			authorcids[uid].push(mykey);
		}
		futuredisplaymode[mykey] = decideMode(mykey);
		if (futuredisplaymode[mykey] == 'full') {
			fulls.push(mykey);
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


function refreshSettings() {
	var changed = 0;
	/* one of the threshholds have changed, rerender */

	if (threshhold != $('threshholdselect').value) {
		threshhold = $('threshholdselect').value;
		changed = 1;
	}

	if (fullthreshhold != $('fullthreshholdselect').value) {
		fullthreshhold = $('fullthreshholdselect').value;
		changed = 1;
	}
	/* not sure if these are right is it value?*/

	if (threshhold > fullthreshhold) {
		threshhold = fullthreshhold;
		$('threshholdselect').value = $('fullthreshholdselect').value;
		changed = 1;
	}
	
	var pd;
	if ($('promotedepth').checked) {
		pd = 1;
	} else {
		pd = 0;
	}

	if (promotedepth != pd) {	
		promotedepth = pd; 
		changed = 1;
	}
	
	prefbehaviors = ['default', 'focus'];
	for (var ctype in prefbehaviors) { 
		for (var relation in behaviors[ctype]) {
			if (behaviors[ctype][relation] != $(ctype+'_'+relation).value) {
				behaviors[ctype][relation] = $(ctype+'_'+relation).value;
				changed = 1;
			}
		}
	}

	if (changed) {
		refreshCommentDisplays();
	}
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
	} else {
		focalcids.push(cid);	
	}
	refreshCommentDisplays();
	return void(0);
}




