// _*_ Mode: JavaScript; tab-width: 8; indent-tabs-mode: true _*_
// $Id$

YAHOO.namespace("slashdot");

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
"scifi",
"communications",
"robotics",
"google",
"it",
"politics",
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

    var feedbackDS = new YAHOO.widget.DS_JSArray(YAHOO.slashdot.feedbackTags);
    var actionsDS = new YAHOO.widget.DS_JSArray(YAHOO.slashdot.actionTags);
    var sectionsDS = new YAHOO.widget.DS_JSArray(YAHOO.slashdot.sectionTags);
    var topicsDS = new YAHOO.widget.DS_JSArray(YAHOO.slashdot.topicTags);

    var tagsDS = new YAHOO.widget.DS_XHR("./ajax.pl", ["\n", "\t"]);
    // tagsDS.maxCacheEntries = 0; // turn off local cacheing, because Jamie says the query is fast
    tagsDS.queryMatchSubset = false;
    tagsDS.responseType = tagsDS.TYPE_FLAT;
    tagsDS.scriptQueryParam = "prefix";
    tagsDS.scriptQueryAppend = "op=tags_list_tagnames";
    tagsDS.queryMethod = "POST";

YAHOO.slashdot.dataSources = [tagsDS, actionsDS, sectionsDS, topicsDS, feedbackDS];


YAHOO.slashdot.AutoCompleteWidget = function()
  {
    this._widget = document.getElementById("ac-select-widget");
    this._spareInput = document.getElementById("ac-select-input");

    this._sourceEl = null;
    this._denyNextAttachTo = null;

    YAHOO.util.Event.addListener(document.body, "click", this._onClick, this, true);
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

          // hack? -- override YUI's private member function so that for top tags auto-complete, right arrow means select
        c._jumpSelection = function() { if ( this._oCurItem ) this._selectItem(this._oCurItem); };
      }
    else
      {
        c = new YAHOO.widget.AutoComplete(this._sourceEl, "ac-choices", YAHOO.slashdot.dataSources[tagDomain]);
        c.delimChar = " ";
        c.minQueryLength = 3;
      }
    c.typeAhead = true;
    c.forceSelection = false;
    c.allowBrowserAutocomplete = false;
    c.maxResultsDisplayed = 25;

    return c;
  }

YAHOO.slashdot.AutoCompleteWidget.prototype._show = function( obj, callbackParams, tagDomain )
  {
    this._sourceEl = obj;

    if ( this._sourceEl )
      {
        this._callbackParams = callbackParams;
        this._callbackParams._tagDomain = tagDomain;
        this._completer = this._newCompleter(tagDomain);

        var pos = YAHOO.util.Dom.getXY(this._sourceEl);
        pos[1] += this._sourceEl.offsetHeight;
        YAHOO.util.Dom.setXY(this._widget, pos);

        YAHOO.util.Dom.addClass(this._sourceEl, "ac-source");
        YAHOO.util.Dom.removeClass(this._widget, "hidden");

        if ( this._needsSpareInput() )
          {
            YAHOO.util.Dom.removeClass(this._spareInput, "hidden");
            this._spareInput.value = "";
            this._spareInput.focus();

            this._completer.itemSelectEvent.subscribe(this._onItemSelectEvent, this);
            this._completer.textboxBlurEvent.subscribe(this._onTextboxBlurEvent, this);
          }
        else
          YAHOO.util.Dom.addClass(this._spareInput, "hidden");

        YAHOO.util.Event.addListener(this._textField(), "keyup", this._onTextboxKeyUp, this, true);
      }
  }

YAHOO.slashdot.AutoCompleteWidget.prototype._hide = function()
  {
    YAHOO.util.Dom.addClass(this._widget, "hidden");
    YAHOO.util.Dom.addClass(this._spareInput, "hidden");
    if ( this._sourceEl )
      {
        YAHOO.util.Dom.removeClass(this._sourceEl, "ac-source");

        YAHOO.util.Event.removeListener(this._textField(), "keyup", this._onTextboxKeyUp, this, true);
        if ( this._needsSpareInput() )
          {
            this._completer.itemSelectEvent.unsubscribe(this._onItemSelectEvent, this);
            this._completer.textboxBlurEvent.unsubscribe(this._onTextboxBlurEvent, this);
          }

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
        this._show(newSourceEl, callbackParams, tagDomain);
        if ( tagDomain != 0 )
          {
            var temp = this._completer.minQueryLength;
            this._completer.minQueryLength = 0;
            this._completer._sendQuery("");
            this._completer.minQueryLength = temp;
          }
          
      }
  }

YAHOO.slashdot.AutoCompleteWidget.prototype._onClick = function( e, me )
  {
      // if the user re-clicked the item to which I'm attached, then they mean to hide me
      //  I'm going to hide automatically, because a click outside the text will blur, and that makes me go away
      //  but I need to remember _not_ to let the current click re-show me
    var reclicked = me._sourceEl && YAHOO.util.Event.getTarget(e, true) == me._sourceEl;
    me._denyNextAttachTo = reclicked ? me._sourceEl : null;
  }

YAHOO.slashdot.AutoCompleteWidget.prototype._onItemSelectEvent = function( type, args, me )
  {
    var tagname = args[2];
    var p = me._callbackParams;

	// only change the 'menu' title when that title is a tag you are replacing
    if ( tagname && me._needsSpareInput() && p._tagDomain != 4 )
      {
        me._sourceEl.innerHTML = tagname;
      }
    me._hide();

      // really need to move this into a separate function...
      //  at least when there is more than just p._type=='firehose'
    if ( p._tagDomain != 0 )
      {
          // save the new tag immediately
	createTag(tagname, p._id, p._type);

          // and if the user tags field exists, add it there (but don't show or hide the field)
        var tagField = document.getElementById('newtags-' + p._id);
        if ( tagField )
          {
	    var s = tagField.value.slice(-1);
            if ( s.length && s != " " )
              tagField.value += " ";
            tagField.value += tagname;
          }
      }
  }

YAHOO.slashdot.AutoCompleteWidget.prototype._onTextboxBlurEvent = function( type, args, me )
  {
    var o = me._denyNextAttachTo;
    me._hide();
    me._denyNextAttachTo = o;
  }

YAHOO.slashdot.AutoCompleteWidget.prototype._onTextboxKeyUp = function( e, me )
  {
    switch ( e.keyCode )
      {
        case 27: // esc
        // any other keys?...
          me._hide();
      }
  }
