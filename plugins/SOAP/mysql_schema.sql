DROP TABLE IF EXISTS soap_methods;
CREATE TABLE soap_methods (
        id MEDIUMINT(5) UNSIGNED NOT NULL AUTO_INCREMENT,
        class VARCHAR(100) NOT NULL,
        method VARCHAR(100) NOT NULL,
        seclev MEDIUMINT DEFAULT 1000 NOT NULL,
        subscriber_only TINYINT DEFAULT 0 NOT NULL,
        formkeys VARCHAR(255) DEFAULT '' NOT NULL,
        PRIMARY KEY (id),
        UNIQUE soap_method(class, method)
);
