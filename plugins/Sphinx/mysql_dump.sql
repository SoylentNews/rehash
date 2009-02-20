INSERT INTO dbs (id, virtual_user, isalive, type, weight, weight_adjust) VALUES (NULL, 'sphinx01', 'yes', 'sphinx', 1, 1);

INSERT INTO vars (name, value, description) VALUES ('sphinx', '0', 'Is Sphinx installed?');
INSERT INTO vars (name, value, description) VALUES ('sphinx_01_hostname_searchd', '', 'Hostname for the sphinx01 instance: searchd');
INSERT INTO vars (name, value, description) VALUES ('sphinx_01_hostname_sphinxse', '', 'Hostname for the sphinx01 instance: SphinxSE on mysqld');
INSERT INTO vars (name, value, description) VALUES ('sphinx_01_max_children', '100', 'max_children value for the sphinx01 searchd');
INSERT INTO vars (name, value, description) VALUES ('sphinx_01_max_iops', '40', 'max_iops value for the sphinx01 indexer');
INSERT INTO vars (name, value, description) VALUES ('sphinx_01_max_matches', '10000', 'max_matches value for the sphinx01 searchd');
INSERT INTO vars (name, value, description) VALUES ('sphinx_01_mem_limit', '512M', 'mem_limit value for the sphinx01 indexer');
INSERT INTO vars (name, value, description) VALUES ('sphinx_01_port', '3312', 'Port the sphinx01 instance listens on');
INSERT INTO vars (name, value, description) VALUES ('sphinx_01_vardir', '/srv/sphinx/var', 'The path to the var directory for the sphinx01 instance');
INSERT INTO vars (name, value, description) VALUES ('sphinx_stopwords', 'the to of and http in that is com for www it on with this be as you are an writes has from have at html but by they or will not can about org was we news new their', 'Space-sep list of stopwords');
INSERT INTO vars (name, value, description) VALUES ('sphinx_se', '0', 'Use SphinxSE instead of the API directly?');

