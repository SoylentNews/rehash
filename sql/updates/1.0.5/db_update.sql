ALTER TABLE formkeys MODIFY column id varchar(30) NOT NULL DEFAULT '';
ALTER TABLE formkeys MODIFY column uid int(11) NOT NULL DEFAULT -1;
ALTER TABLE abusers ADD column reason varchar(60) not null default '';
ALTER TABLE abusers ADD key reason(reason);
ALTER TABLE abusers ADD column querystring varchar(120) not null default '';
ALTER TABLE formkeys DROP column comment_length;
ALTER TABLE formkeys ADD column content_length int(4) NOT NULL DEFAULT 0;

