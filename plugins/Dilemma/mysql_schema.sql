#
# Table structure for table 'dilemma_species'
#

DROP TABLE IF EXISTS dilemma_species;
CREATE TABLE dilemma_species (
	dsid SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
	name CHAR(16) NOT NULL,
	uid MEDIUMINT UNSIGNED NOT NULL,
	code TEXT NOT NULL,
	births MEDIUMINT UNSIGNED DEFAULT 0 NOT NULL,
	deaths MEDIUMINT UNSIGNED DEFAULT 0 NOT NULL,
	rewardtotal FLOAT UNSIGNED DEFAULT 0 NOT NULL,
	contests MEDIUMINT UNSIGNED DEFAULT 0 NOT NULL,
	PRIMARY KEY (dsid),
	UNIQUE (name),
	KEY (uid)
) TYPE=InnoDB;

DROP TABLE IF EXISTS dilemma_agents;
CREATE TABLE dilemma_agents (
	daid INT UNSIGNED NOT NULL AUTO_INCREMENT,
	trid INT UNSIGNED NOT NULL,
	dsid SMALLINT UNSIGNED NOT NULL,
	alive ENUM("no", "yes") DEFAULT "yes" NOT NULL,
	born INT UNSIGNED DEFAULT 0 NOT NULL,
	food FLOAT DEFAULT 1.0 NOT NULL,
	memory BLOB NOT NULL,
	PRIMARY KEY (daid),
	KEY (dsid),
	KEY trid_alive (trid, alive)
) TYPE=InnoDB;

DROP TABLE IF EXISTS dilemma_tournament_info;
CREATE TABLE dilemma_tournament_info (
	trid INT UNSIGNED NOT NULL AUTO_INCREMENT,
	active ENUM("no", "yes") DEFAULT "yes" NOT NULL,
	max_tick INT UNSIGNED DEFAULT 1000 NOT NULL,
	last_tick INT UNSIGNED DEFAULT 0 NOT NULL,
	food_per_tick FLOAT UNSIGNED DEFAULT 1.0 NOT NULL,
	birth_food FLOAT UNSIGNED DEFAULT 10.0 NOT NULL,
	idle_food FLOAT UNSIGNED DEFAULT 0.05 NOT NULL,
	min_meets INT UNSIGNED DEFAULT 10 NOT NULL,
	max_meets INT UNSIGNED DEFAULT 30 NOT NULL,
	graph_drawn_tick INT UNSIGNED DEFAULT 0 NOT NULL,
	PRIMARY KEY (trid)
) TYPE=InnoDB;

# this will eventually store more interesting numbers than just name='num_alive','sumfood'
# and probably we need stats on an other-than-just-species basis
DROP TABLE IF EXISTS dilemma_stats;
CREATE TABLE dilemma_stats (
	trid INT UNSIGNED NOT NULL,
	tick INT UNSIGNED DEFAULT 0 NOT NULL,
	dsid SMALLINT UNSIGNED DEFAULT 0 NOT NULL,
	dstnmid SMALLINT UNSIGNED DEFAULT 0 NOT NULL,
	value FLOAT,
	UNIQUE ttdd (trid, tick, dsid, dstnmid),
	KEY tdd (trid, dsid, dstnmid)
) TYPE=InnoDB;

DROP TABLE IF EXISTS dilemma_stat_names;
CREATE TABLE dilemma_stat_names (
	dstnmid SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
	name CHAR(16) NOT NULL,
	PRIMARY KEY (dstnmid)
) TYPE=InnoDB;

DROP TABLE IF EXISTS dilemma_meetlog;
CREATE TABLE dilemma_meetlog (
	meetid INT UNSIGNED NOT NULL AUTO_INCREMENT,
	trid INT UNSIGNED NOT NULL,
	tick INT UNSIGNED NOT NULL,
	foodsize FLOAT UNSIGNED NOT NULL,
	PRIMARY KEY (meetid),
	KEY trid_tick (trid, tick)
) TYPE=InnoDB;

DROP TABLE IF EXISTS dilemma_playlog;
CREATE TABLE dilemma_playlog (
	meetid INT UNSIGNED NOT NULL,
	daid INT UNSIGNED NOT NULL,
	playtry FLOAT UNSIGNED NOT NULL,
	playactual FLOAT UNSIGNED NOT NULL,
	reward FLOAT NOT NULL,
	sawdaid INT UNSIGNED NOT NULL,
	UNIQUE meetid_daid (meetid, daid),
	KEY daid_meetid (daid, meetid)
) TYPE=InnoDB;

