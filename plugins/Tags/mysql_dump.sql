#
# $Id$
#

INSERT INTO vars (name, value, description) VALUES ('memcached_exptime_tags', '3600', 'Seconds to cache tag data in memcached');
INSERT INTO vars (name, value, description) VALUES ('tags_cache_expire', '180', 'Local data cache expiration for tags');
INSERT INTO vars (name, value, description) VALUES ('tags_tagname_regex', '^[a-z][a-z0-9/]{0,63}$', 'Regex that tag names must conform to');
INSERT INTO vars (name, value, description) VALUES ('tags_stories_allowread', '0', 'Who is allowed to see existing tags on stories (incl. search on them)? 0=nobody 1=admins 2=subscribers 3=non-neg. karma 4=all logged in');
INSERT INTO vars (name, value, description) VALUES ('tags_stories_allowwrite', '0', 'Who is allowed to tag stories? 0=nobody 1=admins 2=subscribers 3=non-neg. karma 4=all logged in');
INSERT INTO vars (name, value, description) VALUES ('tags_stories_lastscanned', '0', 'The last tagid scanned to update stories');
INSERT INTO vars (name, value, description) VALUES ('tags_stories_examples', 'cool dupe', 'Example tags for stories');

INSERT INTO reskey_resources (rkrid, name) VALUES (108, 'ajax_tags');
INSERT INTO reskey_resource_checks (rkrcid, rkrid, type, class, ordernum) VALUES (NULL, 108, 'all', 'Slash::ResKey::Checks::User', 101);

