INSERT INTO tagboxes (tbid, name, weight, last_run_completed, last_tagid_logged, last_tdid_logged, last_tuid_logged) VALUES (NULL, 'CommentScoreReason', 1, '2000-01-01 00:00:00', 0, 0, 0);

INSERT INTO vars (name, value, description) VALUES ('tagbox_csr_baseneediness', '60', 'Base neediness score for comments that have been moderated');
INSERT INTO vars (name, value, description) VALUES ('tagbox_csr_minneediness', '138', 'Minimum neediness score to possibly insert a needy comment into the firehose');
INSERT INTO vars (name, value, description) VALUES ('tagbox_csr_needinesspercent', '5', 'Percentage of comments with the necessary minimum neediness which actually do get inserted into the firehose');

