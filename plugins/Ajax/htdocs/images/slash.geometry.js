; // slash.geometry.js

function Size(){
	var	bare	= this.__isa !== Size,		// called without 'new'
		self	= bare ? new Size : this,
		args	= bare && !arguments.length ? [this] : arguments;
	return Size.prototype.assign.apply(self, args);
}

function Position(){
	var	bare	= this.__isa !== Position,	// called without 'new'
		self	= bare ? new Position : this,
		args	= bare && !arguments.length ? [this] : arguments;
	return Position.prototype.assign.apply(self, args);
}

function Bounds(){
	var	bare	= this.__isa !== Bounds,	// called without 'new'
		self	= bare ? new Bounds : this,
		args	= bare && !arguments.length ? [this] : arguments;
	return Bounds.prototype.assign.apply(self, args);
}

(function(){

function _unwrap( o, allow_lists ){
	if ( TypeOf(o) === 'string' ) {
		var el = document.getElementById(o);
		o = el ? el : $(o);
	}

	return allow_lists||!TypeOf.list(o) ? o : o[0];
}

function _isSize( o ){
	var t=TypeOf(o), isNum=TypeOf.number;
	if ( t==='size' || o && isNum(o.height) && isNum(o.width) ) {
		return t;
	}
}

function _hasSize( o ){
	var t=TypeOf(o), isFn=TypeOf.fn;
	if ( o && isFn(o.height) && isFn(o.width) ) {
		return t;
	}
}

function _isPosition( o ){
	var t=TypeOf(o), isNum=TypeOf.number;
	if ( t==='position' || t==='bounds' || o && isNum(o.top) && isNum(o.left) ) {
		return t;
	}
}

function _isBounds( o ){
	var t=TypeOf(o), isNum=TypeOf.number;
	if ( t==='bounds' || o && isNum(o.top) && isNum(o.left) && isNum(o.bottom) && isNum(o.right) ) {
		return t;
	}
}

Size.prototype = {
	__isa: Size,
	__typeOf: function(){ return 'size'; },

	assign: function( o ){
		switch ( !!o && TypeOf(o=_unwrap(o)) ) {
			case 'document':
			case 'element':
			case 'window':
				o = $(o);
			default:
				if ( _isSize(o) ) {
					break;
				}
				if ( _hasSize(o) ) {
					o = { height:o.height(), width:o.width() };
					break;
				}
				if ( _isBounds(o) ) {
					o = { height:o.bottom-o.top, width:o.right-o.left };
					break;
				}
			case 'undefined':
			case 'null':
			case false:
				o = { height:0, width:0 };
		}

		this.height=o.height; this.width=o.width;
		return this;
	},
	toString: function(){
		return '{ height:'+this.height+', width:'+this.width+' }';
	}
};
Size._expected = function( o ){ return _isSize(o) ? o : new Size(o); };

Position.prototype = {
	__isa: Position,
	__typeOf: function(){ return 'position'; },

	assign: function( o ){
		if ( !_isPosition(o) ) {
			switch ( !!o && TypeOf(o=_unwrap(o)) ) {
				case 'window':
					o = $(o);
					o = { top:o.scrollTop(), left:o.scrollLeft() };
					break;
				case 'element':
					o = $(o).offset();
					break;
				default:
					o = { top:0, left:0 };
			}
		}

		this.top=o.top; this.left=o.left;
		return this;
	},
	toString: function(){
		return '{ top:'+this.top+', left:'+this.left+' }';
	}
};
Position._expected = function( o ){ return _isPosition(o) ? o : new Position(o); };

Bounds.prototype = {
	__isa: Bounds,
	__typeOf: function(){ return 'bounds'; },

	assign: function( o1, o2 ){
		if ( _isBounds(o1) ) {
			this.top = o1.top;
			this.left = o1.left;
			this.bottom = o1.bottom;
			this.right = o1.right;
		} else {
			var po1 = Position._expected(o1);
			this.top = this.bottom = po1.top;
			this.left = this.right = po1.left;

			arguments.length==1 && (o2 = Size(o1));
			if ( _isPosition(o2) ) {
				this.bottom = o2.top;
				this.right = o2.left;
			} else if ( _isSize(o2) ) {
				this.bottom += o2.height;
				this.right += o2.width;
			}
		}
		return this;
	},
	toString: function(){
		return '{ top:'+this.top+', left:'+this.left+', bottom:'+this.bottom+', right:'+this.right+' }';
	},
	height: function(){ return this.bottom-this.top; },
	width: function(){ return this.right-this.left; },
	union: function( o ){
		o = Bounds._expected(o);

		o.top<this.top && (this.top=o.top);
		o.left<this.left && (this.left=o.left);
		o.bottom>this.bottom && (this.bottom=o.bottom);
		o.right>this.right && (this.right=o.right);

		return this;
	},
	intersect: function( o ){
		o = Bounds._expected(o);

		o.top>this.top && (this.top=o.top);
		o.left>this.left && (this.left=o.left);
		o.bottom<this.bottom && (this.bottom=o.bottom);
		o.right<this.right && (this.right=o.right);

		return this;
	}
};
Bounds._expected = function( o ){ return _isBounds(o) ? o : new Bounds(o); };

Bounds.empty = function( o ){
	o = Bounds._expected(o);
	return o.bottom<=o.top || o.right<=o.left;
};
Bounds.equal = function( a, b ){
	a = Bounds._expected(a); b = Bounds._expected(b);
	return a.top==b.top && a.left==b.left && a.bottom==b.bottom && a.right==b.right;
};


function _each_op( a, b ){
	var	result	= new Bounds(a=_unwrap(a, true)),
		A	= arguments.length==1 && TypeOf.list(a) ? a : arguments;
	for ( var i=1; i<A.length; ++i ){
		result[this](A[i]);
	}
	return result;
}
// Bounds.op(a, b [, c, d, e...]) or Bounds.op($list)
Bounds.union = function(){ return _each_op.apply('union', arguments); };
Bounds.intersection = function(){ return _each_op.apply('intersect', arguments); };

Bounds.intersect = function( a, b ){
	return !Bounds.empty(Bounds.intersection(a, b));
};
Bounds.contain = function( a, b ){
	return Bounds.equal(a, Bounds.union(a, b));
};

Bounds.y = function( o ){
	var bounds = new Bounds(o);
	bounds.left = -Infinity;
	bounds.right = Infinity;
	return bounds;
}
Bounds.x = function( o ){
	var bounds = new Bounds(o);
	bounds.top = -Infinity;
	bounds.bottom = Infinity;
	return bounds;
}

})();
