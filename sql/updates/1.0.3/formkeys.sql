# MySQL dump 7.1
#
# Host: localhost    Database: slashdot
#--------------------------------------------------------
# Server version	3.22.32

#
# Table structure for table 'formkeys'
#
CREATE TABLE formkeys (
  formkey varchar(20) DEFAULT '' NOT NULL,
  formname varchar(20) DEFAULT '' NOT NULL,
  sid varchar(30) DEFAULT '' NOT NULL,
  uid int(1) DEFAULT '-1' NOT NULL,
  host_name varchar(30),
  ts varchar(20) DEFAULT '0' NOT NULL,
  value int(1) DEFAULT '0' NOT NULL,
  cid int(15) DEFAULT '0' NOT NULL,
  submit_ts varchar(20) DEFAULT '0',
  comment_length int(4) DEFAULT '0' NOT NULL,
  PRIMARY KEY (formkey),
  KEY formname (formname),
  KEY sid (sid),
  KEY id (sid,cid),
  KEY uid (uid)
);

