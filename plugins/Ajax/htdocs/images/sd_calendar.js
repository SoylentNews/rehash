// _*_ Mode: JavaScript; tab-width: 8; indent-tabs-mode: true _*_
; // $Id$

YAHOO.namespace("slashdot");

function _datesToSelector( selectorFormat, dates ) {
	function format( d ) {
		return selectorFormat(d.getFullYear(), d.getMonth()+1, d.getDate(), d.getDay());
	}

	var s = format(dates[0]);
	if ( dates[1] !== undefined )
		s += "-" + format(dates[1]);
	return s;
}

function _bundleDates( date1, date2 ) {
	if ( date1 instanceof Array )
		return date1;
	else if ( date2 === undefined )
		return [ date1 ];
	else
		return [ date1, date2 ];
}

function datesToHumanReadable( date1, date2 ) {
	var day_name = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];

	function day_ordinal( d ) {
		switch ( d ) {
			case 1: case 21: case 31: return d+"st";
			case 2: case 22:          return d+"nd";
			case 3: case 23:          return d+"rd";
			default:                  return d+"th";
		}
	}


	var month_name = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];

	function minimalHumanReadable( y, m, d, wd ) {
		var now = new Date();
		if ( now.getFullYear() == y ) {
			if ( now.getMonth()+1 == m ) {
			}
		}
	}



	return _datesToSelector(function(y,m,d){return ""+d+" "+month_name[m-1]+" "+y;}, _bundleDates(date1, date2));
}

function datesToYUISelector( date1, date2 ) {
	return _datesToSelector(function(y,m,d){return ""+m+"/"+d+"/"+y;}, _bundleDates(date1, date2));
}

function datesToKinoSelector( date1, date2 ) {
	function formatter( y, m, d ) {
		if ( m < 10 ) m = "0" + m;
		if ( d < 10 ) d = "0" + d;
		return "" + y + m + d;
	}
	return _datesToSelector(formatter, _bundleDates(date1, date2));
}

// Kino format to YUI format: "20070428".replace(/(....)(..)(..)/, "$2/$3/$1")

function weekOf( date ) {
	var dayStart = new Date(datesToYUISelector(date));
	var dayCount = Math.round(dayStart.getTime() / 86400000);
	var weekStart = dayCount - dayStart.getDay() + 1;
	var weekStop = weekStart + 6;
	var startDate = new Date(weekStart * 86400000);
	var endDate = new Date(weekStop * 86400000);
	return [startDate, endDate];
}

var gOpenCalendarPane = null;


YAHOO.slashdot.DateWidget = function( params ) {
	this.init(params);
}

YAHOO.slashdot.DateWidget.prototype.init = function( params ) { // id, mode, date, initCallback
	var peer = null;
	if ( params.peer !== undefined ) {
		peer = document.getElementById(params.peer);
		params.mode = peer._widget._mode;
		params.date = peer._widget.getDate();

		this.subscribeToPeer(peer);
		this._peer = peer;
	}

	this._mode = (params.mode !== undefined) ? params.mode : "now";

	var root = document.getElementById(params.id);
	var find1st = function(name, kind) {
		return YAHOO.util.Dom.getElementsByClassName(name, kind, root)[0];
	}

	var widget = this;

	this._element = root;
	this._dateTab = find1st('date-tab', 'span');
		this._dateTab._widget = this;
	this._label = find1st('day-label', 'option');
	this._calendarPane = find1st('calendar-pane', 'div');
	this.toggleCalendarPane(false);

	this._popup = find1st('date-span-popup', 'select');
		this._popup._widget = this;

	this._calendar = new YAHOO.widget.Calendar(params.id+'-calendar-table', this._calendarPane.id, {maxdate:datesToYUISelector(new Date())});
	this._calendar.selectEvent.subscribe(this.handleCalendarSelect, this, true);

	root._widget = this;
	root.setDate = function(d, m) { widget.setDate(d, m); }
	root.getDateRange = function() { return widget.getDateRange(); }
	root.changeEvent = new YAHOO.util.CustomEvent("change");

	this._muteEvents = 0;

	this.setDate(params.date);

	if ( peer )
		peer._widget.subscribeToPeer(this._element);

	if ( params.init !== undefined )
		params.init(root);
}

function attachDateWidgetTo( params ) {
	return new YAHOO.slashdot.DateWidget(params);
}

YAHOO.slashdot.DateWidget.prototype.muteEvents = function() {
	++this._muteEvents;
}

YAHOO.slashdot.DateWidget.prototype.unmuteEvents = function() {
	--this._muteEvents;
}

