alter table abusers add column reason varchar(60) not null default '';
alter table abusers add key reason(reason);
alter table abusers add column querystring varchar(120) not null default '';
alter table formkeys drop column comment_length;
alter table formkeys add column content_length int(4) NOT NULL DEFAULT 0;

