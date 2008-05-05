(
  function() {
    var url_attr   = 'url='   + encodeURIComponent(window.[% sitename %]_url         || window.location.href);
    var style_attr = 'style=' + encodeURIComponent(window.[% sitename %]_badge_style || 'h0');
    var title_attr = 'title=' + encodeURIComponent(window.[% sitename %]_title       || document.title);
    var src_query  = '?' + [style_attr, url_attr, title_attr].join('&');

    var dx=130, dy=25;
    if ( /^style=v/.test(style_attr) ) {
      dx=52;
      dy=80;
    }
    
    var iframe = '<iframe src="http://[% basedomain %]/badge.pl'+src_query+'"' +
                  ' height="' + dy + '" width="' + dx + '" scrolling="no" frameborder="0"></iframe>'
    document.write(iframe);
  }
)()
