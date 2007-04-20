// _*_ Mode: JavaScript; tab-width: 8; indent-tabs-mode: true _*_
// $Id$

YAHOO.namespace("slashdot");

function _datesToSelector( selectorFormat, dates ) {
  function format( d ) {
    return selectorFormat(d.getFullYear(), d.getMonth()+1, d.getDate());
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
  var month_name = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
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


YAHOO.slashdot.DateWidget = function( id, mode, date ) {
  if ( date === undefined )
    date = new Date;

  this._date = date;
  this._mode = mode;

  var root = document.getElementById(id);
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

  var popup = find1st('date-span-popup', 'select');
    popup._widget = this;

  this._calendar = new YAHOO.widget.Calendar(id+'-calendar-table', this._calendarPane.id, {maxdate:datesToYUISelector(new Date())});
  this._calendar.selectEvent.subscribe(this.handleCalendarSelect, this, true);

  root._widget = this;
  root.setDate = function(d) { widget.setDate(d); }
  root.getDateRange = function() { return widget.getDateRange(); }

  this.setDate(date);
}

function attachDateWidgetTo( id, date ) {
  return new YAHOO.slashdot.DateWidget(id, date);
}

YAHOO.slashdot.DateWidget.prototype.setDate = function( date ) {
  this._calendar.select(date);
}

YAHOO.slashdot.DateWidget.prototype._setDateFromSelection = function( date ) {
  this._date = date;
  this._label.innerHTML = datesToHumanReadable(date);
  this.updateWeekHighlight();
}

YAHOO.slashdot.DateWidget.prototype.getDate = function() {
  return this._date;
}

YAHOO.slashdot.DateWidget.prototype.getDateRange = function() {
  var range = new Object;
  var start = null;
  if ( this._mode == "since" )
    start = this._date;
  else if ( this._mode == "day" ) {
    start = this._date;
    range.duration = 1;
  } else if ( this._mode == "week" ) {
    start = weekOf(this._date)[0];
    range.duration = 7;
  }

  if ( start !== null )
    range.start = datesToKinoSelector(start);

  return range;
}

YAHOO.slashdot.DateWidget.prototype.updateWeekHighlight = function( date ) {
  var C = this._calendar;
  var rendered = false;
  // if ( weekSelected ) {
    C.resetRenderers();
    C.clearAllBodyCellStyles("highlight1");
    C.render();
    rendered = true;
  //  weekSelected = false;
  //}

  if ( this._mode == "week" ) {
    if ( date === undefined )
      date = this.getDate();
  
    C.addRenderer(datesToYUISelector(weekOf(date)), C.renderCellStyleHighlight1);
    C.render();
    rendered = true;
    //weekSelected = true;
  }

  if ( !rendered )
    C.render();
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
}

YAHOO.slashdot.DateWidget.prototype.handleRangePopupSelect = function( obj ) {
  var oldMode = this._mode;
  var newMode = obj.value;
  if ( newMode != oldMode ) {
    if ( newMode == "all" )
      this.toggleCalendarPane(false);
    YAHOO.util.Dom.replaceClass(this._element, oldMode, newMode);
    this._mode = newMode;
    if ( oldMode == "week" || newMode == "week" )
      this.updateWeekHighlight();
  }
}

