# $Id$
INSERT INTO tagboxes (tbid, name, affected_type, clid, weight, last_run_completed, last_tagid_logged, last_tdid_logged, last_tuid_logged) VALUES (NULL, 'FHPopularity', 'globj', 2, 1, '2000-01-01 00:00:00', 0, 0, 0);
#INSERT INTO tagbox_userkeyregexes VALUES ('FHPopularity', '^tag_clout$');

INSERT IGNORE INTO vars (name, value, description) VALUES ('tagbox_fhpopularity_maybefrac', '1.0', 'Amount that an editor nod+maybe boosts popularity, expressed as fraction of a plain nod');

