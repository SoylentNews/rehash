# MySQL dump 6.0
#
# Host: localhost    Database: slash
#--------------------------------------------------------
# Server version        3.22.25

#
# Alter table structure for table 'blocks'
#

ALTER TABLE blocks add column type varchar(20) DEFAULT '' NOT NULL;
ALTER TABLE blocks add column description text;
ALTER TABLE blocks add key type (type);

  
#
# Table structure for table 'commentkey'
#

CREATE TABLE commentkey (
  formkey varchar(20) DEFAULT '' NOT NULL,
  sid varchar(30) DEFAULT '' NOT NULL,
  uid int(1) DEFAULT '-1' NOT NULL,
  host_name varchar(30),
  ts varchar(20) DEFAULT '0' NOT NULL,
  value int(1) DEFAULT '0' NOT NULL,
  cid int(15) DEFAULT '0' NOT NULL,
  submit_ts varchar(20) DEFAULT '0',
  comment_length int(4) DEFAULT '0' NOT NULL,
  PRIMARY KEY (formkey),
  KEY sid (sid),
  KEY id (sid,cid),
  KEY uid (uid)
);


#
# Table structure for table 'content_filters'
#

CREATE TABLE content_filters (
  filter_id int(4) DEFAULT '0' NOT NULL auto_increment,
  regex varchar(100) DEFAULT '' NOT NULL,
  modifier varchar(5) DEFAULT '' NOT NULL,
  field varchar(20) DEFAULT '' NOT NULL,
  ratio float(6,4) DEFAULT '0.0000' NOT NULL,
  minimum_match int(6) DEFAULT '0' NOT NULL,
  minimum_length int(10) DEFAULT '0' NOT NULL,
  err_message varchar(150) DEFAULT '',
  maximum_length int(10) DEFAULT '0' NOT NULL,
  PRIMARY KEY (filter_id),
  KEY regex (regex),
  KEY field (field)
);

 
#
# Table structure for table 'metamodlog'
#

CREATE TABLE metamodlog (
  mmid int(11) DEFAULT '0' NOT NULL,
  uid int(11) DEFAULT '0' NOT NULL,
  val int(11) DEFAULT '0' NOT NULL,
  ts datetime,
  id int(11) DEFAULT '0' NOT NULL auto_increment,
  PRIMARY KEY (id)
);

