#
# $Id$
#

INSERT INTO vars (name, value, description) VALUES ('memcached_exptime_tags', '3600', 'Seconds to cache tag data in memcached');
INSERT INTO vars (name, value, description) VALUES ('memcached_exptime_tags_brief', '300', 'Seconds to cache tag data that only needs brief caching, in memcached');
INSERT INTO vars (name, value, description) VALUES ('tags_admin_private_tags', '', 'List of tags separated by | that are private for admins');
INSERT INTO vars (name, value, description) VALUES ('tags_admin_autoaddstorytopics', '1', 'Auto-add tags for story topic keywords?');
INSERT INTO vars (name, value, description) VALUES ('tags_cache_expire', '180', 'Local data cache expiration for tags');
INSERT INTO vars (name, value, description) VALUES ('tags_list_mintc', '4', 'Minimum value of total_clout for tagged items shown at /tags/foo');
INSERT INTO vars (name, value, description) VALUES ('tags_prefixlist_minc', '4', 'Minimum value of c (count) for tagnames returned by listTagnamesByPrefix');
INSERT INTO vars (name, value, description) VALUES ('tags_prefixlist_mins', '3', 'Minimum value of s (clout sum) for tagnames returned by listTagnamesByPrefix');
INSERT INTO vars (name, value, description) VALUES ('tags_prefixlist_num', '10', 'Number of tagnames returned by listTagnamesByPrefix');
INSERT INTO vars (name, value, description) VALUES ('tags_prefixlist_priority', 'back bookmark feed hold journal none quik submission story', 'Tagnames to give priority to on autocomplete');
INSERT INTO vars (name, value, description) VALUES ('tags_prefixlist_priority_score', '999', 'Fake score to give any tagnames from tags_autocomplete_priority which may match a prefix');
INSERT INTO vars (name, value, description) VALUES ('tags_stories_allowread', '0', 'Who is allowed to see existing tags on stories (incl. search on them)? 0=nobody 1=admins 2=subscribers 2.5=tags_stories_allowread ACL 3=non-neg. karma 4=all logged in (3,4: up to tags_userfrac_read)');
INSERT INTO vars (name, value, description) VALUES ('tags_stories_allowwrite', '0', 'Who is allowed to tag stories? 0=nobody 1=admins 2=subscribers 2.5=tags_stories_allowwrite ACL 3=non-neg. karma 4=all logged in (3,4: up to tags_userfrac_write)');
INSERT INTO vars (name, value, description) VALUES ('tags_stories_examples_pre', 'dupe typo', 'Example tags for stories before they go live');
INSERT INTO vars (name, value, description) VALUES ('tags_stories_examples', '', 'Example tags for stories');
INSERT INTO vars (name, value, description) VALUES ('tags_stories_lastscanned', '0', 'The last tagid scanned to update stories');
INSERT INTO vars (name, value, description) VALUES ('tags_stories_top_minscore', '2', 'Minimum score a tag must have to make it into the top tags for a story');
INSERT INTO vars (name, value, description) VALUES ('tags_udc_daysback', '182', 'Days back to crunch numbers for tags_udc related tables, should be a multiple of 7');
INSERT INTO vars (name, value, description) VALUES ('tags_urls_examples_pre', 'plus minus binspam', 'Example tags for urls');
INSERT INTO vars (name, value, description) VALUES ('tags_urls_examples', '', 'Example tags for urls');
INSERT INTO vars (name, value, description) VALUES ('tags_urls_lastscanned', '0', 'The last tagid scanned to update urls');
INSERT INTO vars (name, value, description) VALUES ('tags_urls_top_minscore', '2', 'Minimum score a tag must have to make it into the top tags for a urls');
INSERT INTO vars (name, value, description) VALUES ('tags_urls_pos_tags', 'plus', '| separated list of tags applied which positively affect url popularity');
INSERT INTO vars (name, value, description) VALUES ('tags_urls_neg_tags', 'minus|binspam', '| separated list of tags applied which negatively affect url popularity');
INSERT INTO vars (name, value, description) VALUES ('tags_usecloutfield', '', 'Use a users_param field for clout? Leave empty to use users_info.tag_clout times some simple multipliers');
INSERT INTO vars (name, value, description) VALUES ('tags_usecloutfield_default', '', 'If empty string, then users with no tags_usecloutfield param use the old formula based on karma. If number, then those users use this number. If tags_usecloutfield not defined, leave this the empty string.');
INSERT INTO vars (name, value, description) VALUES ('tags_usecloutfield_mult', '1.0', 'Multiply the users_param field by this');
INSERT INTO vars (name, value, description) VALUES ('tags_userfrac_read', '1', 'Fraction (0.0-1.0) of user UIDs which are allowed to read tags, if tags_*_allow* is set that way');
INSERT INTO vars (name, value, description) VALUES ('tags_userfrac_write', '0.95', 'Fraction (0.0-1.0) of user UIDs which are allowed to tag, if tags_*_allow* is set that way');
INSERT INTO vars (name, value, description) VALUES ('tags_tagname_regex', '^\!?[a-z][a-z0-9/]{0,63}$', 'Regex that tag names must conform to');
INSERT INTO vars (name, value, description) VALUES ('tags_upvote_tagname', 'nod', 'Tag for upvote');
INSERT INTO vars (name, value, description) VALUES ('tags_downvote_tagname', 'nix', 'Tag for downvote');
INSERT INTO vars (name, value, description) VALUES ('tags_negative_tagnames', 'nix,dupe,whocares', 'Negative tags (comma separated)');

