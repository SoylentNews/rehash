INSERT INTO tagboxes (tbid, name, weight, last_run_completed, last_tagid_logged, last_tdid_logged, last_tuid_logged) VALUES (NULL, 'Top', 1, '2000-01-01 00:00:00', 0, 0, 0);

INSERT IGNORE INTO vars (name, value, description) VALUES ('tagbox_top_minscore_stories', '2', 'Minimum score a tag must have to make it into the top tags for a story');
INSERT IGNORE INTO vars (name, value, description) VALUES ('tagbox_top_minscore_urls', '2', 'Minimum score a tag must have to make it into the top tags for a URL');

