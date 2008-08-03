// slashdot.jquery.js: jquery-related general utilities we wrote ourselves

;$(function(){
	$.ajaxSetup({
		url:	'/ajax.pl',
		type:	'POST'
	});
});

function $dom( id ) {
	return document.getElementById(id);
}

jQuery.fn.extend({

	mapClass: function( map ) {
		map['?'] = map['?'] || [];
		return this.each(function() {
			var unique = {};
			var cl = [];
			$.each($.map(this.className.split(/\s+/), function(k){
				return k in map ? map[k] : ('*' in map ? map['*'] : k)
			}).concat(map['+']), function(i, k) {
				if ( k && !(k in unique) ) {
					unique[k] = true;
					cl.push(k);
				}
			});
			this.className = (cl.length ? cl : map['?']).join(' ');
		});
	},

	setClass: function( c1 ) {
		return this.each(function() {
			this.className = c1
		});
	},

	toggleClasses: function( c1, c2, force ) {
		var map = { '?': force };
		map[c1]=c2;
		map[c2]=c1;
		return this.mapClass(map);
	},

	toggleClassTo: function( css_class, expr ) {
		return this[ expr ? 'addClass' : 'removeClass' ](css_class)
	},

	nearest_parent: function( selector ) {
		var answer = this.map(function(){
			var $this = $(this);
			return $this.is(selector)
				? this
				: $this.parents(selector + ':first')[0]
		});

		return this.pushStack($.unique(answer))
	},

	separate: function( f ){
		var pass, fail;
		[ pass, fail ] = separate(this, $.isFunction(f) ? f : function(e){
			return $(e).is(f)
		});
		return [ $(pass), $(fail) ]
	}

});


/*
We push around a lot of strings, often using them to represent a lists, e.g.,

	'tag1 tag2 tag3'

is a string representation for the logical list

	['tag1', 'tag2', 'tag3']

list_as_array comes in when you need your "logical list" to really be a
concrete array of individual strings; building you that _actual_ list.  It is
also designed to "nest": if the data came to you already in the form of an array
of strings, list_as_array just hands it right back to you. That is, for any
input that is _not_ split-able, list_as_array's goal is to be the identity
function.

Because we're thinking of the logical list implied by your string, there are a
couple of special cases: the empty string, '', or a string containing only
whitespace both imply an empty list [], as does any expression that evaluates to
false. Leading or trailing whitespace in the input list must be ignored.
JavaScript's split won't give us the answer we want for any of these cases (if
it did, we'd just call it directly!).
*/
function list_as_array( list ){
	if ( list ) {
		// jQuery wrapped elements are already an array
		if ( list.jquery !== undefined )
			return list;

		// trim leading/trailing whitespace if we can
		if ( list.replace  )
			list = list.replace(/^\s*(.*?)\s*$/, '$1');

		// Were list=='', we would have missed the outer 'if', but
		// trimming may have _made_ list empty.  That's why we did it
		// _before_ calling split.

		return list.length && list.split ? list.split(/\s+/) : list || []
	}

	return []
}

function list_as_string( list ){
	if ( list ) {
		if ( list.join )
			list = list.join(' ');

		return /\S/.test(list) ? list : ''
	}

	return ''
}


function join_wrap( a, elem_prefix, elem_suffix, list_prefix, list_suffix ) {
	// always returns a string, even if it's the empty string, ''
	var result = '';
	a = list_as_array(a);
	if ( a && a.length ) {
		var ep = elem_prefix || '';
		var es = elem_suffix || '';
							// Example:
		result = (list_prefix || '') + ep	// '<ul><li>'
			+ a.join(es+ep)			// .join('</li><li>')
			+ es + (list_suffix || '');	// '</li></ul>
	}
	return result
}


function map_list_to_set( list, map_fn ){
	// map_list_to_set is most useful when you need to repeatedly ask "Is 'x'
	//	in this list?  Is 'y' in this list?", or do set like operations
	//	on lists, e.g., union, intersection, difference.

	// list (required) can be an array or a string
	list = list_as_array(list);

	// map_fn (optional) allows you to filter the list
	if ( map_fn === undefined )
		map_fn = function(x){return x};

	// always returns a set, even if it's the empty set, {}
	var set = {};
	if ( list && list.length ) {
		$.each(list, function(){
			var k = map_fn(this);
			if ( k !== undefined && k !== null )
				set[k] = true;
		})
	}
	return set
}


function map_set_to_list( set, map_fn ){
	// map_set_to_list is most useful for getting back to a list after you've
	//	used sets (made with map_list_to_set) to do a bunch of math.  But
	//	see also keys() and values(), below.

	// set (required) must be iterable

	// map_fn (optional) allows you to filter the set, and specify what
	//	actually ends up in the resulting list.  The default is the 'key',
	//	thus "un-doing" the map_list_to_set operation.
	if ( map_fn === undefined )
		map_fn = function(k, v){return k};

	// always returns a list, even if it's the empty list, []
	var list = [];
	$.each(set, function(k, v){
		var x = map_fn(k, v);
		if ( x !== undefined && x !== null )
			list.push(x)
	});
	return list
}


function keys( dict ){
	return map_set_to_list(dict)
}


function values( dict ){
	return map_set_to_list(dict, function(k, v){return v})
}


function separate( list, fn ){
	var answer = { true: [], false: [] };
	$.each(list_as_array(list), function(i, elem){
		answer[!!fn.apply(elem, [elem, i])].push(elem)
	})
	return [ answer[true], answer[false] ]
}