INSERT INTO ajax_ops VALUES (NULL, 'tags_get_user_story', 'Slash::Tags', 'ajaxGetUserStory', 'ajax_tags_write', 'createuse');
INSERT INTO ajax_ops VALUES (NULL, 'tags_get_user_urls', 'Slash::Tags', 'ajaxGetUserUrls', 'ajax_tags_write', 'createuse');
INSERT INTO ajax_ops VALUES (NULL, 'tags_create_for_story', 'Slash::Tags', 'ajaxCreateForStory', 'ajax_tags_write', 'use');
INSERT INTO ajax_ops VALUES (NULL, 'tags_create_for_url', 'Slash::Tags', 'ajaxCreateForUrl', 'ajax_tags_write', 'use');
INSERT INTO ajax_ops VALUES (NULL, 'tags_get_admin_story', 'Slash::Tags', 'ajaxGetAdminStory', 'ajax_admin', 'createuse');
INSERT INTO ajax_ops VALUES (NULL, 'tags_get_admin_url', 'Slash::Tags', 'ajaxGetAdminUrl', 'ajax_admin', 'createuse');
INSERT INTO ajax_ops VALUES (NULL, 'tags_admin_commands', 'Slash::Tags', 'ajaxProcessAdminTags', 'ajax_admin', 'use');
INSERT INTO ajax_ops VALUES (NULL, 'tags_history', 'Slash::Tags', 'ajaxTagHistory', 'ajax_admin', 'createuse');
INSERT INTO ajax_ops VALUES (NULL, 'tags_list_tagnames', 'Slash::Tags', 'ajaxListTagnames', 'ajax_tags_read', 'createuse');

INSERT INTO menus VALUES (NULL, 'tagszg', 'Active', 'active', '[% gSkin.rootdir %]/tags',        1, 1, 1);
INSERT INTO menus VALUES (NULL, 'tagszg', 'Recent', 'recent', '[% gSkin.rootdir %]/tags/recent', 1, 1, 2);
INSERT INTO menus VALUES (NULL, 'tagszg', 'All',    'all',    '[% gSkin.rootdir %]/tags/all',    1, 1, 3);

#INSERT INTO tagboxes VALUES (NULL, 'tag_count', 'user', '1.0', 0, NULL);

