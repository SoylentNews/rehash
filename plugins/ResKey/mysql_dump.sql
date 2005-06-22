#
# $Id$
#

INSERT INTO reskey_resources VALUES (1, 'comments');

INSERT INTO reskey_resource_checks VALUES (NULL, 1, 'create', 'Slash::ResKey::Checks::User',    101);
INSERT INTO reskey_resource_checks VALUES (NULL, 1, 'create', 'Slash::ResKey::Checks::ACL',     201);
INSERT INTO reskey_resource_checks VALUES (NULL, 1, 'touch',  'Slash::ResKey::Checks::User',    101);
INSERT INTO reskey_resource_checks VALUES (NULL, 1, 'touch',  'Slash::ResKey::Checks::ACL',     201);
INSERT INTO reskey_resource_checks VALUES (NULL, 1, 'use',    'Slash::ResKey::Checks::User',    101);
INSERT INTO reskey_resource_checks VALUES (NULL, 1, 'use',    'Slash::ResKey::Checks::ACL',     201);


INSERT INTO vars VALUES ('reskey_checks_user_seclev_comments', 0, 'Minimum seclev to post a comment');
INSERT INTO vars VALUES ('reskey_checks_user_karma_comments', '', 'No minimum karma to post a comment');

INSERT INTO vars VALUES ('reskey_checks_acl_no_comments', 'reskey_no_comments', 'No comment posting for you!');

