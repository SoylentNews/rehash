;(function($){

Slash.Util.Package({ named: 'Slash.ArticleInfo',
	stem_function: datum,
	api: {
		key:		find_key,
		find_article:	elem_fn($find_articles),
		find:		elem_fn($find_info_blocks)
	},
	jquery: {
		stem_function: function( k, v ){
			if ( v === undefined ) {
				return datum(this[0], k);
			}
			return this.each(function(){
				datum(this, k, v);
			});
		},
		element_api: {
			key: function(){
				return find_key(this[0]);
			},
			get: function( k ){
				return datum(this[0], k);
			},
			set: function( k, v ){
				return this.each(function(){
					datum(this, k, v);
				});
			},
			find_articles:	jquery_fn($find_articles),
			find:		jquery_fn($find_info_blocks)
		}
	}
});

var re_key = /^sd-key-(.*)/;
var select_keys = '[class^=sd-key-]';
var select_first_key = select_keys + ':first';
var select_info_blocks = 'span.sd-info-block';
var info_block_html = '<span class="sd-info-block" style="display: none" />';

function datum( elem, k, v ){
	var	info = Slash.ArticleInfo.find(elem),
		$info = info ? $(info) : $([]),
		$datum = $info.find('.' + k);

	if ( v === undefined ) {
		return $datum.text();
	}
	if ( ! $datum.length ) {
		if ( ! $info.length ) {
			var	$elem = $(elem),
				$key = $elem.find(select_first_key).siblings(select_keys).andSelf();
			if ( $key.length ) {
				$key.wrapAll(info_block_html);
			} else {
				$elem.prepend(info_block_html);
			}
			$info = $elem.find(select_info_blocks);
		}
		$datum = $info.append('<span class="' + k + '" />').find('.' + k);
	}
	$datum.text(v);
}

function find_key( elem ){
	var $key = $(elem).find(select_first_key);
	if ( $key.length ) {
		return {
			key:		$key.text(),
			key_type:	re_key.exec($key[0].className)[1]
		};
	}
}

function $find_info_blocks( $list ){
	return $list.map(function(){
		return $(this).find_nearest(select_info_blocks, 'self', 'down', 'up').get();
	});
}

function $find_articles( $list ){
	return $find_info_blocks($list).map(function(){
		var $this = $(this);
		return $this.nearest_parent($this.find('span.scope').text() || 'div')[0];
	});
}

function jquery_fn( fn ){
	return function( expr ){
		var $list = fn(this);
		if ( expr !== undefined ) {
			$list = $list.filter(expr);
		}
		return this.pushStack($.unique($list));
	};
}

function elem_fn( fn ){
	return function( elem ){
		var $list = fn($(elem));
		if ( $list.length ) {
			return $list[0];
		}
	}
}

})(Slash.jQuery);

/*

$('#firehoselist .tagui-need-init').
	article_info__find_articles();

<span class="sd-info-block">
	<span class="sd-key-firehose-id">1128650</span>
	<span class="scope">#firehose-1128650</span>
	<span class="type">firehose</span>
	<span class="tagui-needs-init">true</span>
</span>

<span class="sd-info-block">
	<span class="sd-key-url">http://cmdrtaco.net</span>
	<span class="type">project</span>
</span>


*/
