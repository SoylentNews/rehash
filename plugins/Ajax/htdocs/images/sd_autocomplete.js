// _*_ Mode: JavaScript; tab-width: 8; indent-tabs-mode: true _*_
// $Id$

YAHOO.namespace("slashdot");

YAHOO.slashdot.DS_JSArray = function(aData, oConfigs)
  {
    if ( typeof oConfigs == "object" )
      for ( var sConfig in oConfigs )
        this[sConfig] = oConfigs[sConfig];

    if ( !aData || (aData.constructor != Array) )
      return

    this.data = aData;
    this._init();
  }

YAHOO.slashdot.DS_JSArray.prototype = new YAHOO.widget.DataSource();

YAHOO.slashdot.DS_JSArray.prototype.data = null;

YAHOO.slashdot.DS_JSArray.prototype.doQuery = function(oCallbackFn, sQuery, oParent) {
    var aData = this.data; // the array
    var aResults = []; // container for results
    var bMatchFound = false;
    var bMatchContains = this.queryMatchContains;

    if(sQuery && !this.queryMatchCase) {
        sQuery = sQuery.toLowerCase();
    }

    // Loop through each element of the array...
    // which can be a string or an array of strings
    for(var i = aData.length-1; i >= 0; i--) {
        var aDataset = [];

        if(aData[i]) {
            if(aData[i].constructor == String) {
                aDataset[0] = aData[i];
            }
            else if(aData[i].constructor == Array) {
                aDataset = aData[i];
            }
        }

        if(aDataset[0] && (aDataset[0].constructor == String)) {
            var sKeyIndex = 0;
            if (sQuery) {
              sKeyIndex = (this.queryMatchCase) ?
                encodeURIComponent(aDataset[0]).indexOf(sQuery):
                encodeURIComponent(aDataset[0]).toLowerCase().indexOf(sQuery);
            }

            // A STARTSWITH match is when the query is found at the beginning of the key string...
            if((!bMatchContains && (sKeyIndex === 0)) ||
            // A CONTAINS match is when the query is found anywhere within the key string...
            (bMatchContains && (sKeyIndex > -1))) {
                // Stash a match into aResults[].
                aResults.unshift(aDataset);
            }
        }
    }

    this.getResultsEvent.fire(this, oParent, sQuery, aResults);
    oCallbackFn(sQuery, aResults, oParent);
};


YAHOO.slashdot.gCompleterWidget = null;

YAHOO.slashdot.feedbackTags = ["dupe", "typo", "error"];
YAHOO.slashdot.actionTags = ["none", "quik", "hold", "back"];
YAHOO.slashdot.sectionTags = [ "apache",
"apple",
"askslashdot",
"awards",
"backslash",
"books",
"bsd",
"developers",
"features",
"games",
"hardware",
"interviews",
"it",
"linux",
"mainpage",
"politics",
"polls",
"radio",
"science",
"search",
"tacohell",
"vendors",
"vendor_amd",
"yro" ];

