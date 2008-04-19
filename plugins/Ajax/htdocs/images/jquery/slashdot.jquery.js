// slashdot.jquery.js: jquery-related general utilities we wrote ourselves

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
	}

});


function split_if_string( list, sep ){
	return typeof list === 'string' ? list.split(sep || /\s+/) : list
}


function join_wrap( a, elem_prefix, elem_suffix, list_prefix, list_suffix ) {
	var result = '';
	if ( a && a.length ) {
		a = split_if_string(a);

		var ep = elem_prefix || '';
		var es = elem_suffix || '';
							// Example:
		result = (list_prefix || '') + ep	// '<ul><li>'
			+ a.join(es+ep)			// .join('</li><li>')
			+ es + (list_suffix || '');	// '</li></ul>
	}
	return result;
}


function map_list_to_set( list, map_fn ){
	if ( !list || !list.length )
		return;

	list = split_if_string(list);

	if ( map_fn === undefined )
		map_fn = function(x){return x};

	var set = {};
	$.each(list, function(){
		var k = map_fn(this);
		if ( k !== undefined && k !== null )
			set[k] = true;
	});
	return set;
}


function map_set_to_list( set, map_fn ){
	var list = [];
	$.each(set, function(k, v){
		var x = map_fn(k, v);
		if ( x !== undefined && x !== null )
			list.push(x)
	});
	return list;
}


function keys( dict ){
	return map_set_to_list(dict, function(k, v){return k})
}


function values( dict ){
	return map_set_to_list(dict, function(k, v){return v})
}
