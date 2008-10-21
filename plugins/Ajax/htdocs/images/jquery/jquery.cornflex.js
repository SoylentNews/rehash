/*
 * jQuery CornFLEX plugin
 *
 * @name	cornflex
 * @type	jQuery
 * @param	boxname		options		
 */
(function($) {
	$.fn.cornflex = function(boxname, options) {
		
		var settings = {
			omega		: 0,
			boxname		: boxname,
			image_t		: this.boxname + '_t.png',
			image_r		: this.boxname + '_r.png',
			image_b		: this.boxname + '_b.png',
			image_l		: this.boxname + '_l.png',
			alpha		: 0,
			beta		: 0,
			gamma		: 0,
			delta		: 0
		};
		
		if (options) {
			$.extend(settings, options);
		}

		var new_boxes = [];
		
		this.each(function(){
			var $this = $(this);
			$this.wrap('<div class="cornflex ' + settings.boxname + '"><div class="t"><div class="c"></div></div></div>');
			new_boxes.push($this.parents('.cornflex.'+ settings.boxname + ':first')[0]);
		});
		
		/*
		 * Defining specific styles for that box (according to the css: http://dev.pnumb.com/cornflex/wiki/WikiStart#Specificclass)
		 */

		var $new_boxes = $(new_boxes);
		$new_boxes.
			append('<div class="r"></div><div class="b"></div><div class="l"></div>').
			css('padding', '0 ' + (settings.omega + settings.beta) + 'px ' + (settings.omega + settings.gamma) + 'px 0');

		$new_boxes.
			find('.t').
				css('background-image', 'url(' + settings.image_t + ')').
				find('.c').
					css({
						paddingTop: settings.alpha+'px',
						paddingLeft: settings.delta+'px',
						position: 'relative',
						top: (settings.omega / 2) + 'px',
						left: (settings.omega / 2) + 'px'
					});
		$new_boxes.
			find('.r').
				css({
					width: (settings.omega + settings.beta) + 'px',
					bottom: (settings.omega + settings.gamma) + 'px',
					backgroundImage: 'url(' + settings.image_r + ')',
					height: "expression(this.parentNode.offsetHeight - " + (settings.omega + settings.gamma) + " + 'px')"
				});
		$new_boxes.
			find('.b').
				css({
					width: (settings.omega + settings.beta) + 'px',
					height: (settings.omega + settings.gamma) + 'px',
					backgroundImage: 'url(' + settings.image_b + ')'
				});
		$new_boxes.
			find('.l').
				css({
					height: (settings.omega + settings.gamma) + 'px',
					right: (settings.omega + settings.beta) + 'px',
					backgroundImage: 'url(' + settings.image_l + ')',
					width: "expression(this.parentNode.offsetWidth - " + (settings.omega + settings.beta) + " + 'px')"
				});
		return this;
	};
})(jQuery);
