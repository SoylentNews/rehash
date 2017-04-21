
DROP TABLE IF EXISTS firehose;
DROP TABLE IF EXISTS firehose_ogaspt;
DROP TABLE IF EXISTS firehose_topics_rendered;
DROP TABLE IF EXISTS firehose_text;
DROP TABLE IF EXISTS firehose_section;
DROP TABLE IF EXISTS firehose_section_settings;
DROP TABLE IF EXISTS firehose_tab;
DROP TABLE IF EXISTS firehose_view;
DROP TABLE IF EXISTS firehose_view_settings;
DROP TABLE IF EXISTS firehose_update_log;
DROP TABLE IF EXISTS firehose_setting_log;
DROP TABLE IF EXISTS firehose_skin_volume;

DROP TABLE IF EXISTS tag_params;
DROP TABLE IF EXISTS tagboxes;
DROP TABLE IF EXISTS tagboxlog_feeder;
DROP TABLE IF EXISTS tagcommand_adminlog;
DROP TABLE IF EXISTS tagcommand_adminlog_sfnet;
DROP TABLE IF EXISTS tagname_cache;
DROP TABLE IF EXISTS tagname_params;
DROP TABLE IF EXISTS tagnames;
DROP TABLE IF EXISTS tagnames_similarity_rendered;
DROP TABLE IF EXISTS tagnames_synonyms_chosen;
DROP TABLE IF EXISTS tags    ;
DROP TABLE IF EXISTS tags_dayofweek;
DROP TABLE IF EXISTS tags_deactivated;
DROP TABLE IF EXISTS tags_hourofday;
DROP TABLE IF EXISTS tags_peerweight;
DROP TABLE IF EXISTS tags_searched;
DROP TABLE IF EXISTS tags_udc;
DROP TABLE IF EXISTS tags_userchange;

DROP TABLE IF EXISTS globjs_viewed;
DROP TABLE IF EXISTS globjs_viewed_archived;

DELETE FROM vars WHERE name LIKE '%firehose%';
DELETE FROM vars WHERE name LIKE 'tags%';
DELETE FROM vars WHERE name LIKE 'memcache%tags%';
DELETE FROM globj_types WHERE maintable = 'tagnames';
