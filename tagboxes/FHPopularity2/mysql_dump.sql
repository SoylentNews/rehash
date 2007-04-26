# $Id$
INSERT INTO tagboxes (tbid, name, affected_type, weight, last_run_completed, last_tagid_logged, last_tdid_logged, last_tuid_logged) VALUES (NULL, 'FHPopularity2', 'globj', 1, '2000-01-01 00:00:00', 0, 0, 0);
#INSERT INTO tagbox_userkeyregexes VALUES ('FHPopularity2', '^tag_clout$');

INSERT IGNORE INTO vars (name, value, description) VALUES ('tagbox_fhpopularity_maxudcmult', '5', 'Maximum multiplier for an up/down tag based on the tags_udc table');

