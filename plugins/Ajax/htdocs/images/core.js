var core = (function(){

function ordered( o ){
	// Returns |true| if |o| should be treated as an ordered collection.
	return o && 'length' in o && (o.length-1 in o || o.length===0 && typeof(o)!=='function');
}

function flatten( array ){
	// |concat| "flattens" array arguments; use .apply to "unwrap" |array|.
	return Array.prototype.concat.apply([], array);
}


// The following functions visit each member of |o| with |fn(key, o[key])|.  |key|
// is an index when |o| is a list, else it is a member name; undefined regions of
// sparse lists are not visited.  Within |fn|, |this===o[key]|.  Differences noted.

function each( o, fn ){
	// Do arbitrary work for each member of |o|; returning |o|.

	// |fn| may return |false| to "break" out of the loop, any other result is ignored.

	if ( ordered(o) ) {
		// |Array.forEach| can't "break"; |Array.every| does.
		Array.every(o, function( v, i ){
			return fn.call(v, i, v)!==false;
		});
	} else {
		for ( var name in o ){
			if ( fn.call(o[name], name, o[name])===false ) {
				break;
			}
		}
	}
	return o;
}

function reduce( o, accumulated, fn ){
	// Return a value accumulated by applying |fn| to each member of |o|.
	// The initial value of |accumulated| can be omitted: |reduce(o, fn)|.

	// |fn| is called with a third argument: |fn(key, o[key], accumulated)|.  Within
	// |fn|, |this===accumulated|.  The value returned by |fn| replaces the existing
	// |accumulated|.  If |fn| updates |accumulated| in-place, it should return
	// |undefined|.  |accumulated| defaults to |[]| for list-like |o|, or else |{}|.

	var step;
	switch ( typeof(accumulated) ){
		case 'function':
			if ( arguments.length > 2 )
				break;
			fn = accumulated;
			// fall through
		case 'undefined':
			accumulated = ordered(o) ? [] : {};
	}
	each(o, function( k, v ){
		(step=fn.call(accumulated, k, v, accumulated))!==undefined && (accumulated=step);
	});
	return accumulated;
}


return {

	each: each,

	reduce: reduce,

	map: function( o, fn ){
		// Return an array of the results of |fn| applied to the members of |o|.
		// Often useful on list-like |o|; rarely, if ever, on hashes.

		var step, mapped=[];
		reduce(o, mapped, function( k, v ){
			(step=fn.call(v, k, v))!==undefined && this.push(step);
			// Note: |step| may be an array.
		});
		return flatten(mapped);
	},

	keys: function( o ){
		// Return an array of the keys in |o|.
		// Useful on hashes; rarely, if ever, on list-like |o|.

		return reduce(o, [], function( key ){ this.push(key); });
	},

	values: function( o ){
		// Return an array of the values in |o|.
		// Useful on hashes; identity on list-like |o|.

		return reduce(o, [], function( key, value ){ this.push(value); });
	},

	grep: function( o, fn, invert ){
		// Return an array of the values from |o| for which |fn| returned |true|-ish.
		// Useful on list-like |o|; rarely, if ever, on hashes.

		return reduce(o, [], function( k, v ){
			!invert != !fn.call(v, k, v) && this.push(v);
		});
	},

	merge: function( o /*, o1, o2, ... */ ){
		Array.prototype.push.apply(o, flatten(Array.slice(arguments, 1)));
		return o;
	},

	unique:	function( o ){
		// Return an array of distinct values in |o|.
		// Useful on list-like |o|; rarely, if ever, on hashes.

		var seen={};
		return reduce(o, [], function( k, v ){
			v in seen || (seen[v]=true) && this.push(v);
		});
	}

};

})();
