INSERT INTO vars (name, value) VALUES ('soap_enabled', 1);

# examples for use with test package Slash::SOAP::Test
# would normally be "Slash::${plugin}::SOAP", e.g., 'Slash::Search::SOAP'
INSERT INTO soap_methods (class, method, seclev, formkeys) VALUES ('Slash::SOAP::Test', 'get_nickname', 0, 'max_post_check,interval_check');
INSERT INTO soap_methods (class, method, seclev, formkeys) VALUES ('Slash::SOAP::Test', 'get_uid', 0, 'max_post_check,interval_check');
INSERT INTO vars (name, value) VALUES ('test/get_nickname_speed_limit', 10);
INSERT INTO vars (name, value) VALUES ('max_test/get_nickname_allowed', 50);
INSERT INTO vars (name, value) VALUES ('test/get_uid_speed_limit', 10);
INSERT INTO vars (name, value) VALUES ('max_test/get_uid_allowed', 50);