YAHOO.slashdot.topicTags = ["keyword",
"mainpage",
"apache",
"apple",
"askslashdot",
"awards",
"books",
"bsd",
"developers",
"features",
"games",
"interviews",
"polls",
"radio",
"science",
"search",
"tacohell",
"yro",
"be",
"caldera",
"comdex",
"debian",
"digital",
"gimp",
"encryption",
"gnustep",
"internet",
"links",
"movies",
"money",
"news",
"pilot",
"starwars",
"sun",
"usa",
"x",
"xmas",
"linux",
"java",
"microsoft",
"redhat",
"spam",
"quake",
"ie",
"netscape",
"enlightenment",
"cda",
"gnu",
"intel",
"eplus",
"aol",
"kde",
"doj",
"slashdot",
"wine",
"tech",
"bug",
"tv",
"unix",
"gnome",
"corel",
"humor",
"ibm",
"hardware",
"amiga",
"sgi",
"compaq",
"music",
"amd",
"suse",
"quickies",
"perl",
"ed",
"mandrake",
"media",
"va",
"linuxcare",
"graphics",
"censorship",
"mozilla",
"patents",
"programming",
"privacy",
"toys",
"space",
"transmeta",
"announce",
"linuxbiz",
"upgrades",
"turbolinux",
"editorial",
"slashback",
"anime",
"php",
"ximian",
"journal",
"security",
"hp",
"desktops",
"imac",
"media",
"networking",
"osnine",
"osx",
"portables",
"technology",
"utilities",
"wireless",
"portables",
"software",
"ent",
"biz",
"media",
"gui",
"os",
"biotech",
"books",
"wireless",
"printers",
"displays",
"storage",
"lotr",
"matrix",
"windows",
"classic",
"emulation",
"fps",
"nes",
"pcgames",
"portablegames",
"puzzlegames",
"rpg",
"rts",
"xbox",
"ps2",
"gamecube",
"wii",
"scifi",
"communications",
"robotics",
"google",
"it",
"politics",
"military",
"worms",
"databases",
"hardhack",
"novell",
"republicans",
"democrats",
"mars",
"inputdev",
"math",
"moon",
"networking",
"supercomputing",
"power",
"sony",
"nintendo",
"e3",
"nasa",
"yahoo",
"vendors",
"vendor_amd",
"vendor_amd_64chip",
"vendor_amd_announce",
"vendor_amd_ask",
"vendor_amd_64fx",
"vendor_amd_laptops",
"vendor_amd_multicore",
"vendor_amd_ostg",
"backslash" ];

YAHOO.slashdot.fhitemOpts = [
"hold",
"back",
"quik",
"typo",
"dupe"
];

YAHOO.slashdot.storyOpts = [
"neverdisplay"
];

    var feedbackDS = new YAHOO.slashdot.DS_JSArray(YAHOO.slashdot.feedbackTags);
    var actionsDS = new YAHOO.slashdot.DS_JSArray(YAHOO.slashdot.actionTags);
    var sectionsDS = new YAHOO.slashdot.DS_JSArray(YAHOO.slashdot.sectionTags);
    var topicsDS = new YAHOO.slashdot.DS_JSArray(YAHOO.slashdot.topicTags);
    var fhitemDS = new YAHOO.slashdot.DS_JSArray(YAHOO.slashdot.fhitemOpts);
    var storyDS = new YAHOO.slashdot.DS_JSArray(YAHOO.slashdot.storyOpts);

    var tagsDS = new YAHOO.widget.DS_XHR("./ajax.pl", ["\n", "\t"]);
    // tagsDS.maxCacheEntries = 0; // turn off local cacheing, because Jamie says the query is fast
    tagsDS.queryMatchSubset = false;
    tagsDS.responseType = YAHOO.widget.DS_XHR.TYPE_FLAT;
    tagsDS.scriptQueryParam = "prefix";
    tagsDS.scriptQueryAppend = "op=tags_list_tagnames";
    tagsDS.queryMethod = "POST";

    var fhtabsDS = new YAHOO.widget.DS_XHR("./ajax.pl", ["\n", "\t"]);
    fhtabsDS.queryMatchSubset = false;
    fhtabsDS.responseType = YAHOO.widget.DS_XHR.TYPE_FLAT;
    fhtabsDS.scriptQueryParam = "prefix";
    fhtabsDS.scriptQueryAppend = "op=firehose_list_tabs";
    fhtabsDS.queryMethod = "POST";

YAHOO.slashdot.dataSources = [tagsDS, actionsDS, sectionsDS, topicsDS, feedbackDS, storyDS, fhitemDS, fhtabsDS ];

YAHOO.slashdot.AutoCompleteWidget = function()
  {
    this._widget = document.getElementById("ac-select-widget");
    this._spareInput = document.getElementById("ac-select-input");

    this._sourceEl = null;
    this._denyNextAttachTo = null;

    YAHOO.util.Event.addListener(document.body, "click", this._onSdClick, this, true);
    // add body/window blur to detect changing windows?
  }

