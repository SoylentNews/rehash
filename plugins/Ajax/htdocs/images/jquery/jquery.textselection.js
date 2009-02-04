;(function($){

// constructor
$.TextSelection = function( el, r ){
	spull(this, el); // initializes:
	// this._el	to: text field DOM element, iff $.TextSelection.get() understands it
	// this._r	to: browser-specific object representing a selection range

	if ( r ) { spush(this.range(r)); }
};

$.TextSelection.Error = function( description, obj ){
	this._description = description;
	this._obj = obj;
};

// public 'class' methods
$.TextSelection.get = function( el ){
	// expected to throw an exception if for any reason el doesn't satisfy
	if ( ! el ) {
		throw $.TextSelection.Error('$.TextSelection.get(el): argument is required', el);
	}

	try {
		if ( el.selectionStart !== undefined ) {
			return {
				selectionStart:	el.selectionStart,
				selectionEnd:	el.selectionEnd
			};
		} else if ( el.createTextRange ) {
			var START=true, END=false;
			var bound = function( at_start ){
				var tr = document.selection.createRange();
				if ( tr.compareEndPoints('StartToEnd', tr) ) {
					tr.collapse(at_start);
				}
				return tr.getBookmark().charCodeAt(2)-2;
			};
			return {
				selectionStart:	bound(START),
				selectionEnd:	bound(END)
			};
		}
	} catch ( unused_error ) {
		// fall through...
	}

	throw $.TextSelection.Error('$.TextSelection.get(el): no range operations available on el', el);
};

$.TextSelection.set = function( el, r ){
	// expected to throw an exception if for any reason el doesn't satisfy
	if ( !(el && r) ) {
		throw $.TextSelection.Error('$.TextSelection.set(el, r): both arguments are required', el);
	}

	try {
		if ( el.createTextRange ) {
			var tr = el.createTextRange();
			tr.collapse(true);
			tr.moveStart('character', r.selectionStart);
			tr.moveEnd('character', r.selectionEnd);
			tr.select();
		} else if ( el.setSelectionRange ) {
			el.setSelectionRange(r.selectionStart, r.selectionEnd);
		} else if ( el.selectionStart !== undefined ) {
			el.selectionStart =	r.selectionStart;
			el.selectionEnd =	r.selectionEnd;
		}

		return;
	} catch ( unused_error ) {
		// fall through...
	}

	throw $.TextSelection.Error('$.TextSelection.set(el, r): no range operations available on el', el);
};


// private
// spull/spush trap all exceptions and try to be non-destructive; use Firebug (or equiv) if you need to see them
function spull( ts, el ){
	// initialize or update a TextSelection, fetching the currently selected range
	try {
		ts._r = $.TextSelection.get(ts._el=(el||ts._el));
	} catch ( unused_error ) {
		ts._el = null;
	}
	return ts;
}

function spush( ts, el ){
	// apply the range described by a TextSelection to a text field
	try {
		$.TextSelection.set(el || ts._el, ts._r);
	} catch ( unused_error ) {
		// non-fatal, ignore
	}
	return ts;
}



// public instance methods
$.TextSelection.prototype = {
	field: function( el ){
		// set or get the underlying text field DOM element
		return el ? spull(this, el) : this._el;
	},
	range: function( r, dont_select ){
		// set or get the selection range as cached in the TextSelection
		if ( r ) {
			this._r = r;
			return dont_select ? this : spush(this);
		} else {
			return this._r;
		}
	},
	focus: function(){
		$(this._el || []).focus();
	},
	save: function( el ){
		return spull(this, el);
	},
	restore: function(){
		return spush(this);
	}
};

})(jQuery);
