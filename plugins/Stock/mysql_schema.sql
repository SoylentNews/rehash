DROP TABLE IF EXISTS stocks;
CREATE TABLE stocks (
  name varchar(40) NOT NULL DEFAULT '',
  stockorder INT NOT NULL DEFAULT 0,
  exchange varchar(20) NOT NULL DEFAULT '',
  symbol varchar(10) NOT NULL DEFAULT '',
  url varchar(255) NOT NULL DEFAULT '',
  PRIMARY KEY (name),
  UNIQUE ex_sym (exchange,symbol)
) TYPE=MyISAM;