YAHOO.slashdot.AutoCompleteWidget.prototype._textField = function()
  {
    if ( this._sourceEl==null || this._sourceEl.type=='text' || this._sourceEl.type=='textarea' )
      return this._sourceEl;

    return this._spareInput;
  }

YAHOO.slashdot.AutoCompleteWidget.prototype._needsSpareInput = function()
  {
    // return this._textField() == this._spareInput;
    return this._sourceEl && (this._sourceEl.type != "text") && (this._sourceEl.type != "textarea");
  }

YAHOO.slashdot.AutoCompleteWidget.prototype._newCompleter = function( tagDomain )
  {
    var c = null;
    if ( this._needsSpareInput() )
      {
        c = new YAHOO.widget.AutoComplete("ac-select-input", "ac-choices", YAHOO.slashdot.dataSources[tagDomain]);
        c.minQueryLength = 0;

          // hack? -- override YUI's private member function so that for top tags auto-complete, right arrow means select
        c._jumpSelection = function() { if ( this._oCurItem ) this._selectItem(this._oCurItem); };
      }
    else
      {
        c = new YAHOO.widget.AutoComplete(this._sourceEl, "ac-choices", YAHOO.slashdot.dataSources[tagDomain]);
        c.delimChar = " ";
        c.minQueryLength = 3;
      }
    c.typeAhead = false;
    c.forceSelection = false;
    c.allowBrowserAutocomplete = false;
    c.maxResultsDisplayed = 25;
    c.animVert = false;

    return c;
  }

YAHOO.slashdot.AutoCompleteWidget.prototype._show = function( obj, callbackParams, tagDomain )
  {
      // onTextboxBlur should have already hidden the previous instance (if any), but if events
      //  come out of order, we must hide now to prevent broken listeners
    if ( this._sourceEl )
      this._hide();

    this._sourceEl = obj;

    if ( this._sourceEl )
      {
        this._callbackParams = callbackParams;
        this._callbackParams._tagDomain = tagDomain;
        this._completer = this._newCompleter(tagDomain);
        
        if ( typeof callbackParams.yui == "object" )
          for ( var field in callbackParams.yui )
            this._completer[field] = callbackParams.yui[field];

        if ( callbackParams.delayAutoHighlight )
          this._completer.autoHighlight = false;
          

	  // widget must be visible to move
        YAHOO.util.Dom.removeClass(this._widget, "hidden");
	  // move widget to be near the 'source'
        var pos = YAHOO.util.Dom.getXY(this._sourceEl);
        pos[1] += this._sourceEl.offsetHeight;
        YAHOO.util.Dom.setXY(this._widget, pos);

        YAHOO.util.Dom.addClass(this._sourceEl, "ac-source");

        if ( this._needsSpareInput() )
          {
            YAHOO.util.Dom.removeClass(this._spareInput, "hidden");
            this._spareInput.value = "";
            this._spareInput.focus();
          }
        else
          YAHOO.util.Dom.addClass(this._spareInput, "hidden");

        this._completer.itemSelectEvent.subscribe(this._onSdItemSelectEvent, this);
        this._completer.unmatchedItemSelectEvent.subscribe(this._onSdItemSelectEvent, this);
        this._completer.textboxBlurEvent.subscribe(this._onSdTextboxBlurEvent, this);

        YAHOO.util.Event.addListener(this._textField(), "keyup", this._onSdTextboxKeyUp, this, true);

        this._pending_hide = setTimeout("YAHOO.slashdot.gCompleterWidget._hide()", 15000);
      }
  }

