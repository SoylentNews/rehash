YAHOO.namespace("slashdot");

YAHOO.slashdot.SlashBox = function( id, sGroup, config ) {
	if ( id ) {
		this.init(id, sGroup, config);
		this.initFrame();
		this.logger = this.logger || YAHOO;
	}

	this.deleteBoundaryId = sGroup;
}

YAHOO.extend(YAHOO.slashdot.SlashBox, YAHOO.util.DDProxy);


YAHOO.slashdot.SlashBox.prototype.startDrag = function(x, y) {
	var orig = $(this.getEl());
	var dragCopy = $(this.getDragEl());
	// dragging a copy, make sure it has the same contents and class as the original
	dragCopy.html(orig.html()).setClass(orig.attr('className'));
	orig.addClass("to-be-moved");
}

YAHOO.slashdot.SlashBox.prototype.endDrag = function(e) {
	$(this.getEl()).removeClass("to-be-moved");
	// done moving, back to your regularly scheduled CSS (see this.startDrag)
}

YAHOO.slashdot.SlashBox.prototype.onDragOver = function(e, id) {
	if ( id == this.deleteBoundaryId )
		return;

	var pointer_y = YAHOO.util.Event.getPageY(e);
	var dragged_box = this.getEl();
	var fixed_box;

	if ("string" == typeof id)
		fixed_box = YAHOO.util.DDM.getElement(id);
	else
		fixed_box = YAHOO.util.DDM.getBestMatch(id).getEl();

	var parent = fixed_box.parentNode;

	var dragged_top = YAHOO.util.DDM.getPosY(dragged_box);
	var fixed_top = YAHOO.util.DDM.getPosY(fixed_box);
	
	var fixed_mid = fixed_top + ( Math.floor(fixed_box.offsetHeight / 2));

	var dragging_down = dragged_top < fixed_top;


	if ( dragging_down && pointer_y > fixed_mid )
		parent.insertBefore(fixed_box, dragged_box);
	else if ( !dragging_down && pointer_y < fixed_mid )
		parent.insertBefore(dragged_box, fixed_box);
	else
		return;
}

YAHOO.slashdot.SlashBox.prototype.onDragEnter = function(e, id) {
	if ( id == this.deleteBoundaryId ) {
		$([this.getDragEl(), this.getEl()]).removeClass("to-be-deleted");
			// so we can style the object-to-be-moved in CSS
	}
}

YAHOO.slashdot.SlashBox.prototype.onDragOut = function(e, id) {
	if ( id == this.deleteBoundaryId ) {
		$([this.getDragEl(), this.getEl()]).addClass("to-be-deleted");
			// so we can style the object-to-be-moved in CSS
	}
}

YAHOO.slashdot.SlashBox.prototype.onDragDrop = function(e, id) {
	ajaxSaveSlashboxes();
}
