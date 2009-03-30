INSERT INTO achievements (name, description, repeatable, increment) VALUES ('story_posted', 'Posted a Story', 'yes', 2);
INSERT INTO achievements (name, description, repeatable, increment) VALUES ('comment_posted', 'Posted a Comment', 'no', 0);
INSERT INTO achievements (name, description, repeatable, increment) VALUES ('journal_posted', 'Posted a Journal Entry', 'no', 0);
INSERT INTO achievements (name, description, repeatable, increment) VALUES ('achievement_obtained', 'Achievements', 'yes', 1);
INSERT INTO achievements (name, description, repeatable, increment) VALUES ('mod_points_exhausted', 'Spent All My Mod Points', 'no', 0);
INSERT INTO achievements (name, description, repeatable, increment) VALUES ('score5_comment', 'Got a Score:5 Comment', 'yes', 2);
INSERT INTO achievements (name, description, repeatable, increment) VALUES ('story_accepted', 'Submitted a Story That Was Posted', 'yes', 2);
INSERT INTO achievements (name, description, repeatable, increment) VALUES ('consecutive_days_read', 'Days Read in a Row', 'yes', 2);
INSERT INTO achievements (name, description, repeatable, increment) VALUES ('consecutive_days_metamod', 'Days Metamoderated in a Row', 'yes', 2);
INSERT INTO achievements (name, description, repeatable, increment) VALUES ('the_tagger', 'The Tagger', 'no', 0);
INSERT INTO achievements (name, description, repeatable, increment) VALUES ('the_contradictor', 'The Contradictor', 'no', 0);
INSERT INTO achievements (name, description, repeatable, increment) VALUES ('1_uid_club', 'Member of the 1 Digit UID Club', 'yes', 1);
INSERT INTO achievements (name, description, repeatable, increment) VALUES ('2_uid_club', 'Member of the 2 Digit UID Club', 'yes', 1);
INSERT INTO achievements (name, description, repeatable, increment) VALUES ('3_uid_club', 'Member of the 3 Digit UID Club', 'yes', 1);
INSERT INTO achievements (name, description, repeatable, increment) VALUES ('4_uid_club', 'Member of the 4 Digit UID Club', 'yes', 1);
INSERT INTO achievements (name, description, repeatable, increment) VALUES ('5_uid_club', 'Member of the 5 Digit UID Club', 'yes', 1);
INSERT INTO achievements (name, description, repeatable, increment) VALUES ('the_maker', 'The Maker', 'no', 0);
INSERT INTO achievements (name, description, repeatable, increment) VALUES ('comedian', 'Comedian', 'no', 0);
INSERT INTO achievements (name, description, repeatable, increment) VALUES ('april_fool', 'The April Fool', 'no', 0);
INSERT INTO achievements (name, description, repeatable, increment) VALUES ('comment_upmodded', 'Had a Comment Modded Up', 'no', 0);

INSERT INTO ajax_ops VALUES (NULL, 'enable_maker_adless', 'Slash::Achievement', 'ajaxEnableMakerAdless', 'ajax_user', 'createuse');
INSERT INTO vars (name, value, description) VALUES ('ach_maker_adlesstime', '259200', 'After a maker_mode user turns off ads, how long does the adless state persist, in seconds');

