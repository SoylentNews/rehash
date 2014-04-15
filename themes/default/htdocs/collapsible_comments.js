// SoylentNews Expandable Comment Tree
// 2014-02-25
//
// Based on Slashdot Expandable Comment Tree v2
// Version of 2008-12-05
// http://althenia.net/userjs
//
// Copyright 2006 Andrey Zholos <aaz@althenia.net>
// Released under the GNU GPL license: http://www.gnu.org/copyleft/gpl.html
// There is no warranty; not even for merchantability or fitness for a
// particular purpose. See the license for more details.
//
// This is a Greasemonkey script. Greasemonkey is an extension for the Mozilla
// Firefox web browser. To install it, visit http://greasemonkey.mozdev.org
//
//
// This script adds the following buttons in front of comments on Slashdot:
//
//   [+] and [-]
//       Expand or collapse a single comment.
//
//       If a comment is in a collapsed state on the original page, it is
//       loaded from the page to which that comment links. All other comments
//       that are shown on that page are also loaded, but not expanded.
//
//   [++]
//       Expand all comments in this branch.
//
//       All loaded comments are expanded, and all comments from the page of
//       the nearest comment that has not yet been loaded are loaded and
//       expanded. Thus, repeated clicking on this button will load and display
//       all comments in this branch.
//
//       This also shows all hidden comments in this branch.
//
//   [--]
//       Collapse all comments in this branch.
//
//   [.]
//       Hide or show all replies to this comment.
//
//       This does not affect the loading of the hidden comments with the above
//       buttons.
//
//       Hiding also collapses the comment.
//

// Changes:
// 2014-02-25:
//   + Change @include to load on soylentnews.org
//   + Fix "class" reserved word conflict
//   + Xpath tweaks to match open comments on soylentnews.org
//   + Add @grant lines to shut up greasemonkey
// 2008-12-05:
//   + Adopted by Teridon to get it working again
// 2006-06-10:
//   + Better ordering of simultaneous requests when using [++]
// 2006-06-06:
//   + Use images for buttons instead of text
// 2006-04-08:
//   + Expand comments that have a "Read the rest of this comment..." link
//   + Multiple simultaneous server requests when using [++] button
// 2006-03-31:
//   + Support document access both through XPath (Firefox, Opera 9) and
//     thorugh the DOM (Opera 8).
//   + Insert elements in the background so the browser doesn't lock up for
//     several seconds on big pages.


// ==UserScript==
// @name          SoylentNews Expandable Comment Tree
// @namespace     FoobarBazbot
// @description   Expand and collapse any comments on a SoylentNews page. Comments not on the original page can also be expanded, they are loaded from the server.
// @include       http*://soylentnews.org/*
// @include       http*://*.soylentnews.org/*
// @grant         internal_log
// @grant         GM_xmlhttpRequest
// ==/UserScript==




