// _*_ Mode: JavaScript; tab-width: 8; indent-tabs-mode: true _*_
// $Id$

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


YAHOO.slashdot.DateWidget = function( params ) { // id, mode, date, initCallback
  if ( params.master !== undefined ) {
    var master = document.getElementById(params.master)._widget;
    params.mode = master._mode;
    params.date = master.getDate();
    // also need to listen to master events
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
  this._label = find1st('tab-label', 'span');
  this._calendarPane = find1st('calendar-pane', 'div');
  this.toggleCalendarPane(false);

  this._popup = find1st('date-span-popup', 'select');
    this._popup._widget = this;

  this._calendar = new YAHOO.widget.Calendar(params.id+'-calendar-table', this._calendarPane.id, {maxdate:datesToYUISelector(new Date())});
  this._calendar.selectEvent.subscribe(this.handleCalendarSelect, this, true);

  root._widget = this;
  root.setDate = function(d, m) { widget.setDate(d, m); }
  root.getDateRange = function() { return widget.getDateRange(); }
  root.selectEvent = new YAHOO.util.CustomEvent("select");

  this.setDate(params.date);

  if ( params.init !== undefined )
    params.init(root);
}

function attachDateWidgetTo( params ) {
  return new YAHOO.slashdot.DateWidget(params);
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
  return modeChanged;
}

YAHOO.slashdot.DateWidget.prototype.setDate = function( date, mode ) {
  if ( mode !== undefined )
    this.setMode(mode);
  if ( date === undefined )
    date = new Date();
  this._calendar.select(date);
  this._calendar.render();
}

YAHOO.slashdot.DateWidget.prototype._setDateFromSelection = function( date ) {
  this._label.innerHTML = datesToHumanReadable(date);
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
  this._setDateFromSelection(this._calendar._toDate(args[0][0]));
  this._element.selectEvent.fire(this.getDateRange());
}

YAHOO.slashdot.DateWidget.prototype.handleRangePopupSelect = function( obj ) {
  if ( this.setMode(obj.value) )
    this._element.selectEvent.fire(this.getDateRange());
}