YAHOO.slashdot.AutoCompleteWidget.prototype._hide = function()
  {
    if ( this._pending_hide )
      {
        clearTimeout(this._pending_hide);
        this._pending_hide = null;
      }

    YAHOO.util.Dom.addClass(this._widget, "hidden");
    YAHOO.util.Dom.addClass(this._spareInput, "hidden");
    if ( this._sourceEl )
      {
        YAHOO.util.Dom.removeClass(this._sourceEl, "ac-source");

        YAHOO.util.Event.removeListener(this._textField(), "keyup", this._onSdTextboxKeyUp, this, true);
        this._completer.itemSelectEvent.unsubscribe(this._onSdItemSelectEvent, this);
        this._completer.unmatchedItemSelectEvent.unsubscribe(this._onSdItemSelectEvent, this);
        this._completer.textboxBlurEvent.unsubscribe(this._onSdTextboxBlurEvent, this);

        this._sourceEl = null;
        this._callbackParams = null;
        this._completer = null;
      }

    this._denyNextAttachTo = null;
  }

YAHOO.slashdot.AutoCompleteWidget.prototype.attach = function( obj, callbackParams, tagDomain )
  {
    var newSourceEl = obj;
    if ( typeof obj == "string" )
      newSourceEl = document.getElementById(obj);

      // act like a menu: if we click on the same trigger while visible, hide
    var denyThisAttach = this._denyNextAttachTo == newSourceEl;
    this._denyNextAttachTo = null;
    if ( denyThisAttach )
      return;

    if ( newSourceEl )
      {
        callbackParams._sourceEl = newSourceEl;
        this._show(newSourceEl, callbackParams, tagDomain);

        var q = callbackParams.queryOnAttach;
        if ( q )
          this._completer.sendQuery((typeof q == "string") ? q : "");
      }
  }

YAHOO.slashdot.AutoCompleteWidget.prototype._onSdClick = function( e, me )
  {
      // if the user re-clicked the item to which I'm attached, then they mean to hide me
      //  I'm going to hide automatically, because a click outside the text will blur, and that makes me go away
      //  but I need to remember _not_ to let the current click re-show me
    var reclicked = me._sourceEl && YAHOO.util.Event.getTarget(e, true) == me._sourceEl;
    me._denyNextAttachTo = reclicked ? me._sourceEl : null;
  }

YAHOO.slashdot.AutoCompleteWidget.prototype._onSdItemSelectEvent = function( type, args, me )
  {
    var tagname = args[2];
    if ( tagname !== undefined && tagname !== null ) {
      if ( typeof tagname != 'string' )
        tagname = tagname[0];

      var p = me._callbackParams;
      if ( p.action0 !== undefined )
        p.action0(tagname, p);
      me._hide();
      if ( p.action1 !== undefined )
        p.action1(tagname, p);

    } else {
      me._hide();
    }
  }

YAHOO.slashdot.AutoCompleteWidget.prototype._onSdTextboxBlurEvent = function( type, args, me )
  {
    var o = me._denyNextAttachTo;
    me._hide();
    me._denyNextAttachTo = o;
  }

YAHOO.slashdot.AutoCompleteWidget.prototype._onSdTextboxKeyUp = function( e, me )
  {
    if ( me._callbackParams && me._callbackParams.delayAutoHighlight )
      {
        me._callbackParams.delayAutoHighlight = false;
        me._completer.autoHighlight = true;
      }

    switch ( e.keyCode )
      {
        case 27: // esc
        // any other keys?...
          me._hide();
          break;
        case 13:
        	// I'm sorry to say we have to test first, something somehow somewhere can still leave
        	//	leave this listener dangling; want to look deeper into this, as this would _still_
        	//	leave the listener dangling
        	if ( me._completer )
          	me._completer.unmatchedItemSelectEvent.fire(me._completer, me, me._completer._sCurQuery);
          break;
        default:
          if ( me._pending_hide )
            clearTimeout(me._pending_hide);
          me._pending_hide = setTimeout("YAHOO.slashdot.gCompleterWidget._hide()", 15000);
      }
  }