(function() {

// Configuration:

var log = false;
if (log) { internal_log("HI THERE");}

// Maximum number of requests made to fetch comments when the [++] button is pressed:
var optionSimultaneous = 3;

// Use larger button icon set (true / false):
var optionLargerButtons = true;

// Highlight buttons (true / false):
var optionHighlightButtons = true;


// If debugging is needed, turn this into something useful
function internal_log(message) {
    return Console.log(message);
}

/* Select a single node using XPath */

function xpathNode(xpath, context) {
    return document.evaluate(xpath, context ? context : document, null, XPathResult.ANY_UNORDERED_NODE_TYPE, null).singleNodeValue;
}

/* Select several nodes using XPath */

function xpathCollection(xpath, context) {
    return document.evaluate(xpath, context ? context : document, null, XPathResult.ORDERED_NODE_SNAPSHOT_TYPE, null);
}

/* Get a string value using XPath */

function xpathString(xpath, context) {
    return document.evaluate(xpath, context ? context : document, null, XPathResult.STRING_TYPE, null).stringValue;
}

/* Get a number using XPath */

function xpathNumber(xpath, context) {
    return document.evaluate(xpath, context ? context : document, null, XPathResult.NUMBER_TYPE, null).numberValue;
}


/* Load an external document */

function xmlHttpGet(url, onload) {
    try {
        var xmlHttp = new XMLHttpRequest();
        xmlHttp.onreadystatechange = function() { if (xmlHttp.readyState == 4) onload(xmlHttp.responseText); }
        xmlHttp.open("GET", url, true);
        xmlHttp.send(null);
    } catch (e) {
        internal_log("error 2 getting URL;");
    }
}


/* Toggle button images. The first five of each group are the [+], [-], [++],
   [--] and [.] images; the rest are the highlighted versions. */

var toggleButtons = !optionLargerButtons ? [
    "R0lGODdhCQAJAIABAAAAAP///ywAAAAACQAJAAACEYSPoRu28KCSDSJLc44s3lMAADs=",
    "R0lGODdhCQAJAIAAAAAAAP///ywAAAAACQAJAAACEISPoRvG614D80x5ZXyogwIAOw==",
    "R0lGODlhCQAJAIABAAAAAP///ywAAAAACQAJAAACEYSPoavQHNxhLj67Zs0XRoQUADs=",
    "R0lGODdhCQAJAIAAAAAAAP///ywAAAAACQAJAAACEYR/oavA7NJyr0ETaNUPeVAAADs=",
    "R0lGODdhCQAJAIABAAAAAP///ywAAAAACQAJAAACEISPoRvG614DEFIZX2aogwIAOw==",
    "R0lGODdhCQAJAIABAAAAAMzMzCwAAAAACQAJAAACEYSPoRu28KCSDSJLc44s3lMAADs=",
    "R0lGODdhCQAJAIAAAAAAAMzMzCwAAAAACQAJAAACEISPoRvG614D80x5ZXyogwIAOw==",
    "R0lGODlhCQAJAIABAAAAAMzMzCwAAAAACQAJAAACEYSPoavQHNxhLj67Zs0XRoQUADs=",
    "R0lGODdhCQAJAIAAAAAAAMzMzCwAAAAACQAJAAACEYR/oavA7NJyr0ETaNUPeVAAADs=",
    "R0lGODdhCQAJAIABAAAAAMzMzCwAAAAACQAJAAACEISPoRvG614DEFIZX2aogwIAOw=="
] : [
    "R0lGODlhDgAOAIAAAP///wAAACH5BAAAAAAALAAAAAAOAA4AAAIgjI8Jy73mIoCNMvuCw1NXnxxZFo7f5l2pqaKS+6rhXAAAOw==",
    "R0lGODlhDgAOAIAAAP///wAAACH5BAAAAAAALAAAAAAOAA4AAAIdjI8Jy73mIoCy0foCZjSdnHngNmnkhaGVKnmuUQAAOw==",
    "R0lGODlhDwAOAIAAAP///wAAACH5BAAAAAAALAAAAAAPAA4AAAIgjI8ZwO2+WnxsAvsshlddLoGV+IWhsmzmSLEupbUtShcAOw==",
    "R0lGODlhDwAOAIAAAP///wAAACH5BAAAAAAALAAAAAAPAA4AAAIdjI8Jy93hIoMy0vpAMha762nWJoYL6KGYWm3uUQAAOw==",
    "R0lGODlhDgAOAIAAAP///wAAACH5BAAAAAAALAAAAAAOAA4AAAIdjI8Jy73mIoCy0foCZje7PmmWuIGSGaEfiSUuUgAAOw==",
    "R0lGODlhDgAOAIAAAMzMzAAAACH5BAAAAAAALAAAAAAOAA4AAAIgjI8Jy73mIoCNMvuCw1NXnxxZFo7f5l2pqaKS+6rhXAAAOw==",
    "R0lGODlhDgAOAIAAAMzMzAAAACH5BAAAAAAALAAAAAAOAA4AAAIdjI8Jy73mIoCy0foCZjSdnHngNmnkhaGVKnmuUQAAOw==",
    "R0lGODlhDwAOAIAAAMzMzAAAACH5BAAAAAAALAAAAAAPAA4AAAIgjI8ZwO2+WnxsAvsshlddLoGV+IWhsmzmSLEupbUtShcAOw==",
    "R0lGODlhDwAOAIAAAMzMzAAAACH5BAAAAAAALAAAAAAPAA4AAAIdjI8Jy93hIoMy0vpAMha762nWJoYL6KGYWm3uUQAAOw==",
    "R0lGODlhDgAOAIAAAMzMzAAAACH5BAAAAAAALAAAAAAOAA4AAAIdjI8Jy73mIoCy0foCZje7PmmWuIGSGaEfiSUuUgAAOw=="
];


/* Mouse event handler that swaps button images */

function toggleButtonHover(event) {
    var toggle = event.target;
    if (toggle) {
        var image = toggle.getAttribute("sxct_hover");
        toggle.setAttribute("sxct_hover", toggle.getAttribute("src"));
        toggle.setAttribute("src", image);
    }
}


/* Make an expand/collapse button element */

function toggleButton(button, event) {
    var toggle = document.createElement("img");
    toggle.style.cursor = "pointer";
    toggle.setAttribute("src", "data:image/gif;base64," + toggleButtons[button]);
    toggle.addEventListener("click", event, false);
    if (optionHighlightButtons) {
        toggle.setAttribute("sxct_hover", "data:image/gif;base64," + toggleButtons[button + 5]);
        toggle.addEventListener("mouseover", toggleButtonHover, false);
        toggle.addEventListener("mouseout", toggleButtonHover, false);
    }
    return toggle;
}


/* Insert a text node with a single space */

function insertSpace(node, before) {
    node.insertBefore(document.createTextNode(" "), before ? before : node.firstChild);
}



/* Wrap all selected elements into a div */

function divWrap(elements, myclass) {
    var div = document.createElement("div");
    div.setAttribute("class", myclass);

    for (var i = 0; i < elements.snapshotLength; i++) {
        var child = elements.snapshotItem(i);
        div.appendChild(child);
    }

    return div;
}



/* Test if an element is contained in an array */

function inArray(array, element) {
    for (var i = 0; i < array.length; i++)
        if (array[i] == element)
            return true;
}


/* Insert the relevant open and close buttons into a comment */

function commonCommentButtons(comment, where) {
    if (xpathNumber("count(.//li[not(ancestor::div[@class='commentBody'])])", comment)) {
        where.insertBefore(toggleButton(4, toggleHide), where.firstChild);
        insertSpace(where, where.firstChild);
        if (xpathNumber("count(.//li[not(ancestor::div[@class='commentBody']) and not(./b/a)])", comment)) {
            where.insertBefore(toggleButton(3, toggleCloseAll), where.firstChild);
            where.insertBefore(toggleButton(2, toggleOpenAll), where.firstChild);
            insertSpace(where, where.firstChild);
        }
    }
}

function openCommentButtons(comment) {
    var title = xpathNode("(./div[@class='sict_open'] | ./div[@class='sict_open']/div)/div[starts-with(@class,'commentTop')]/div[@class='title']/h4", comment);
    if (!title)
        return;

    insertSpace(title);
    commonCommentButtons(comment, title);
    title.insertBefore(toggleButton(1, toggleCloseEvent), title.firstChild);
}

function closedCommentButtons(comment) {
    var div = xpathNode("./div[@class='sict_closed']", comment);
    if (!div)
        return;

    var commentLink = xpathNode("./a", div);
    if (commentLink)
        commentLink.style.backgroundImage = "none";

    insertSpace(div);
    commonCommentButtons(comment, div);
    div.insertBefore(toggleButton(0, toggleOpenEvent), div.firstChild);
}



/* When a comment is closed, it is hidden and its closed string, which is
   already inserted next to it, is shown. */

function toggleCloseEvent(event) {
    toggleClose(event.target);
}

function toggleClose(target) {
    var open = xpathNode("ancestor-or-self::div[@class='sict_open']", target);
    var closed = xpathNode("parent::li/div[@class='sict_closed']", open);

    if (!open || !closed)
        return;

    open.style.display = "none";
    closed.style.display = "block";
    closed.parentNode.removeAttribute("class");
    closed.removeAttribute("sict_opening");
}



/* Collapse and expand the comment and all its descendants. */

function toggleCloseAll(event) {
    var comment = xpathNode("ancestor::div[@class='sict_open' or @class='sict_closed']/parent::li", event.target);
    if (!comment)
        return;

    var comments = xpathCollection("descendant-or-self::li[not(ancestor::div[@class='commentBody'])]", comment);

    for (var i = 0; i < comments.snapshotLength; i++) {
        var item = comments.snapshotItem(i);
        var closed = xpathNode("./div[@class='sict_closed']", item);
        var open = xpathNode("./div[@class='sict_open']", item);
        if (!closed)
            continue;

        if (open)
            toggleClose(open);
        else
            closed.removeAttribute("sict_opening");
    }
}

function toggleOpenAll(event) {
    var comment = xpathNode("ancestor::div[@class='sict_open' or @class='sict_closed']/parent::li", event.target);
    if (!comment)
        return;

    var cid = comment.getAttribute("sict_cid");

    var unopened = new Array;

    var comments = xpathCollection("descendant-or-self::li[not(ancestor::div[@class='commentBody'])]", comment);

    for (var i = 0; i < comments.snapshotLength; i++) {
        var item = comments.snapshotItem(i);
        var closed = xpathNode("./div[@class='sict_closed']", item);
        var open = xpathNode("./div[@class='sict_open']", item);
        if (!closed)
            continue;

        if (open)
            toggleOpen(closed);
        else {
            closed.setAttribute("sict_opening", "1");
            var depth = xpathCollection("ancestor-or-self::li[ancestor-or-self::li[@sict_cid='" + cid + "']]", item).snapshotLength;

            while (unopened.length <= depth)
                unopened.push(new Array);

            unopened[depth].push(closed);
        }

        var ul = xpathNode("./ul", item);
        if (ul && ul.style.display == "none")
            ul.style.display = "block";
    }


    var unopenedLinks = new Array;
    var opened = 0;

    for (var i = 0; i < unopened.length; i++) {
        var unopenedLevel = unopened[i];
        for (var j = 0; j < unopenedLevel.length; j++) {
            var unopenedItem = unopenedLevel[j];

            var link = xpathString("./a/@href", unopenedItem);

            if (link) {
                link = link.replace(/#.*/, "");
                if (inArray(unopenedLinks, link))
                    continue;
                unopenedLinks.push(link);
            }

            toggleOpen(unopenedItem);
            if (++opened >= optionSimultaneous)
                return;
        }
    }
}

if (log) { internal_log("before insertOpen");}


/* Insert all opened comments from the loaded page near their closed strings */

function insertOpen(comments) {
    /* A hackish way to get what's inside the body tags. */

    if (log) { internal_log("insertOpen pos 0");}

    var i = comments.indexOf("<body>");
    var j = comments.lastIndexOf("</body>");
    if (i < 0 || j < 0) {
	    internal_log("no commments!");
        return;
    }
    comments = comments.slice(i + 6, j)

if (log) { internal_log("insertOpen pos 1");}
    /* Insert the text into the document temporarily so that the HTML is
       parsed. The DOMParser only parses valid XML, which this is not. */

    var commentsContainer = document.createElement("div");
    commentsContainer.style.display = "none";
    var body = xpathNode("//body");
    if (!body) {
	    internal_log("NO BODY!");
        return;
    }

    body.appendChild(commentsContainer);
    commentsContainer.innerHTML = comments;


    /* Process the opened comments. */

    var openComments = xpathCollection(".//ul[@id='commentlisting']//li[@class='comment']", commentsContainer);

    if (log) { internal_log("comment listing length is " + openComments.snapshotLength); }
    for (var i = 0; i < openComments.snapshotLength; i++) {
        var comment = openComments.snapshotItem(i);

        /* Find the comment cid */

        var cid;
        try {
            cid = xpathString("(./div | ./div/div)[starts-with(@class,'commentTop')]/div[@class='details']/span[@class='otherdetails']/a[last()]/@href", comment).match(/(cid=|#)(\d+)/)[2];
        } catch (e) {
            continue;
        }


        /* Insert the opened comment into the real discussion */

        var realComment = xpathNode("//li[@sict_cid='" + cid + "']");

        if (realComment) {

            /* Extract all elements that make up the opened comment and wrap them in a
            div. The ul element that contains all child posts is not included. */

            var openDiv = divWrap(xpathCollection("./div[not(@class) or @class!='comment_footer'] | ./a | ./text()", comment), "sict_open");

            /* Find the closed and open views of this comment */

            var closed = xpathNode("./div[@class='sict_closed']", realComment);
            if (!closed)
                continue;

            var open = xpathNode("./div[@class='sict_open']", realComment);
            if (open) {
                if (open.getAttribute("sict_rest"))
                    open.parentNode.removeChild(open);
                else
                    continue;
            }


            /* Insert an open button in front of a "Read the rest..." link */

            var commentBody = xpathNode("(./div | ./div/div)[@class='commentBody']", openDiv);
            if (commentBody) {
                var restLink = xpathNode("./div[@class='commentshrunk']/a", commentBody);
                if (restLink) {
                    var closedLink = xpathNode("./a", closed);
                    if (closedLink) {
                        closedLink.setAttribute("href", restLink.getAttribute("href"));
                        openDiv.setAttribute("sict_rest", "1");
                        restLink.parentNode.insertBefore(toggleButton(0, toggleOpenEvent), restLink);
                        insertSpace(restLink.parentNode, restLink);
                    }
                }
            }


            /* Insert the comment into the tree */

            realComment.insertBefore(openDiv, realComment.firstChild);
            openCommentButtons(realComment);
            if (closed.getAttribute("sict_opening")) {
                closed.style.display = "none";
                closed.removeAttribute("sict_opening");
                realComment.setAttribute("class", "comment");
            } else
                openDiv.style.display = "none";
        }
    }


    /* Remove the temporary content. */

    body.removeChild(commentsContainer);
}



/* When a comment is opened and it is not already inserted next to the closed
   string, the relevant page is loaded from the server, and all opened comments
   on that page are inserted near their closed strings. */

function toggleOpenEvent(event) {
    toggleOpen(event.target);
}

function toggleOpen(target) {
    var closed = xpathNode("ancestor-or-self::div[@class='sict_closed']", target);
    var open = xpathNode("parent::li/div[@class='sict_open']", closed);

    if (!closed) {
        /* In the case of the button that expands an incomplete open comment */

        open = xpathNode("ancestor-or-self::div[@class='sict_open']", target);
        closed = xpathNode("parent::li/div[@class='sict_closed']", open);
        if (!closed)
            return;
    }

    if (open) {
        closed.style.display = "none";
        closed.removeAttribute("sict_opening");
        open.style.display = "block";
        open.parentNode.setAttribute("class", "comment");
    }

    if (!open || open.getAttribute("sict_rest")) {
        var cidUrl = xpathString("./a/@href", closed).replace(/#\d*$/, "").replace(/^\/\//, "http://");

        if (cidUrl) {
            closed.setAttribute("sict_opening", "1");
            xmlHttpGet(cidUrl, insertOpen);
        }
    }
}



/* Hide or show all comments in the ul below this one */

function toggleHide(event) {
    var ul = xpathNode("ancestor::div[@class='sict_open' or @class='sict_closed']/parent::li/ul", event.target);
    if (!ul)
        return;

    if (ul.style.display == "none")
        ul.style.display = "block";
    else {
        ul.style.display = "none";
        toggleClose(event.target);
    }
}



/* For each open comment, a close button is added to the title, the comment is
   wrapped in a div so that it can be hidden, and a closed string is extracted
   from its header and inserted next to it in a hidden state. */

var openComments = xpathCollection("//ul[@id='commentlisting']//li[@class='comment']");
if (log) { 
	internal_log("openComments length is " + openComments.snapshotLength);
}

function nextOpenComment(i, single) {
	if (log) { 
		internal_log("nextOpenComment " + i);
	}
    if (!(i < openComments.snapshotLength))
        return;

    do {

    var comment = openComments.snapshotItem(i);

    var commentTop = xpathNode("(./div | ./div/div)[starts-with(@class,'commentTop')]", comment);
    if (!commentTop) {
		internal_log("commentTop not found " + i);
        continue;
	} else {
		if (log) {
			internal_log("processing commentTop with id " + commentTop.getAttribute('id'));
		}
	}
	
    var commentBody = xpathNode("(./div | ./div/div)[@class='commentBody']", comment);
    if (!commentBody) {
	   	internal_log("commentBody not found " + i);
        continue;
	}

    /* Find the comment cid and set an attribute on its li */

    var commentLink = xpathNode("./div[@class='details']/span[@class='otherdetails']/a[last()]", commentTop);
    if (!commentLink)  {
		internal_log("commentLink not found " + i);
        continue;
	} else {
		if (log) { 
			internal_log("commentLink found " + i);
		}
	}
	
    var cidUrl = commentLink.getAttribute("href");
    try {
        var cid = cidUrl.match(/(cid=|#)(\d+)/)[2];
        comment.setAttribute("sict_cid", cid);
    } catch (e) {
    }


    /* Extract the elements that make up the closed string */

    var title = xpathNode("./div[@class='title']", commentTop);
    if (!title)
        continue;

    var closedTitle = xpathString("string(./h4)", title);
    var closedText = xpathString("normalize-space(./div[@class='details']/text()[1])", commentTop);
    var closedScore = xpathString("normalize-space(./span[@class='score']/text()[1])", title);
    if (closedText.length > 5) // AC
        closedText = closedText.replace(/\s*\(*\s*$/, "").replace(/^(.*?\s+)(on)/, "$1 " + closedScore + " $2");
    else {
        var closedUser = xpathString("normalize-space(substring-before(./div[@class='details']/a[1], '('))", commentTop);
        var closedDate = xpathString("string(preceding-sibling::text()[1])", commentLink);
        try {
            closedDate = closedDate.match(/^\s*[>)]*\s*(on\s*)?(.*?)\s*[<(]*\s*$/)[2];
        } catch (e) {
        }
        closedText += " " + closedUser + " " + closedScore + " " + closedDate;
    }


    /* Extract all elements that make up the opened comment and wrap them in a
       div. The ul element that contains all child posts is not included. */

    var openDiv = divWrap(xpathCollection("./div | ./a | ./text()", comment), "sict_open");
    comment.insertBefore(openDiv, comment.firstChild);


    /* Insert the open and close buttons in front of the comment title */

    openCommentButtons(comment);


    /* Insert an open button in front of a "Read the rest..." link */

    var restLink = xpathNode("./div[@class='commentshrunk']/a", commentBody);
    if (restLink) {
        cidUrl = restLink.getAttribute("href");
        openDiv.setAttribute("sict_rest", "1");
        restLink.parentNode.insertBefore(toggleButton(0, toggleOpenEvent), restLink);
        insertSpace(restLink.parentNode, restLink);
    }

    /* Insert a closed string into the tree.*/

    var closedDiv = document.createElement("div");
    closedDiv.setAttribute("class", "sict_closed");

    var closedLink = document.createElement("a");
    closedLink.setAttribute("href", cidUrl);
    closedLink.appendChild(document.createTextNode(closedTitle));
    closedDiv.appendChild(closedLink);
    closedDiv.appendChild(document.createTextNode(" " + closedText));
    closedDiv.style.display = "none";

    comment.insertBefore(closedDiv, comment.firstChild);


    /* Insert the open and close buttons in front of the closed comment */

    closedCommentButtons(comment);

    } while (0);
    if (!single) {
        var j = 1;
        for (; j < 7; j++)
            nextOpenComment(i + j, true);
        setTimeout(function() { nextOpenComment(i + j); }, 1);
    }
}

nextOpenComment(0);



/* For each closed comment, an open button is added in front of it. */

var closedComments = xpathCollection("//ul[@id='commentlisting']//li[not(@class) and not(ancestor::div[@class='commentBody']) and ./a]");

function nextClosedComment(i, single) {
    if (!(i < closedComments.snapshotLength))
        return;

    do {

    var comment = closedComments.snapshotItem(i);


    /* Find the comment cid and set an attribute on its li */

    var cid;
    try {
        cid = xpathString("./a/@href", comment).match(/(cid=|#)(\d+)/)[2];
    } catch (e) {
        continue;
    }

    comment.setAttribute("sict_cid", cid);


    /* Extract all elements that make up the closed comment and wrap them in a
       div. The ul element that contains all child posts is not included. */

    var closedDiv = divWrap(xpathCollection("./a | ./text()", comment), "sict_closed");
    comment.insertBefore(closedDiv, comment.firstChild);


    /* Insert the open and close buttons in front of the closed comment */

    closedCommentButtons(comment);

    } while (0);
    if (!single) {
        var j = 1;
        for (; j < 7; j++)
            nextClosedComment(i + j, true);
        setTimeout(function() { nextClosedComment(i + j); }, 1);
    }
}

nextClosedComment(0);


})();

// End of file
