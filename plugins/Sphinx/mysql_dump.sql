INSERT INTO dbs (id, virtual_user, isalive, type, weight, weight_adjust) VALUES (NULL, 'sphinx01', 'yes', 'sphinx', 1, 1);

INSERT INTO vars (name, value, description) VALUES ('sphinx', '0', 'Is Sphinx installed?');
INSERT INTO vars (name, value, description) VALUES ('sphinx_01_vardir', '/srv/sphinx/var', 'The path to the var directory for the sphinx01 instance');
INSERT INTO vars (name, value, description) VALUES ('sphinx_01_hostname', '', 'Hostname for the sphinx01 instance');
INSERT INTO vars (name, value, description) VALUES ('sphinx_01_port', '3312', 'Port the sphinx01 instance listens on');

