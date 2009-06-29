;(function($){
// No client-callable functions.  It's all automatic.

function save_slashboxes(){
	if (! check_logged_in()) {
		return false;
	}

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
	prepend($('#slug-Crown')).
	append($('#slug-Top')).
	sortable({			// make slashboxes sortable...
		axis: 'y',
		containment: 'parent',
		handle: '.title',
		items: '>:not(.nosort)',
		opacity: 0.8,
		update: save_slashboxes	// ...and save their new order
	}).
	find('> div.block:not(.nosort) > div.title > h4').	// add closeboxes...
		append('<span class="closebox">x</span>');

// .live() requires a selector ... no context, and so no $(...).find()
$('#slashboxes .block:not(.nosort) h4 span.closebox').
	live('click', function(){
		$(this).closest('div.block').remove();
		save_slashboxes();
		after_article_moved();
	});

});

})(Slash.jQuery);
