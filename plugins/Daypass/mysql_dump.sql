INSERT INTO hooks (param, class, subroutine) VALUES ('daypass_dooffer', 'Slash::Daypass', 'doOfferDaypass');
INSERT INTO hooks (param, class, subroutine) VALUES ('daypass_getoffertext', 'Slash::Daypass', 'getOfferText');

INSERT INTO vars (name, value, description) VALUES ('daypass', '0', 'Activate daypass system?');
INSERT INTO vars (name, value, description) VALUES ('daypass_cache_expire', '300', 'How long is the cache of the daypass_available table stored?');
INSERT INTO vars (name, value, description) VALUES ('daypass_offer', '0', 'Offer daypasses to logged-in non-subscriber users on the homepage?');
INSERT INTO vars (name, value, description) VALUES ('daypass_seetmf', '0', 'Should users with daypasses be able to, like subscribers, see The Mysterious Future?');


