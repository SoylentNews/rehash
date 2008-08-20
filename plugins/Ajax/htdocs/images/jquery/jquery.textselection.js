;(function($){

// constructor
$.TextSelection = function( el, r ){
	spull(this, el);
	if ( r ) { spush(this.range(r)); }
};

// public 'class' methods
$.TextSelection.get = function( el ){
	if ( el ) {
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
	}
};

$.TextSelection.set = function( el, r ){
	if ( el && r ) {
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
	}
};


// private
function spull( ts, el ){
	ts._r = $.TextSelection.get(ts._el=(el||ts._el));
	return ts;
}

function spush( ts, el ){
	$.TextSelection.set(el || ts._el, ts._r);
	return ts;
}



// public instance methods
$.TextSelection.prototype = {
	field: function( el ){
		return el ? spull(this, el) : this._el;
	},
	range: function( r, dont_select ){
		if ( r ) {
			this._r = r;
			return dont_select ? this : spush(this);
		} else {
			return this._r;
		}
	},
	focus: function(){
		$(this._el).focus();
	},
	save: function( el ){
		return spull(this, el);
	},
	restore: function(){
		return spush(this);
	}
};

})(jQuery);
