#
# Table structure for table 'formkeys'
#
DROP TABLE IF EXISTS formkeys;
CREATE TABLE formkeys (
  formkey varchar(20) DEFAULT '' NOT NULL,
  formname varchar(20) DEFAULT '' NOT NULL,
  id varchar(20) DEFAULT '' NOT NULL,
  sid varchar(30) DEFAULT '' NOT NULL,
  uid int(1) DEFAULT '-1' NOT NULL,
  host_name varchar(30) DEFAULT '0.0.0.0' NOT NULL,
  value int(1) DEFAULT '0' NOT NULL,
  cid int(15) DEFAULT '0' NOT NULL,
  comment_length int(4) DEFAULT '0' NOT NULL,
  ts int(12) DEFAULT '0' NOT NULL,
  submit_ts int(12) DEFAULT '0' NOT NULL,
  PRIMARY KEY (formkey),
  KEY formname (formname),
  KEY id (id),
  KEY ts (ts),
  KEY submit_ts (submit_ts)
);

