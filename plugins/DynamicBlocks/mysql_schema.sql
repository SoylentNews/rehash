DROP TABLE IF EXISTS dynamic_blocks;
CREATE TABLE dynamic_blocks (
  type_id tinyint(1) unsigned NOT NULL default '0',
  type enum('portal','admin','user') NOT NULL default 'user',
  private enum('yes','no') NOT NULL default 'no',
  PRIMARY KEY  (type_id)
) ENGINE=InnoDB;

DROP TABLE IF EXISTS dynamic_user_blocks;
CREATE TABLE dynamic_user_blocks (
  bid mediumint(8) unsigned NOT NULL auto_increment,
  portal_id mediumint(8) unsigned NOT NULL default '0',
  type_id tinyint(1) unsigned NOT NULL default '0',
  uid mediumint(8) unsigned NOT NULL default '0',
  title varchar(64) NOT NULL default '',
  url varchar(128) NOT NULL default '',
  name varchar(30) NOT NULL default '',
  description varchar(64) NOT NULL default '',
  block text,
  seclev mediumint(8) unsigned NOT NULL default '0',
  created datetime NOT NULL default '0000-00-00 00:00:00',
  last_update datetime NOT NULL default '0000-00-00 00:00:00',
  PRIMARY KEY (bid),
  UNIQUE KEY name (name),
  UNIQUE KEY idx_uid_name (uid, name),
  KEY idx_typeid (type_id),
  KEY idx_portalid (portal_id)
) ENGINE=InnoDB;
