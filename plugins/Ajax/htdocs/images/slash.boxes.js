;(function($){

function save_slashbox_positions(){
	ajax_update({
		op:	'page_save_user_boxes',
		reskey:	reskey_static,
		bids:	$('#slashboxes div.title').map(function(){
				return this.id.slice(0,-6);
			}).get().join(',')
	});
}

function remove_slashbox_by_id( id ){
	if ( $('#slashboxes > #'+id).remove().size() ) {
		save_slashbox_positions();
	}
}

function make_slashboxes_sortable(){
	$('#slashboxes').sortable({
		axis: 'y',
		containment: 'parent',
		handle: '.title',
		opacity: 0.8,
		update: save_slashbox_positions
	});
}

Slash.Util.Package({ named: 'Slash.Boxes',
	api: {
		remove: remove_slashbox_by_id
	}
});

$(function(){
	make_slashboxes_sortable();
});

})(Slash.jQuery);
