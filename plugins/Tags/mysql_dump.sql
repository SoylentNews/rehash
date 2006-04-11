#
# $Id$
#

INSERT INTO vars (name, value, description) VALUES ('memcached_exptime_tags', '3600', 'Seconds to cache tag data in memcached');
INSERT INTO vars (name, value, description) VALUES ('tags_cache_expire', '180', 'Local data cache expiration for tags');
INSERT INTO vars (name, value, description) VALUES ('tags_stories_allowread', '0', 'Who is allowed to see existing tags on stories (incl. search on them)? 0=nobody 1=admins 2=subscribers 3=non-neg. karma 4=all logged in');
INSERT INTO vars (name, value, description) VALUES ('tags_stories_allowwrite', '0', 'Who is allowed to tag stories? 0=nobody 1=admins 2=subscribers 3=non-neg. karma 4=all logged in');
INSERT INTO vars (name, value, description) VALUES ('tags_stories_examples_pre', 'dupe typo', 'Example tags for stories');
INSERT INTO vars (name, value, description) VALUES ('tags_stories_examples', '', 'Example tags for stories');
INSERT INTO vars (name, value, description) VALUES ('tags_stories_lastscanned', '0', 'The last tagid scanned to update stories');
INSERT INTO vars (name, value, description) VALUES ('tags_stories_top_minscore', '2', 'Minimum score a tag must have to make it into the top tags for a story');
INSERT INTO vars (name, value, description) VALUES ('tags_urls_examples_pre', 'plus minus binspam', 'Example tags for urls');
INSERT INTO vars (name, value, description) VALUES ('tags_urls_examples', '', 'Example tags for urls');
INSERT INTO vars (name, value, description) VALUES ('tags_urls_lastscanned', '0', 'The last tagid scanned to update urls');
INSERT INTO vars (name, value, description) VALUES ('tags_urls_top_minscore', '2', 'Minimum score a tag must have to make it into the top tags for a urls');
INSERT INTO vars (name, value, description) VALUES ('tags_reduced_tag_clout', '0.5', 'Reduced clout of tags');
INSERT INTO vars (name, value, description) VALUES ('tags_reduced_user_clout', '0.5', 'Reduced clout of user applied tags');
INSERT INTO vars (name, value, description) VALUES ('tags_tagname_regex', '^\!?[a-z][a-z0-9/]{0,63}$', 'Regex that tag names must conform to');

INSERT INTO ajax_ops VALUES (NULL, 'tags_get_user_story', 'Slash::Tags', 'ajaxGetUserStory', 'ajax_tags_write', 'createuse');
INSERT INTO ajax_ops VALUES (NULL, 'tags_get_user_urls', 'Slash::Tags', 'ajaxGetUserUrls', 'ajax_tags_write', 'createuse');
INSERT INTO ajax_ops VALUES (NULL, 'tags_create_for_story', 'Slash::Tags', 'ajaxCreateForStory', 'ajax_tags_write', 'use');
INSERT INTO ajax_ops VALUES (NULL, 'tags_create_for_url', 'Slash::Tags', 'ajaxCreateForUrl', 'ajax_tags_write', 'use');
INSERT INTO ajax_ops VALUES (NULL, 'tags_get_admin_story', 'Slash::Tags', 'ajaxGetAdminStory', 'ajax_admin', 'createuse');
INSERT INTO ajax_ops VALUES (NULL, 'tags_get_admin_url', 'Slash::Tags', 'ajaxGetAdminUrl', 'ajax_admin', 'createuse');
INSERT INTO ajax_ops VALUES (NULL, 'tags_admin_commands', 'Slash::Tags', 'ajaxProcessAdminTags', 'ajax_admin', 'use');
INSERT INTO ajax_ops VALUES (NULL, 'tags_history', 'Slash::Tags', 'ajaxTagHistory', 'ajax_admin', 'createuse');

INSERT INTO menus VALUES (NULL, 'tagszg', 'Active', 'active', '[% gSkin.rootdir %]/tags',        1, 1, 1);
INSERT INTO menus VALUES (NULL, 'tagszg', 'Recent', 'recent', '[% gSkin.rootdir %]/tags/recent', 1, 1, 2);
INSERT INTO menus VALUES (NULL, 'tagszg', 'All',    'all',    '[% gSkin.rootdir %]/tags/all',    1, 1, 3);

