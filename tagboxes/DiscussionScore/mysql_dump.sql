# $Id$
INSERT INTO tagboxes (tbid, name, affected_type, clid, weight, last_run_completed, last_tagid_logged, last_tdid_logged, last_tuid_logged) VALUES (NULL, 'DiscussionScore', 'globj', 3, 1, '2000-01-01 00:00:00', 0, 0, 0);

INSERT INTO vars (name, value, description) VALUES ('tagbox_ds_map', 'f4<-modserious', 'Map column names in comments table to tagname_param names. Key-value separator is <-, each pair space-separated');