YAHOO.slashdot.DateWidget.prototype._reportChanged = function() {
	if ( ! this._muteEvents )
		this._element.changeEvent.fire(this.getDateRange(), this._mode, this.getDate());
}

YAHOO.slashdot.DateWidget.prototype.severPeer = function() {
	if ( this._peer !== undefined ) {
		this._peer._widget.unsubscribeFromPeer(this);
		this.unsubscribeFromPeer(this._peer);
		delete this._peer;
	}
}

YAHOO.slashdot.DateWidget.prototype.subscribeToPeer = function( peer ) {
	peer.changeEvent.subscribe(this.handlePeerChange, this, true);
}

YAHOO.slashdot.DateWidget.prototype.unsubscribeFromPeer = function( peer ) {
	peer.changeEvent.unsubscribe(this.handlePeerChange, this);
}

YAHOO.slashdot.DateWidget.prototype.setMode = function( newMode ) {
	var oldMode = this._mode;
	var modeChanged = (newMode !== undefined) && (newMode != oldMode);
	if ( modeChanged ) {
		if ( newMode == "all" )
			this.toggleCalendarPane(false);
		YAHOO.util.Dom.replaceClass(this._element, oldMode, newMode);
		this._mode = newMode;
		this._popup.value = newMode;
	}

	if ( modeChanged )
		this._reportChanged();

	return modeChanged;
}

YAHOO.slashdot.DateWidget.prototype.setDate = function( date, mode ) {
	this.muteEvents();
		if ( date === undefined )
			date = new Date();
		this._calendar.select(date);
		this._calendar.render();
		var dateChanged = this._setDateFromSelection(date);

		var modeChanged = false;
		if ( mode !== undefined )
			modeChanged = this.setMode(mode);
	this.unmuteEvents();

	if ( dateChanged || modeChanged )
		this._reportChanged();
}

YAHOO.slashdot.DateWidget.prototype._setDateFromSelection = function( date, allowModeChange ) {
	var oldLabel = this._label.innerHTML;
	var newLabel = "Day of " + datesToHumanReadable(date);
	var labelChanged = oldLabel != newLabel;
	if ( labelChanged )
		this._label.innerHTML = newLabel;

	var modeChanged = false;
	if ( allowModeChange==true ) {
		var today = new Date();
		var newMode = ( date.getFullYear() == today.getFullYear()
		             && date.getMonth()    == today.getMonth()
		             && date.getDate()     == today.getDate() ) ? "now" : "day";

		this.muteEvents();
		modeChanged = this.setMode(newMode);
		this.unmuteEvents();
	}

	if ( labelChanged || modeChanged )
		this._reportChanged();

	return labelChanged || modeChanged;
}

YAHOO.slashdot.DateWidget.prototype.getDate = function() {
	return this._calendar.getSelectedDates()[0];
}

YAHOO.slashdot.DateWidget.prototype.getDateRange = function() {
	var range = { duration: -1 };

	var start = null;
	if ( this._mode == "day" ) {
		start = this.getDate();
		range.duration = 1;
	} else if ( this._mode == "now" ) {
		range.duration = 7;
	}

	if ( start !== null )
		range.startdate = datesToKinoSelector(start);

	return range;
}

YAHOO.slashdot.DateWidget.prototype.toggleCalendarPane = function( show ) {
	if ( gOpenCalendarPane !== null && gOpenCalendarPane !== this ) {
		gOpenCalendarPane.toggleCalendarPane(false);
	}
	this._calendarPane.style.display = show ? 'block' : 'none';
	YAHOO.util.Dom[ show ? 'addClass' : 'removeClass' ](this._dateTab, 'active');
	gOpenCalendarPane = show ? this : null;
}

YAHOO.slashdot.DateWidget.prototype.handleDateTabClick = function() {
	this.toggleCalendarPane( ! YAHOO.util.Dom.hasClass(this._dateTab, 'active') );
}

YAHOO.slashdot.DateWidget.prototype.handleCalendarSelect = function( type, args, obj ) {
	this._setDateFromSelection(this._calendar._toDate(args[0][0]), true);
	this.toggleCalendarPane(false);
}

YAHOO.slashdot.DateWidget.prototype.handleRangePopupSelect = function( obj ) {
	this.setMode(obj.value);
}

YAHOO.slashdot.DateWidget.prototype.handlePeerChange = function( type, args, obj ) {
	this.muteEvents();
		this.setDate(args[2], args[1]);
	this.unmuteEvents();
}

;
