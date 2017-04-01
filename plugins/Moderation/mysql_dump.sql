#
# $Id$
#

INSERT IGNORE INTO vars (name, value, description) VALUES ('m1', '1', 'Allows use of the moderation system');
REPLACE INTO vars (name, value, description) VALUES ('m1_pluginname', 'Moderation', 'Which moderation plugin to use');

DELETE FROM vars WHERE name='show_mods_with_comments';
INSERT IGNORE INTO vars (name, value, description) VALUES ('m1_admin_show_mods_with_comments', '1', 'Show moderations with comments for admins?');
INSERT IGNORE INTO vars (name, value, description) VALUES ('m1_eligible_hitcount','3','Number of hits on comments.pl before user can be considered eligible for moderation');
INSERT IGNORE INTO vars (name, value, description) VALUES ('m1_eligible_percentage','0.8','Percentage of users eligible to moderate');
INSERT IGNORE INTO vars (name, value, description) VALUES ('m1_pointgrant_end', '0.8888', 'Ending percentage into the pool of eligible moderators (used by moderatord)');
INSERT IGNORE INTO vars (name, value, description) VALUES ('m1_pointgrant_factor_upfairratio', '1.3', 'Factor of upmods fairness ratio in deciding who is eligible for moderation (1=irrelevant, 2=top user twice as likely)');
INSERT IGNORE INTO vars (name, value, description) VALUES ('m1_pointgrant_factor_downfairratio', '1.3', 'Factor of downmods fairness ratio in deciding who is eligible for moderation (1=irrelevant, 2=top user twice as likely)');
INSERT IGNORE INTO vars (name, value, description) VALUES ('m1_pointgrant_factor_fairtotal', '1.3', 'Factor of fairness total in deciding who is eligible for moderation (1=irrelevant, 2=top user twice as likely)');
INSERT IGNORE INTO vars (name, value, description) VALUES ('m1_pointgrant_factor_stirratio', '1.3', 'Factor of stirred-points ratio in deciding who is eligible for moderation (1=irrelevant, 2=top user twice as likely)');
INSERT IGNORE INTO vars (name, value, description) VALUES ('moderator_or_post', '1', 'Can users moderate and post in the same discussion (1=yes, 0=no)');

INSERT IGNORE INTO modreasons (id, name, m2able, listable, val, karma, fairfrac, ordered, needs_prior_mod) VALUES ( 0,  'Normal',        0, 0,  0,   0, 0.5,   0, 0);
INSERT IGNORE INTO modreasons (id, name, m2able, listable, val, karma, fairfrac, ordered, needs_prior_mod) VALUES ( 1,  'Offtopic',      1, 1, -1,  -1, 0.5,  10, 0);
INSERT IGNORE INTO modreasons (id, name, m2able, listable, val, karma, fairfrac, ordered, needs_prior_mod) VALUES ( 2,  'Flamebait',     1, 1, -1,  -1, 0.5,  12, 0);
INSERT IGNORE INTO modreasons (id, name, m2able, listable, val, karma, fairfrac, ordered, needs_prior_mod) VALUES ( 3,  'Troll',         1, 1, -1,  -1, 0.5,  13, 0);
INSERT IGNORE INTO modreasons (id, name, m2able, listable, val, karma, fairfrac, ordered, needs_prior_mod) VALUES ( 4,  'Redundant',     1, 1, -1,  -1, 0.5,  11, 0);
INSERT IGNORE INTO modreasons (id, name, m2able, listable, val, karma, fairfrac, ordered, needs_prior_mod) VALUES ( 5,  'Insightful',    1, 1,  1,   1, 0.5,   2, 0);
INSERT IGNORE INTO modreasons (id, name, m2able, listable, val, karma, fairfrac, ordered, needs_prior_mod) VALUES ( 6,  'Interesting',   1, 1,  1,   1, 0.5,   3, 0);
INSERT IGNORE INTO modreasons (id, name, m2able, listable, val, karma, fairfrac, ordered, needs_prior_mod) VALUES ( 7,  'Informative',   1, 1,  1,   1, 0.5,   4, 0);
INSERT IGNORE INTO modreasons (id, name, m2able, listable, val, karma, fairfrac, ordered, needs_prior_mod) VALUES ( 8,  'Funny',         1, 1,  1,   1, 0.5,   5, 0);
INSERT IGNORE INTO modreasons (id, name, m2able, listable, val, karma, fairfrac, ordered, needs_prior_mod) VALUES ( 9,  'Overrated',     0, 0, -1,   0, 0.5,   8, 1);
INSERT IGNORE INTO modreasons (id, name, m2able, listable, val, karma, fairfrac, ordered, needs_prior_mod) VALUES (10,  'Underrated',    0, 0,  1,   0, 0.5,   7, 1);
INSERT IGNORE INTO modreasons (id, name, m2able, listable, val, karma, fairfrac, ordered, needs_prior_mod) VALUES (11,  'Spam',          0, 1, -1, -10, 0.5, 101, 0);
INSERT IGNORE INTO modreasons (id, name, m2able, listable, val, karma, fairfrac, ordered, needs_prior_mod) VALUES (12,  'Disagree',      0, 1,  0,   0, 0.5,   9, 0);
INSERT IGNORE INTO modreasons (id, name, m2able, listable, val, karma, fairfrac, ordered, needs_prior_mod) VALUES (13,  'Touché',        0, 1,  1,   1, 0.5,   6, 0);
INSERT IGNORE INTO modreasons (id, name, m2able, listable, val, karma, fairfrac, ordered, needs_prior_mod) VALUES (100, '-----------',   0, 1,  1,   1, 0.5, 100, 0);
