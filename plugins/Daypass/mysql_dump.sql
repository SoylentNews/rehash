INSERT INTO hooks (param, class, subroutine) VALUES ('daypass_dooffer', 'Slash::Daypass', 'doOfferDaypass');
INSERT INTO hooks (param, class, subroutine) VALUES ('daypass_getoffertext', 'Slash::Daypass', 'getOfferText');

INSERT INTO vars (name, value, description) VALUES ('daypass', '0', 'Activate daypass system?');
INSERT INTO vars (name, value, description) VALUES ('daypass_adnum', '13', 'Which ad number to pass to getAd?');
INSERT INTO vars (name, value, description) VALUES ('daypass_cache_expire', '60', 'How long is the cache of the daypass_available table stored?');
INSERT INTO vars (name, value, description) VALUES ('daypass_offer', '0', 'Offer daypasses to logged-in non-subscriber users on the homepage?');
INSERT INTO vars (name, value, description) VALUES ('daypass_offer_onlywhentmf', '0', 'Offer daypasses only when there is a story in The Mysterious Future?');
INSERT INTO vars (name, value, description) VALUES ('daypass_offer_method', '0', 'How to determine whether a daypass is offered: 0=use daypass_available table, 1=check adpos text against regex');
INSERT INTO vars (name, value, description) VALUES ('daypass_offer_method1_acl', '', 'ACL required to be offered a daypass (blank for none, i.e. all users eligible)');
INSERT INTO vars (name, value, description) VALUES ('daypass_offer_method1_adpos', '31', 'If daypass_offer_method is 1, which ad position to check?');
INSERT INTO vars (name, value, description) VALUES ('daypass_offer_method1_minduration', '10', 'Minimum time allowed before click');
INSERT INTO vars (name, value, description) VALUES ('daypass_offer_method1_regex', '!placeholder', 'If daypass_offer_method is 1, what regex on that ad text tells us whether a daypass is available? A leading ! inverts logic (regex match means daypass not available)');
INSERT INTO vars (name, value, description) VALUES ('daypass_offer_onlytologgedin', '0', 'If 1, offer a daypass only to logged-in users');
INSERT INTO vars (name, value, description) VALUES ('daypass_seetmf', '0', 'Should users with daypasses be able to, like subscribers, see The Mysterious Future?');
INSERT INTO vars (name, value, description) VALUES ('daypass_tz', 'PST', 'What timezone are daypasses considered to be in (this determines where "midnight" starts and ends the day)');

