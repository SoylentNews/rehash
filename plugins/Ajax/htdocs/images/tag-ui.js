; // tag-ui.js

var Tags={}, tag_admin=false, gFocusedText, $previous_context_trigger = $([]);
(function(){
var WS=/\s+/, NODNIX=/\b(?:meta)?(?:nod|nix)\b/i;

function topics( $tags, sort ){
	var tags = $tags.filter('a.topic').map(function(){ return $(this).text(); }).get();
	sort && tags.sort();
	return tags.join(' ');
}

function inspect( $tagbar ){
	var $tags = $tagbar.children();
	return {
		skin:		$tags.filter('a.main:first').text(),
		vote:		$tags.filter('a.my[href$=/nod],a.my[href$=/nix],a.my[href$=/metanod],a.my[href$=/metanix]').text(),
		topics:		topics($tags, 'sorted'),
		datatype:	$tags.filter('a.datatype')
	};
}

function preprocess( fhitem, tags ){ // catch and handle tag-like commands to be processed locally
	var nodnix = NODNIX.test(tags) && ($(fhitem).is('.fhitem-comment') ? firehose_handle_comment_nodnix : firehose_handle_nodnix);
	tags = tags.split(WS);
	firehose_handle_admin_commands && (tags=firehose_handle_admin_commands.call(fhitem, tags));
	nodnix && nodnix.call(fhitem, tags);
	return tags.join(' ');
}

Tags.submit = function( fhitem, tags ){
	var $fhitem=$(fhitem), key=fhitem_key(fhitem), $spinner=$('span.tag-server-busy', fhitem).show();
	tags && (tags=preprocess(fhitem, tags));

	$.ajax({
		type:'POST',
		dataType:'text',
		data:{
			op:'tags_setget_display',
			key:key.key,
			key_type:key.key_type,
			reskey:reskey_static,
			tags:tags||'',
			limit_fetch:'',
			include_topic_images:sign($fhitem.is('.fhitem-editor'))
		},
		success: function( next_markup ){
			var $tagbar=$fhitem.find('span.tag-bar'), prev=inspect($tagbar), next=inspect($tagbar.html(next_markup));

			// Trigger events directly on $fhitem, but bubble up to document (so you only need to .bind() once).
			// In your handler: event.target is the fhitem.
			function notice_changes( k, data ){ next[k]!==prev[k] && $fhitem.trigger(k+'-assigned', data||next[k]); }

			// postprocess
			notice_changes('datatype');
			notice_changes('topics', topics($tagbar.children())); // compare sorted, but notify in server-supplied order
			notice_changes('skin');
			notice_changes('vote');
		},
		complete: function(){
			$spinner.hide();
		}
	});
};

Tags.fetch = function( fhitem ){ Tags.submit(fhitem); };
})();

(function(){
var	CLASS={ 'true':'expand', 'false':'collapse' },
	ESC=27, SPACE=32, ENTER=13, LEFT_ARROW=37, DOWN_ARROW=40,
	HANDLED_KEYS={ 27:1, 32:1, 13:1, 37:1, 40:1 };

$('a.edit-toggle').live('click', function( e ){
	check_logged_in() && firehose_toggle_tag_ui(original_target(e));
});

$('input.tag-entry').live('keydown', function( event ){
	var $this=$(original_target(event)), code=event.which||event.keyCode;
	switch (code) {
		case ESC: case LEFT_ARROW: case DOWN_ARROW: case SPACE: case ENTER:
			if (code == ESC) {
				$this.val('');
			}
			if (code == LEFT_ARROW || code == DOWN_ARROW) {
				if ($this.val() != '')
					return true;
			}
			if (code == SPACE || code == ENTER) {
				Tags.submit($this.closest('.fhitem')[0], $this.val());
				$this.val('')
				if (code == SPACE)
					return true;
			}
			$this.blur();
			firehose_toggle_tag_ui_to(false, $this);
			return false;
		default:
			return true;
	}
});

})();
