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
	dsid SMALLINT UNSIGNED NOT NULL,
	alive ENUM("no", "yes") DEFAULT "yes" NOT NULL,
	born INT UNSIGNED DEFAULT 0 NOT NULL,
	food FLOAT DEFAULT 1.0 NOT NULL,
	memory BLOB NOT NULL,
	PRIMARY KEY (daid),
	KEY (dsid),
	KEY (alive)
) TYPE=InnoDB;

# this will eventually be a "tournaments" table with multiple rows
DROP TABLE IF EXISTS dilemma_info;
CREATE TABLE dilemma_info (
	alive ENUM("no", "yes") DEFAULT "yes" NOT NULL,
	max_runtime INT UNSIGNED DEFAULT 100 NOT NULL,
	last_tick INT UNSIGNED DEFAULT 0 NOT NULL,
	food_per_time FLOAT UNSIGNED DEFAULT 1.0 NOT NULL,
	birth_food FLOAT UNSIGNED DEFAULT 10.0 NOT NULL,
	idle_food FLOAT UNSIGNED DEFAULT 0.05 NOT NULL,
	mean_meets INT UNSIGNED DEFAULT 20 NOT NULL
) TYPE=InnoDB;

# this will eventually have a column for tournament ID
# and store more interesting numbers than just name='num_alive','sumfood'
DROP TABLE IF EXISTS dilemma_stats;
CREATE TABLE dilemma_stats (
	tick INT UNSIGNED NOT NULL,
	dsid SMALLINT UNSIGNED NOT NULL,
	name CHAR(16) NOT NULL,
	value FLOAT,
	UNIQUE (tick, dsid, name),
	KEY (dsid, name)
) TYPE=InnoDB;

DROP TABLE IF EXISTS dilemma_meetlog;
CREATE TABLE dilemma_meetlog (
	meetid INT UNSIGNED NOT NULL AUTO_INCREMENT,
	tick INT UNSIGNED NOT NULL,
	foodsize FLOAT UNSIGNED NOT NULL,
	PRIMARY KEY (meetid),
	KEY tick (tick)
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

