;(function($){

// private

function set_selection( el, r ){
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

function get_selection( el ){
	if ( el.selectionStart !== undefined ) {

		return {
			selectionStart:	el.selectionStart,
			selectionEnd:	el.selectionEnd
		};

	} else if ( el.createTextRange ) {
		var START=true, END=false;
		var end_point = function( at_start ){
			var tr = document.selection.createRange();
			if ( tr.compareEndPoints('StartToEnd', tr) ) {
				tr.collapse(at_start);
			}
			return tr.getBookmark().charCodeAt(2)-2;
		};

		return {
			selectionStart:	end_point(START),
			selectionEnd:	end_point(END)
		};
	}
}

// constructor
$.TextSelection = function( el, r ){
	this.from(el);
	if ( r ) {
		this.range(r);
		this.apply_to(el);
	}
};

// private shortcut
var Ts = $.TextSelection;

// 'class' functions
Ts.set = function( el, r ){
	set_selection(el, r);
};

Ts.get = function( el ){
	return get_selection(el);
};



// methods
Ts.prototype = {
	_pull: function( el ){
		this._r = Ts.get((this._el=el));
		return this;
	},
	_push: function( el ){
		if ( el && this._r ) {
			Ts.set(el, this._r);
		}
		return this;
	},
	field: function( el ){
		if ( el ) {
			return this._pull(el);
		} else {
			return this._el;
		}
	},
	range: function( r ){
		if ( r ) {
			this._r = r;
			return this._push(this._el);
		} else {
			return this._r;
		}
	},
	save: function( el ){
		return this._pull(el ? el : this._el);
	},
	restore: function(){
		return this._push(this._el);
	}
};

})(jQuery);
