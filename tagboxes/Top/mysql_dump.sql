# $Id$
INSERT INTO tagboxes (tbid, name, affected_type, clid, weight, last_run_completed, last_tagid_logged, last_tdid_logged, last_tuid_logged) VALUES (NULL, 'Top', 'globj', 1, 1, '2000-01-01 00:00:00', 0, 0, 0);
INSERT INTO tagbox_userkeyregexes VALUES ('Top', '^tag_clout$');

INSERT IGNORE INTO vars (name, value, description) VALUES ('tagbox_top_minscore_stories', '2', 'Minimum score a tag must have to make it into the top tags for a story');
INSERT IGNORE INTO vars (name, value, description) VALUES ('tagbox_top_minscore_urls', '2', 'Minimum score a tag must have to make it into the top tags for a URL');

