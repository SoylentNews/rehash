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
var	IS_AUTOCOMPLETE_READY='ac-ready',
	ENTER=13, ESC=27, SPACE=32, SUBMIT_FOR={}, CLEAR_FOR={}, CLOSE_FOR={};

(function(){
	SUBMIT_FOR[ENTER] = SUBMIT_FOR[SPACE] = true;
	CLEAR_FOR[ENTER] = CLEAR_FOR[ESC] = CLEAR_FOR[SPACE] = true;
	CLOSE_FOR[ENTER] = CLOSE_FOR[ESC] = true;
})();

$('input.tag-entry').
	live('keydown', function( event ){ // install autocomplete if not yet installed
		var $this=$(original_target(event)), key=event.which || event.keyCode;

		if ( !$this.data(IS_AUTOCOMPLETE_READY) ) {
			$this.	autocomplete('/ajax.pl', {
					loadingClass:'working',
					minChars:3,
					autoFill:true,
					max:25,
					extraParams:{
						op:'tags_list_tagnames'
					}
				}).
				data(IS_AUTOCOMPLETE_READY, true);
		}

		if ( key===ESC ) {
			event.preventDefault();
			event.stopImmediatePropagation();
			return false;
		}

		return true;
	}).
	live('keyup', function( event ){
		var $this=$(original_target(event)), key=event.which || event.keyCode;

		SUBMIT_FOR[key]	&& Tags.submit($this.closest('.fhitem')[0], $this.val());
		CLEAR_FOR[key]	&& $this.val('');
		CLOSE_FOR[key]	&& firehose_toggle_tag_ui_to(false, $this);
		return true;
	});

$('a.edit-toggle').live('click', function( e ){
	check_logged_in() && firehose_toggle_tag_ui(original_target(e));
});

})();
