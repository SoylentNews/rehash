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
