INSERT INTO tagboxes (tbid, name, weight, last_run_completed, last_tagid_logged, last_tdid_logged, last_tuid_logged) VALUES (NULL, 'TagnameInterest', 1, '2000-01-01 00:00:00', 0, 0, 0);

INSERT INTO vars (name, value, description) VALUES ('tagbox_tni_initial_color', '5', 'Initial editor firehose color level for tagnames');
INSERT INTO vars (name, value, description) VALUES ('tagbox_tni_min_globjid', '2', 'Min num globjs necessary to put a tagname into the hose');
INSERT INTO vars (name, value, description) VALUES ('tagbox_tni_min_pop', '', 'Min firehose popularity to count about tagnames on (blank means use tags_active_mincare, default minpop for 5 aka blue)');
INSERT INTO vars (name, value, description) VALUES ('tagbox_tni_min_time', '14400', 'Min num seconds of timespan necessary to put a tagname into the hose');
INSERT INTO vars (name, value, description) VALUES ('tagbox_tni_min_total_count', '8', 'Min num total tags necessary to put a tagname into the hose');
INSERT INTO vars (name, value, description) VALUES ('tagbox_tni_min_total_clout', '8', 'Min sum of tags clout necessary to put a tagname into the hose');
INSERT INTO vars (name, value, description) VALUES ('tagbox_tni_min_uid', '3', 'Min num users necessary to put a tagname into the hose');
INSERT INTO vars (name, value, description) VALUES ('tagbox_tni_num_examples', '5', 'Number of example tags to list');
INSERT INTO vars (name, value, description) VALUES ('tagbox_tni_submitter_uid', '', 'Uid of user who submits tagname firehose entries, or blank for AC');

