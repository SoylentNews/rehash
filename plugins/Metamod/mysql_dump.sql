#
# $Id$
#

INSERT INTO vars (name, value, description) VALUES ('m2', '0', 'Allows use of the metamoderation system');
INSERT INTO vars (name, value, description) VALUES ('m2_batchsize', '300', 'Maximum number of moderations processed for M2 reconciliation per execution of moderation daemon.');
INSERT INTO vars (name, value, description) VALUES ('m2_comments','10','Number of comments for meta-moderation - if more than about 15, doublecheck that users_info.mods_saved is large enough');
INSERT INTO vars (name, value, description) VALUES ('m2_consensus', '9', 'Number of M2 votes per M1 before it is reconciled by consensus - if not odd, will be forced to next highest odd number');
INSERT INTO vars (name, value, description) VALUES ('m2_consensus_waitpow', '1', 'Positive real number, 0.2 to 5 is sensible. Between 0 and 1, older mods are chosen for M2 preferentially. Greater than 1, newer');
INSERT INTO vars (name, value, description) VALUES ('m2_consequences','0.00=0,+2,-100,-1|0.15=-2,+1,-40,-1|0.30=-0.5,+0.5,-20,0|0.35=0,0,-10,0|0.49=0,0,-4,0|0.60=0,0,+1,0|0.70=0,0,+2,0|0.80=+0.01,-1,+3,0|0.90=+0.02,-2,+4,0|1.00=+0.05,0,+5,+0.5','Rewards and penalties for M2ers and moderator, up to the given amount of fairness (0.0-1.0): numbers are 1, tokens to fair-voters, 2, tokens to unfair-voters, 3, tokens to moderator, and 4, karma to moderator');
INSERT INTO vars (name, value, description) VALUES ('m2_consequences_bonus_earlymod_secs', '1800', 'Fairly moderate a comment within this many seconds of its being posted and gain a token bonus');
INSERT INTO vars (name, value, description) VALUES ('m2_consequences_bonus_earlymod_tokenmult', '1.1', 'Fairly moderate a comment early, and gain this bonus multiplier');
INSERT INTO vars (name, value, description) VALUES ('m2_consequences_bonus_minfairfrac', '0.8', 'Fraction of Fair metamods a mod has to get for its user to be eligible for the m2 csq bonuses');
INSERT INTO vars (name, value, description) VALUES ('m2_consequences_bonus_pointsorig_-1', '1.1', 'Fairly moderate a comment from this score, and gain this bonus multiplier');
INSERT INTO vars (name, value, description) VALUES ('m2_consequences_bonus_pointsorig_0',  '1.2', 'Fairly moderate a comment from this score, and gain this bonus multiplier');
INSERT INTO vars (name, value, description) VALUES ('m2_consequences_bonus_pointsorig_1',  '1.1', 'Fairly moderate a comment from this score, and gain this bonus multiplier');
INSERT INTO vars (name, value, description) VALUES ('m2_consequences_bonus_pointsorig_2',  '1.0', 'Fairly moderate a comment from this score, and gain this bonus multiplier');
INSERT INTO vars (name, value, description) VALUES ('m2_consequences_bonus_pointsorig_3',  '0.8', 'Fairly moderate a comment from this score, and gain this bonus multiplier');
INSERT INTO vars (name, value, description) VALUES ('m2_consequences_bonus_pointsorig_4',  '0.5', 'Fairly moderate a comment from this score, and gain this bonus multiplier');
INSERT INTO vars (name, value, description) VALUES ('m2_consequences_bonus_pointsorig_5',  '0.8', 'Fairly moderate a comment from this score, and gain this bonus multiplier');
INSERT INTO vars (name, value, description) VALUES ('m2_consequences_bonus_quintile_1', '0.9', 'Fairly moderate a comment in the first 20% of a discussion and gain this bonus multiplier');
INSERT INTO vars (name, value, description) VALUES ('m2_consequences_bonus_quintile_2', '1.0', 'Fairly moderate a comment in the second 20% of a discussion and gain this bonus multiplier');
INSERT INTO vars (name, value, description) VALUES ('m2_consequences_bonus_quintile_3', '1.1', 'Fairly moderate a comment in the third 20% of a discussion and gain this bonus multiplier');
INSERT INTO vars (name, value, description) VALUES ('m2_consequences_bonus_quintile_4', '1.1', 'Fairly moderate a comment in the fourth 20% of a discussion and gain this bonus multiplier');
INSERT INTO vars (name, value, description) VALUES ('m2_consequences_bonus_quintile_5', '1.1', 'Fairly moderate a comment in the last 20% of a discussion and gain this bonus multiplier');
INSERT INTO vars (name, value, description) VALUES ('m2_consequences_bonus_replypost_tokenmult', '1.2', 'Fairly moderate a reply, instead of a top-level comment, and gain this bonus multiplier');
INSERT INTO vars (name, value, description) VALUES ('m2_consequences_repeats','3=-4|5=-12|10=-100','Token penalties for modding same user multiple times, applied at M2 reconcile time');
INSERT INTO vars (name, value, description) VALUES ('m2_consequences_token_max','25','Maximum number of tokens a user can have, for being on the consensus side of an M2 or being judged Fair, to merit gaining tokens');
INSERT INTO vars (name, value, description) VALUES ('m2_consequences_token_min','-999999','Minimum number of tokens a user must have, for being on the consensus side of an M2 to merit gaining tokens');
INSERT INTO vars (name, value, description) VALUES ('m2_freq','86400','In seconds, the maximum frequency which users can metamoderate');
INSERT INTO vars (name, value, description) VALUES ('m2_inherit', '0', 'Set to true if you would like to inherit m2s from previous mods with the same cid-reason');
INSERT INTO vars (name, value, description) VALUES ('m2_maxbonus_karma','12','Usually about half of goodkarma');
INSERT INTO vars (name, value, description) VALUES ('m2_min_daysbackcushion','2','The minimum days-back cushion');
INSERT INTO vars (name, value, description) VALUES ('m2_mintokens','0','The min M2 tokens');
INSERT INTO vars (name, value, description) VALUES ('m2_multicount', '5', 'Additional multiplier for M2s performed on duplicate mods (leave 0 to disable)');
INSERT INTO vars (name, value, description) VALUES ('m2_oldest_wanted', '10', 'How many days old can un-M2d mods get before they are considered important to get fully reconciled?');
INSERT INTO vars (name, value, description) VALUES ('m2_oldest_zone_percentile', '2', 'What percentile of the oldest un-M2d mods are to be considered highest priority?');
INSERT INTO vars (name, value, description) VALUES ('m2_oldest_zone_mult', '2', 'How many times the normal amount of M2s are applied to the oldest un-M2d mods?');
INSERT INTO vars (name, value, description) VALUES ('m2_oldzone', '0', 'Starting id (youngest) of the old-zone of moderations that still require M2 (the oldest certain percentile)');
INSERT INTO vars (name, value, description) VALUES ('m2_only_perdec', '10', 'What perdecage of mods should get M2d? 1=1/10th, 10=all');
INSERT INTO vars (name, value, description) VALUES ('m2_userpercentage','0.9','UID must be below this percentage of the total userbase to metamoderate');
INSERT INTO vars (name, value, description) VALUES ('m2_wait_hours','12','Number of hours to wait before a mod is available for m2');
