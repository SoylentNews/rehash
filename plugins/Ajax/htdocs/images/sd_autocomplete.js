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
    var tagsDS = topicsDS; // until we get a query

YAHOO.slashdot.dataSources = [tagsDS, actionsDS, sectionsDS, topicsDS];


YAHOO.slashdot.AutoCompleteWidget = function()
  {
    this._widget = document.getElementById("ac-select-widget");
    this._spareInput = document.getElementById("ac-select-input");

    this._sourceEl = null;
    this._tagField = null;
  }

YAHOO.slashdot.AutoCompleteWidget.prototype.sourceIsEditableText = function()
  {
    return this._sourceEl && ((this._sourceEl.type == "text") || (this._sourceEl.type == "textarea"));
  }

YAHOO.slashdot.AutoCompleteWidget.prototype.sourceIsStaticText = function()
  {
    return this._sourceEl && (this._sourceEl.type != "text") && (this._sourceEl.type != "textarea");
  }

YAHOO.slashdot.AutoCompleteWidget.prototype._show = function()
  {
    if ( this._sourceEl && YAHOO.util.Dom.hasClass(this._widget, "hidden") )
      {
        YAHOO.util.Dom.removeClass(this._widget, "hidden");
        YAHOO.util.Dom.addClass(this._sourceEl, "ac-source");

        if ( this.sourceIsStaticText() )
          {
            YAHOO.util.Dom.removeClass(this._spareInput, "hidden");
            this._spareInput.value = "";
            this._spareInput.focus();
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
      YAHOO.util.Dom.removeClass(this._sourceEl, "ac-source");
  }

YAHOO.slashdot.AutoCompleteWidget.prototype.attach = function( obj, callbackParams, tagDomain )
  {
    var newSourceEl = obj;
    if ( typeof obj == "string" )
      newSourceEl = document.getElementById(obj);

    if ( this._sourceEl != newSourceEl )
      {
        this._hide();
        this._sourceEl = newSourceEl;
        this.callbackParams = callbackParams;

        var completer = null;
        
        if ( this.sourceIsStaticText() )
          {
            completer = new YAHOO.widget.AutoComplete("ac-select-input", "ac-choices", YAHOO.slashdot.dataSources[tagDomain]);
            completer.minQueryLength = 0;
            completer.typeAhead = true;
            completer.queryDelay = 0;
            completer.autoHighlight = false;
            completer.maxResultsDisplayed = 25;
          }
        else
          {
            completer = new YAHOO.widget.AutoComplete(obj, "ac-choices", YAHOO.slashdot.dataSources[tagDomain]);
            completer.minQueryLength = 1;
            completer.queryDelay = 0.3;
            completer.typeAhead = true;
            completer.queryMatchSubset = true;
            completer.delimChar = " ";
          }
        this.completer = completer;
      }

    if ( this._sourceEl )
      {
        this._show();
        if ( this.sourceIsStaticText() )
          {
            this.completer.itemSelectEvent.subscribe(this._onItemSelectEvent, this);
            this.completer.textboxBlurEvent.subscribe(this._onTextboxBlurEvent, this);
          }
        if ( tagDomain != 0 )
          this.completer._sendQuery("");
      }
  }

YAHOO.slashdot.AutoCompleteWidget.prototype._onItemSelectEvent = function( type, args, me )
  {
    me._hide();
    var tagname = args[2];
    if ( tagname && me._sourceEl )
      {
        me._sourceEl.innerHTML = tagname;
        YAHOO.util.Dom.addClass(me._sourceEl, "not-yet-saved");
      }
    tagsOpenAndEnter(me.callbackParams._id, tagname, me.callbackParams._is_admin, me.callbackParams._type);
    me.completer.itemSelectEvent.unsubscribe(me._onItemSelectEvent, me);
    me.completer.textboxBlurEvent.unsubscribe(me._onTextboxBlurEvent, me);
  }

YAHOO.slashdot.AutoCompleteWidget.prototype._onTextboxBlurEvent = function( type, args, me )
  {
    me._hide()
  }
