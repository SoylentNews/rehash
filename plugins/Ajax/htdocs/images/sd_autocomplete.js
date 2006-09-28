YAHOO.namespace("slashdot");

YAHOO.slashdot.gCompleterWidget = null;

YAHOO.slashdot.actionTags = ["none", "quick", "hold", "back"];
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

    var actionsDS = new YAHOO.widget.DS_JSArray(YAHOO.slashdot.actionTags);
    var sectionsDS = new YAHOO.widget.DS_JSArray(YAHOO.slashdot.sectionTags);
    var topicsDS = sectionsDS;
    var tagsDS = sectionsDS;

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
