INSERT INTO vars (name, value) VALUES ('soap_enabled', 1);

# examples for use with test package Slash::SOAP::Test
# would normally be "Slash::${plugin}::SOAP", e.g., 'Slash::Search::SOAP'
INSERT INTO soap_methods (class, method, seclev, formkeys) VALUES ('Slash::SOAP::Test', 'get_user', 0, 'max_post_check,interval_check');
INSERT INTO vars (name, value) VALUES ('test/get_user_speed_limit', 10);
INSERT INTO vars (name, value) VALUES ('max_test/get_user_allowed', 50);
