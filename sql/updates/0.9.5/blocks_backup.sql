alter table blocks add column blockbak text;
update blocks set blockbak = block;

