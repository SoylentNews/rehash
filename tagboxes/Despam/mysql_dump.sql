INSERT INTO tagboxes (tbid, name, weight, last_run_completed, last_tagid_logged, last_tdid_logged, last_tuid_logged) VALUES (NULL, 'Despam', 1, '2000-01-01 00:00:00', 0, 0, 0);

INSERT IGNORE INTO vars (name, value, description) VALUES ('tagbox_despam_binspamsallowed', '1', 'Number of binspam tags allowed before action is taken');
INSERT IGNORE INTO vars (name, value, description) VALUES ('tagbox_despam_binspamsallowed_ip', '3', 'Number of binspam tags allowed before action is taken for an IP');
INSERT IGNORE INTO vars (name, value, description) VALUES ('tagbox_despam_decloutdaysback', '7', 'Number of days to look back to declout upvoters');
INSERT IGNORE INTO vars (name, value, description) VALUES ('tagbox_despam_ipdayslookback', '60', 'Number of days to look back in tables to mark IPs, 0 disables IP marking');
INSERT IGNORE INTO vars (name, value, description) VALUES ('tagbox_despam_upvotermaxclout', '0.85', 'Maximum tag_clout for any user who upvotes a submission from a spammer user');
INSERT IGNORE INTO vars (name, value, description) VALUES ('tagbox_despam_al2adminuid', '1', 'Admin uid when setting AL2');

