
SELECT @theme_ctid := ctid FROM css_type where name="theme";
INSERT INTO css (rel, type, media, file, title, skin, page, admin, theme, ctid, ordernum, ie_cond, lowbandwidth) VALUES ('stylesheet','text/css','screen, projection','ostgnavbar.css','','','','no','',@theme_ctid,0,'',"no");

