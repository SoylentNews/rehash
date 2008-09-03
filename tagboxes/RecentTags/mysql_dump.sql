INSERT INTO tagboxes (tbid, name, weight, last_run_completed, last_tagid_logged, last_tdid_logged, last_tuid_logged) VALUES (NULL, 'RecentTags', 1, '2000-01-01 00:00:00', 0, 0, 0);

INSERT IGNORE INTO vars (name, value, description) VALUES ('tagbox_recenttags_secondsback', '7200', 'Number of seconds to look back');
INSERT IGNORE INTO vars (name, value, description) VALUES ('tagbox_recenttags_minclout', '4', 'Minimum clout sum to count a tagname');
INSERT IGNORE INTO vars (name, value, description) VALUES ('tagbox_recenttags_minslice', '4', 'Minimum slice number to count tags on');
INSERT IGNORE INTO vars (name, value, description) VALUES ('tagbox_recenttags_num', '5', 'Number of recent tags to list');

