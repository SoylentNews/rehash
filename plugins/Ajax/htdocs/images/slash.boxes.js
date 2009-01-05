;(function($){
// No client-callable functions.  It's all automatic.

function save_slashboxes(){
	// tell the server our current list of slashboxes
	ajax_update({
		op:	'page_save_user_boxes',
		reskey:	reskey_static,
		bids:	$('#slashboxes div.title').
				map(function(){
					return this.id.slice(0,-6);
				}).
				get().
				join(',')
	});
}

$(function(){ // on document ready:

$('#slashboxes').
	sortable({			// make slashboxes sortable...
		axis: 'y',
		containment: 'parent',
		handle: '.title',
		opacity: 0.8,
		update: save_slashboxes	// ...and save their new order
	}).
	find('> div.block > div.title > h4').	// add closeboxes...
		append('<span class="closebox">x</span>').
		find('span.closebox').
			click(function(){	// ...that close; save new state
				$(this).nearest_parent('div.block').remove();
				save_slashboxes();
			});

});

})(Slash.jQuery);
