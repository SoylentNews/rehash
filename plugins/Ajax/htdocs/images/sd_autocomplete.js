/* _*_ Mode: JavaScript; tab-width: 8; indent-tabs-mode: true _*_ */

YAHOO.namespace("slashdot");

YAHOO.slashdot.gCompleterWidget = null;

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

    var actionsDS = new YAHOO.widget.DS_JSArray(YAHOO.slashdot.actionTags);
    var sectionsDS = new YAHOO.widget.DS_JSArray(YAHOO.slashdot.sectionTags);
    var topicsDS = new YAHOO.widget.DS_JSArray(YAHOO.slashdot.topicTags);

    var tagsDS = new YAHOO.widget.DS_XHR("./ajax.pl", ["\n", "\t"]);
    tagsDS.responseType = tagsDS.TYPE_FLAT;
    tagsDS.scriptQueryParam = "prefix";
    tagsDS.scriptQueryAppend = "op=tags_list_tagnames";
    tagsDS.queryMethod = "POST";

YAHOO.slashdot.dataSources = [tagsDS, actionsDS, sectionsDS, topicsDS];


YAHOO.slashdot.AutoCompleteWidget = function()
  {
    this._widget = document.getElementById("ac-select-widget");
    this._spareInput = document.getElementById("ac-select-input");

    this._sourceEl = null;
    this._denyNextAttachTo = null;

    YAHOO.util.Event.addListener(document.body, "click", this._onClick, this, true);
    // add body/window blur to detect changing windows?
  }

YAHOO.slashdot.AutoCompleteWidget.prototype._needsSpareInput = function()
  {
    return this._sourceEl && (this._sourceEl.type != "text") && (this._sourceEl.type != "textarea");
  }

YAHOO.slashdot.AutoCompleteWidget.prototype._newCompleter = function( tagDomain )
  {
    var c = null;
    if ( this._needsSpareInput() )
      {
        c = new YAHOO.widget.AutoComplete("ac-select-input", "ac-choices", YAHOO.slashdot.dataSources[tagDomain]);
        c.minQueryLength = 0;
        c.queryDelay = 0;
        c.typeAhead = true;
        c.autoHighlight = false;
        c.maxResultsDisplayed = 25;
      }
    else
      {
        c = new YAHOO.widget.AutoComplete(this._sourceEl, "ac-choices", YAHOO.slashdot.dataSources[tagDomain]);
        c.minQueryLength = 1;
        c.queryDelay = 0.3;
        c.typeAhead = true;
        c.queryMatchSubset = true;
        c.delimChar = " ";
      }
    return c;
  }

YAHOO.slashdot.AutoCompleteWidget.prototype._show = function( obj, callbackParams, tagDomain )
  {
    this._sourceEl = obj;
    this._callbackParams = callbackParams;
    this._callbackParams._tagDomain = tagDomain;
    this._completer = this._newCompleter(tagDomain);

    if ( this._sourceEl && YAHOO.util.Dom.hasClass(this._widget, "hidden") )
      {
        YAHOO.util.Dom.removeClass(this._widget, "hidden");
        YAHOO.util.Dom.addClass(this._sourceEl, "ac-source");

        if ( this._needsSpareInput() )
          {
            YAHOO.util.Dom.removeClass(this._spareInput, "hidden");
            this._spareInput.value = "";
            this._spareInput.focus();

            this._completer.itemSelectEvent.subscribe(this._onItemSelectEvent, this);
            this._completer.textboxBlurEvent.subscribe(this._onTextboxBlurEvent, this);
            YAHOO.util.Event.addListener(this._spareInput, "keyup", this._onTextboxKeyUp, this, true);
          }
        else
          YAHOO.util.Dom.addClass(this._spareInput, "hidden");

        var pos = YAHOO.util.Dom.getXY(this._sourceEl);
        pos[1] += this._sourceEl.offsetHeight;
        YAHOO.util.Dom.setXY(this._widget, pos);
      }
  }

YAHOO.slashdot.AutoCompleteWidget.prototype._hide = function()
  {
    YAHOO.util.Dom.addClass(this._widget, "hidden");
    YAHOO.util.Dom.addClass(this._spareInput, "hidden");
    if ( this._sourceEl )
      {
        YAHOO.util.Dom.removeClass(this._sourceEl, "ac-source");
        if ( this._needsSpareInput() )
          {
            this._completer.itemSelectEvent.unsubscribe(this._onItemSelectEvent, this);
            this._completer.textboxBlurEvent.unsubscribe(this._onTextboxBlurEvent, this);
            YAHOO.util.Event.removeListener(this._spareInput, "keyup", this._onTextboxKeyUp, this, true);
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
          this._completer._sendQuery("");
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
    if ( tagname && me._sourceEl )
      {
        me._sourceEl.innerHTML = tagname;
        // YAHOO.util.Dom.addClass(me._sourceEl, "not-yet-saved");
      }
    var p = me._callbackParams;
    me._hide();

      // really need to move this into a separate function...
      //  at least when there is more than just p._type=='firehose'
    if ( p._type == "firehose" && p._tagDomain != 0 )
      {
          // save the new tag immediately
        setOneTopTagForFirehose(p._id, tagname);

          // and if the user tags field exists, add it there (but don't show or hide the field)
        var tagField = document.getElementById('tags-user-' + p._id);
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
