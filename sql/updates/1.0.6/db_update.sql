ALTER TABLE moderatorlog ADD column active int(1) not null DEFAULT 1;
ALTER TABLE users_info ADD column m2fair int not null DEFAULT 0;
ALTER TABLE users_info ADD column m2unfair int not null DEFAULT 0;
ALTER TABLE users_info ADD column m2fairvotes int not null DEFAULT 0;
ALTER TABLE users_info ADD column m2unfairvotes int not null DEFAULT 0;
ALTER TABLE metamodlog ADD column flag int(2) not null DEFAULT 0;

