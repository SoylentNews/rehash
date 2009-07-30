// slash.menu.js

;(function($){

$.widget("slash.menu", $.extend({}, $.ui.mouse, {

/* Events:
	start	ui => { over:item }
	over	ui => { over:new_item, out:old_item }
	select	ui => { select:selected_item, out:selected_item }
	out	ui => { over:new_item, out:old_item }, or else { select:selected_item, out:selected_item }
	stop	ui => { select:selected_item, out:selected_item }

Additionally, ui always includes { trigger:el }
*/

_init: function(){			// called for $(...).menu()
	// Called once per menu "installation" in an item.

	this._mouseInit();
	this.triggers = $(this.options.triggers||[]);

	// Rewire bindings: mousedown goes to _me_ instead of to ui.mouse.
	this.element.unbind('mousedown.'+this.widgetName); // bound by ui.mouse._mouseInit
	var self = this;
	this.triggers.
		bind('mousedown.'+this.widgetName, function( e ){
			return self._menuMouseDown(e, { trigger: this });
		}).
		bind('click.'+this.widgetName, function( e ){
		});

	(this.options.cssNamespace && (this._hoverClass=this.options.cssNamespace + '-hover'));
	this._mouseStarted = false;
},

context: function( e, trigger ){
	return this._menuMouseDown(e, { trigger: trigger });
},

destroy: function(){			// called for $(...).menu('destroy|remove')
	if ( this.element.data('menu') ) {
		this.element.removeData('menu').unbind('.menu');
		this._mouseDestroy();
	}
},

tracking: function( action, e, ui ){	// called for $(...).menu('enable|disable|toggle'), and internally

	// Typically called once to enable tracking when a single "use" of a menu
	// begins; and again when that use ends, to disable tracking.

	// When "tracking": out, over, and select events are triggered; items and the
	// menu itself are highlighted accordingly.  Tracking is first enabled in
	// _mouseCapture, or else by client code.  Tracking is disabled as a final step
	// in _mouseStop, triggering a final 'out' and unhighlighting a selected item.

	// mouseenter/mouseleave are always captured and cache the last "over" item so
	// that a call to tracking can trigger the correct out/over, even when no event
	// is available to tell us the item.

	var track = {
		'begin':	true,
		'disable':	false,
		'enable':	true,
		'end':		false,
		'start':	true,
		'stop':		false,
		'toggle':	!this._tracking
	}[action];

	if ( track === undefined ) {
		// The error case: no-op

	} else if ( !track && (this._tracking===undefined) ) {
		// The expected case: client disables tracking from 'start' (before we've enabled it).
		this._tracking = false;

	} else if ( track != (this._tracking||false) ) {
		// The general case: off=>on, on=>off
		var ui_for_event = track ? 'mouseenter' : 'mouseleave';
		(ui || (ui=this._uiHash(e, ui_for_event)));

		// A change in tracking...
		(this._tracking && this._item('out', e, ui)); // ...triggers 'out', before tracking is disabled;
		this._tracking = track;
		(this._tracking && this._item('over', e, ui)); // ...triggers 'over', after tracking is enabled.
	}
},


_mouseCapture: function( e ){
	// ...my "menuStart".  Called once per menu "use", beginning that use.

	// Start a timer to distinguish between a click and a press.
	this.clickDurationExceded = (this.options.clickDuration||0)<=0;
	if ( !this.clickDurationExceded ) {
		var self = this;
		this._clickDurationTimer = setTimeout(function(){
			self.clickDurationExceded = true;
			self._mouseStart(e);
		}, this.options.clickDuration);
	}

	this._overTarget = this._tracking = undefined;
	this._hoverStarted = false;
	this._menuStarted = (this.options.clickToHover && this._mouseStart(e));

	// Tell ui.mouse: "Yes, start us up."
	return true;
},

_mouseStart: function( e ){
	if ( !this._menuStarted ) {
		var ui = this._uiHash(e);

		this._trigger('start', e, ui); // Hey, client-code!  Open the menu!
		// If client start _didn't_ enable/disable tracking, this._tracking remains undefined.
		((this._tracking===undefined) && this.tracking('start', e, ui));

		// Track mouse movement over the actual menu items (thank you jQuery!).
		var self = this;
		this.element.children().
			bind('mouseleave.'+this.widgetName, function(e){ return self._item('out', e); }).
			bind('mouseenter.'+this.widgetName, function(e){ return self._item('over', e); });

		this._menuStarted = true;
	}
	return this._menuStarted;
},

_item: function( action, e, ui ){
	// Do everything needed when leaving an item or entering a new one
	// (manage highlighting, and trigger the over/out events that run client
	// code).  This function is bound to mouseenter/mouseleave, and will be
	// called more often than any other top-level menu function.

	// Even when tracking is disabled, cache the current mouseover item; we'll need it
	// for an 'over' (and won't have an event to supply it) in case $(...).menu('tracking', 'enable')
	(ui || (ui=this._uiHash(e)));
	(e && (this._overTarget=ui.over));

	// Nothing else to worry about unless tracking is enabled and we actually have an item.
	if ( ui[action] && this._tracking ) {
		// Order matters (to me, anyway); so, if highlighting is...
		// ...to be removed, do so _before_ triggering client code
		((action==='out') && this._highlight(action, e, ui));
		this._trigger(action, e, ui); // Hey, client-code!
		// ...to be applied, do so only _after_ triggering client code
		((action==='over') && this._highlight(action, e, ui));
	}
},

_mouseStop: function( e, ui ){
	// ...my "menuStop".  Called once per menu "use", ending that use.

	if ( this._menuStarted ) {
		(ui || (ui=this._uiHash(e, 'stop')));
		this._item('select', e, ui);
		this.tracking('stop', e, ui);
		this._trigger('stop', e, ui); // Hey, client-code!  Close the menu!
		this._hoverStarted = this._mouseStarted = this._menuStarted = false;
	}

	// We were watching mouseup/down on the document to notice we should stop.
	// Now that we _are_ stopping, we can stop noticing.
	$(document).
		unbind('mousedown.'+this.widgetName).
		unbind('mouseup.'+this.widgetName);
	// No need to track items until next time.
	this.element.children().
		unbind('mouseenter.'+this.widgetName).
		unbind('mouseleave.'+this.widgetName);
	// Note: we _are_ still bound to mousedown in the triggers and menu.
},

_menuMouseDown: function( e, ui ){
	// ...intercepts events that would otherwise have gone directly to ui.mouse._mouseDown
	// to prevent ui.mouse._mouseDown from closing the menu when we've decided to hover.

	var is_trigger = ui.trigger && ui.trigger!==document && (this.options.liveTriggers || this.triggers.index(ui.trigger)>=0);

	if ( !is_trigger ) {
		var ui_stop = this._uiHash(e, 'stop');
		if ( !ui_stop.select ) {
			this._mouseStarted = true; // force _mouseUp to call my _mouseStop
			return this._mouseUp(e, ui);
		}
	}

	if ( this._hoverStarted ) {	// menu-interaction in progress
		this.tracking('start', e);
	} else {			// this mousedown starts a brand-new interaction
		(is_trigger && (this._startTarget=ui.trigger));

		// let ui.mouse set everything up
		this._mouseDown(e);
		// ...except for capturing mouseups
		$(document).
			unbind('mouseup.'+this.widgetName, this._mouseUpDelegate);
	}

	// ...mouseups are for me: to decide if I should start a hover
	var self = this;
	$(document).one('mouseup.'+this.widgetName, function( e ){
		return self._menuMouseUp(e);
	});
},

_menuMouseUp: function( e ){
	// ...intercepts events that would otherwise have gone directly to ui.mouse._mouseUp
	// to decide if this mouseup should make the menu go away, or if it's a click that
	// starts "hover mode".

	clearTimeout(this._clickDurationTimer);
	this._clickDurationTimer = undefined;

	if ( this._startTarget && !this._menuStarted ) {
		this._mouseStarted = true;
		this._mouseUp(e);
		this._trigger('click', e, { click: this._startTarget });
		return false;
	}

	// Close the menu if...
	var ui;
	if ( this._hoverStarted				// ...we were already hovering
		|| this._mouseStarted			// ...we were already dragging
		|| (this._tracking && (ui=this._uiHash(e, 'stop')).select)	// ...mouseup over an item
		|| this._clickDurationExceded(e) ) {	// ...we were already "pressing"

		this._mouseStarted = true; // force _mouseUp to call my _mouseStop
		return this._mouseUp(e, ui);
	}

	// Otherwise, this mouseup ended a click; the user is now "hovering"---using the menu without dragging.
	this._hoverStarted = true;
	var self = this;
	$(document).
		unbind('mouseup.'+this.widgetName, this._mouseUpDelegate).	// bound by ui.mouse._mouseDown
		one('mousedown.'+this.widgetName, function( e ){
			return self._menuMouseDown(e, { trigger: document });
		});
	e.preventDefault();
	return false;
},

_highlight: function( action, e, ui ){
	// Toggle highlight classes on an "over" or "out" item and on the menu itself.

	var if_highlight = { 'over':true, 'out':false }[ action ];
	if ( this._hoverClass && if_highlight!==undefined && ui[action] ){
		// Toggle highlight for the action-item, e.g., ui.out for 'out'.
		$(ui[action]).toggleClass(this._hoverClass, if_highlight);

		// Toggle highlight for the menu itself.  !! forces a boolean.
		this.element.toggleClass(this._hoverClass, !!ui.over);
	}
},

_itemOf: function( el ){
	// Return the menu item that is or contains el (see use in _uiHash).

	// Assuming all items are children of the same container, this.element,
	// climb el's parent-chain until we hit that container.  When we do, the
	// element examined in the previous iteration is the menu item.

	var item = undefined;
	if ( el ) {
		var	menu	= this.element[0],
			$el	= $(el),
			$path	= $el.add( $el.parents() );

		$path.each(function( i ){
			if ( this === menu ) {
				item = $path[i-1];
				return false;
			}
		});
	}
	return item;
},

_uiHash: function( event_or_type, event_type, ui ){
	// Return a hash of items related to an event,
	// e.g., { over: new_item, out: old_item } for an 'over' event.

	var	actual_event	= (event_or_type && event_or_type.type) ? event_or_type : undefined,
		event_items	= actual_event ? {
					item:		this._itemOf(actual_event.target),
					relatedItem:	this._itemOf(actual_event.relatedTarget)
				} : {	item:		this._overTarget },

		requested_type	= event_type || (actual_event ? actual_event.type : event_or_type),
		map_event_to_ui	= {
			'mouseenter':	{ over: 'item', out: 'relatedItem' },
			'mouseleave':	{ out: 'item', over: 'relatedItem' },
			'stop':		{ select: 'item', out: 'item' }
		}[requested_type] || { over: 'item' };

	(ui || (ui={}));
	$.each(map_event_to_ui, function(to, from){
		ui[to] = event_items[from];
	});
	ui.trigger = this._startTarget;
	return ui;
},

_clickDurationExceded: function( e ){
	return this.clickDurationExceded;
}

}));

$.extend($.slash.menu, {
	version: "0.5",
	eventPrefix: "menu",
	defaults: {
		distance: 1,		// ...in pixels that starts a drag
		clickToHover: true,
		clickDuration: 300,	// time in milliseconds at which point a click becomes a press
		liveTriggers: false
	}
});

})(jQuery);
