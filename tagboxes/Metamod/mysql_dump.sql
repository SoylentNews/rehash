INSERT INTO tagboxes (tbid, name, affected_type, clid, weight, last_run_completed, last_tagid_logged, last_tdid_logged, last_tuid_logged) VALUES (NULL, 'Metamod', 'globj', 3, 1, '2000-01-01 00:00:00', 0, 0, 0);

INSERT IGNORE INTO vars (name, value, description) VALUES ('tagbox_metamod_adminmult', '10', 'Admin metamods count as this many regular-user metamods');
INSERT IGNORE INTO vars (name, value, description) VALUES ('tagbox_metamod_modfrac', '0.1', 'A mod counts as this much of a metamod for purposes of determining consensus');

