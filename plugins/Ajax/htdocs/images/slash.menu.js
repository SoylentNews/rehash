(function($){

function bounds( elem ){
	var $e = $(elem), b = $e.offset();
	b.right = b.left + $e.outerWidth();
	b.bottom = b.top + $e.outerHeight();
	return b;
}

function union_bounds(b1, b2){
	if ( ! b1 ) {
		b1 = b2;
	}
	return {
		top:	Math.min(b1.top, b2.top),
		left:	Math.min(b1.left, b2.left),
		bottom:	Math.max(b1.bottom, b2.bottom),
		right:	Math.max(b1.right, b2.right)
	};
}

function point_in_bounds( pt, r ){
	return	r && (r.left <= pt.x) && (pt.x <= r.right) && (r.top <= pt.y) && (pt.y <= r.bottom);
}

$.widget("slash.menu", $.extend({}, $.ui.mouse, {

	_init: function(){
		// called for $(...).menu()

		this._mouseInit();

		(this.options.trigger && (this.triggerElement=$(this.options.trigger)));

		// rewire the bindings: mousedown goes to _me_ instead of to ui.mouse
		var self = this;
		this.element.add(this.triggerElement).
			unbind('mousedown.'+this.widgetName).	// bound by ui.mouse._mouseInit
			bind('mousedown.'+this.widgetName, function( event ){
				return self._menuMouseDown(event);
			});

		(this.options.cssNamespace && (this._hoverClass=this.options.cssNamespace + '-hover'));
		this._mouseStarted = this._menuStarted = false;
	},

	destroy: function(){
		// called for $(...).menu("destroy|remove")

		if ( this.element.data('menu') ) {
			this.element.removeData('menu').unbind('.menu');
			this._mouseDestroy();
		}
	},

	_menuStart: function( event ){
		var t = this.options.clickDuration;
		this.clickDurationExceded = t<=0;
		if ( t ) {
			var self = this;
			this._clickDurationTimer = setTimeout(function(){
				self.clickDurationExceded = true;
			}, t);
		}

		// open/show the menu
		this._trigger('start', event);	// call options.start(event) and other observers

		this._menuStarted = true;
		this._hoverStarted = false;

		// TODO: decide if we need to check that geometry has changed, or if we rely on the client
		this.recalculatePositions();

		// check immediately: are we over an item
		this._menuMove(event);
		return true;
	},

	recalculatePositions: function(){
		// discard cached bounds; clients call this after they've moved the menu or its items
		this.sumItemBounds = this.overBounds = false;
	},

	_over: function( event, force ){
		// find what item the mouse is over saving in this.over (and caching bounds)

		if ( !event ) {
			this.overBounds = this.over = undefined;
			return;
		}



		// try the current element first (we cached its bounds when we first entered it)
		var mouse = { x: event.pageX, y: event.pageY };
		if ( old_over && point_in_bounds(mouse, this.overBounds) ) {
			return force && { over: this.over };
		}

		var old_over = this.over;
		this.overBounds = this.over = undefined;

		// can't test the container bounds directly, as it might not geometrically contain the items :-(
		var in_menu = point_in_bounds(mouse, this.sumItemBounds);

		// in_menu === true		=> sumItemBounds already cached, mouse is within it
		// in_menu === undefined	=> sumItemBounds undefined (not cached)
		// in_menu === false		=> sumItemBounds already cached, mouse _not_ within it

		if ( in_menu===false && !old_over ) {
			return force && { over: old_over };
		}


		// if the mouse is not known to fall outside the menu completely
		if ( in_menu !== false ) {
			// ...test against each possible item in sequence; if this search becomes a performance problem, consider caching
			var bounds_sum, self = this;
			this.element.children().each(function(){
				var r = bounds(this);
				if ( point_in_bounds(mouse, r) ) {
					self.over = this;
					self.overBounds = r;
					return false; // stop the 'each'
				}
				bounds_sum = union_bounds(bounds_sum, r);
			});

			// if we didn't find an item, then we must have looked at every one
			if ( ! this.over && ! this.sumItemBounds ) {
				// in which case, bounds_sum is complete
				this.sumItemBounds = bounds_sum;
			}
		}

		if ( old_over !== this.over ) {
			return { out: old_over, over: this.over };
		} else if ( force ) {
			return { over: this.over };
		}

		return false;
	},

	_menuMove: function( event ){
		// notice when the mouse leaves/enters menu items
		// Note: caching makes this algorithm naive in the face of overlapping items
		var ui = this._over(event);
		if ( ui ) {
			if ( ui.out ) {
				// remove custom highlighting from the item the mouse just left
				(this._hoverClass && $(ui.out).removeClass(this._hoverClass));
				this._trigger('out', event, ui);	// call options.out(event, ui) and other observers
			}

			(this._hoverClass && this.element.toggleClass(this._hoverClass, !!ui.over));

			if ( ui.over )	{
				// add custom highlighting to the item the mouse just entered
				this._trigger('over', event, ui);	// call options.over(event, ui) and other observers
				(this._hoverClass && $(ui.over).addClass(this._hoverClass));
			}
		}
	},

	_menuStop: function( event ){
		// stop hijacking mouseUp/Downs from the document
		$(document).
			unbind('mousedown.'+this.widgetName).
			unbind('mouseup.'+this.widgetName);

		var ui = this._over(event, true);

		// select the current item, if any
		if ( ui.over ) {
			ui.select = ui.over;
			(this._hoverClass && $(ui.over).removeClass(this._hoverClass));

			// update a value or do a command
			this._trigger('select', event, ui);	// call options.select(event, ui) and other observers
		}

		// close/hide the menu, etc.
		this._trigger('stop', event, ui);		// call options.stop(event, ui) and other observers

		// reset for next time
		this._menuStarted = this._hoverStarted = false;
		this._over(false);
	},


	_mouseCapture:	function( event ){
		// called by _mouseDown to ask: does this mouseDown start you up?

		var	capture	= false,
			mouse	= { x: event.pageX, y: event.pageY },
			self	= this;

		// We capture when the mouseDown was within either the menu or the trigger
		this.element.
			add(this.triggerElement).
				each(function(){
					if ( point_in_bounds(mouse, bounds(this)) ) {
						capture = self._menuStart(event);
						return false; // stop the 'each'
					}
				});
		return capture;
	},
	_mouseStart:	function(){ return true; },
	_mouseDrag:	function( event ) { return this._menuMove(event); },
	_mouseStop:	function( event ) { return this._menuStop(event); },

	_menuMouseDown: function( event ){
		// intercepts events that would have gone directly to ui.mouse._mouseDown

		if ( event.originalEvent.mouseHandled ) {
			return;
		}

		// _hoverStarted => a menu action is already in progress (started by click-opening the menu)

		if ( ! this._hoverStarted ) {
			// ...only call ui.mouse._mouseDown to begin a totally new action
			this._mouseDown(event);

			// intercept calls to ui.mouse._mouseUp
			$(document).unbind('mouseup.'+this.widgetName, this._mouseUpDelegate); // bound by ui.mouse._mouseDown
		}

		// the next mouseup goes to us
		var self = this;
		$(document).one('mouseup.'+this.widgetName, function( event ){
			return self._menuMouseUp(event);
		})
	},

	_menuMouseUp: function( event ){
		// intercepts events that would have gone directly to ui.mouse._mouseUp

		clearTimeout(this._clickDurationTimer);

		var ui = this._over(event, true);

		// if this is a mouseUp...
		if ( this._hoverStarted				// ...after a click + second mouseDown
			|| this._mouseStarted			// ...that ends a drag
			|| ui.over				// ...over one of the menu items
			|| this._clickDurationExceded(event) ) {// ...that ends a press (without having moved)

			this._mouseStarted = true; // force _mouseUp to call _menuStop
			return this._mouseUp(event);
		}
		// else, it's a click beginning an extended menu action
		this._hoverStarted = true;

		// this._trigger('click', event, ui); // should we add a 'click' event? first click only? what if over an item?

		var self = this;
		$(document).
			unbind('mouseup.'+this.widgetName, this._mouseUpDelegate).	// bound by ui.mouse._mouseDown
			one('mousedown.'+this.widgetName, function( event ){
				return self._menuMouseDown(event);
			});
		event.preventDefault();
		return false;
	},

	_clickDurationExceded: function( event ){
		return this.clickDurationExceded;
	}
}));

$.extend($.slash.menu, {
	version: "0.1",
	eventPrefix: "menu",
	defaults: {
		distance: 1,		// amount
		clickDuration: 300,	// time in milliseconds at which point a click becomes a press
		animate: true
	}
});

})(jQuery);
