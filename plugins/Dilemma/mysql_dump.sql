INSERT IGNORE INTO vars (name, value, description) VALUES ('dilemma', '1', 'Enable dilemma?');

DELETE FROM dilemma_species;
INSERT INTO dilemma_species (dsid, name, uid, code) VALUES (1, 'alld',         667, 'return 0');
INSERT INTO dilemma_species (dsid, name, uid, code) VALUES (2, 'allc',         667, 'return 1');
INSERT INTO dilemma_species (dsid, name, uid, code) VALUES (3, 'random',       667, 'return rand()');
INSERT INTO dilemma_species (dsid, name, uid, code) VALUES (4, 'titfortat',    667, 'if ($me_play) { $me{memory}{$it{daid}} = $it_play } else { if (defined($me{memory}{$it{daid}})) { return $me{memory}{$it{daid}} } else { return 1 } }');
INSERT INTO dilemma_species (dsid, name, uid, code) VALUES (5, 'titfortat_sp', 667, 'if ($me_play) { $me{memory}{$it{dsid}} = $it_play } else { if (defined($me{memory}{$it{dsid}})) { return $me{memory}{$it{dsid}} } else { return 1 } }');
INSERT INTO dilemma_species (dsid, name, uid, code) VALUES (6, 'titfortat_ra', 667, 'if ($me_play) { $me{memory}{$it{daid}} = $it_play } else { if (defined($me{memory}{$it{daid}})) { return $me{memory}{$it{daid}} } else { return rand() } }');
INSERT INTO dilemma_species (dsid, name, uid, code) VALUES (7, 'titfortat_sq', 667, 'if ($me_play) { $me{memory}{$it{daid}} = $it_play } else { if (defined($me{memory}{$it{daid}})) { return $me{memory}{$it{daid}} ** 2 } else { return 1 } }');
INSERT INTO dilemma_species (dsid, name, uid, code) VALUES (8, 'grudge', 667,       'if ($me_play) { $me{memory}{$it{daid}} = $it_play if !defined($me{memory}{$id{daid}}) || $it_play < $me{memory}{$it{daid}} } else { if (defined($me{memory}{$it{daid}})) { return $me{memory}{$it{daid}} } else { return 1 } }');

DELETE FROM dilemma_agents;
INSERT INTO dilemma_agents (dsid, food) VALUES (1, 1);
INSERT INTO dilemma_agents (dsid, food) VALUES (1, 1);
INSERT INTO dilemma_agents (dsid, food) VALUES (1, 1);
INSERT INTO dilemma_agents (dsid, food) VALUES (1, 1);
INSERT INTO dilemma_agents (dsid, food) VALUES (2, 1);
INSERT INTO dilemma_agents (dsid, food) VALUES (2, 1);
INSERT INTO dilemma_agents (dsid, food) VALUES (2, 1);
INSERT INTO dilemma_agents (dsid, food) VALUES (2, 1);
INSERT INTO dilemma_agents (dsid, food) VALUES (3, 1);
INSERT INTO dilemma_agents (dsid, food) VALUES (3, 1);
INSERT INTO dilemma_agents (dsid, food) VALUES (3, 1);
INSERT INTO dilemma_agents (dsid, food) VALUES (3, 1);
INSERT INTO dilemma_agents (dsid, food) VALUES (4, 1);
INSERT INTO dilemma_agents (dsid, food) VALUES (4, 1);
INSERT INTO dilemma_agents (dsid, food) VALUES (4, 1);
INSERT INTO dilemma_agents (dsid, food) VALUES (4, 1);
INSERT INTO dilemma_agents (dsid, food) VALUES (5, 1);
INSERT INTO dilemma_agents (dsid, food) VALUES (5, 1);
INSERT INTO dilemma_agents (dsid, food) VALUES (5, 1);
INSERT INTO dilemma_agents (dsid, food) VALUES (5, 1);
INSERT INTO dilemma_agents (dsid, food) VALUES (6, 1);
INSERT INTO dilemma_agents (dsid, food) VALUES (6, 1);
INSERT INTO dilemma_agents (dsid, food) VALUES (6, 1);
INSERT INTO dilemma_agents (dsid, food) VALUES (6, 1);
INSERT INTO dilemma_agents (dsid, food) VALUES (7, 1);
INSERT INTO dilemma_agents (dsid, food) VALUES (7, 1);
INSERT INTO dilemma_agents (dsid, food) VALUES (7, 1);
INSERT INTO dilemma_agents (dsid, food) VALUES (7, 1);
INSERT INTO dilemma_agents (dsid, food) VALUES (8, 1);
INSERT INTO dilemma_agents (dsid, food) VALUES (8, 1);
INSERT INTO dilemma_agents (dsid, food) VALUES (8, 1);
INSERT INTO dilemma_agents (dsid, food) VALUES (8, 1);

DELETE FROM dilemma_info;
INSERT INTO dilemma_info (alive, max_runtime, last_tick, food_per_time, birth_food, idle_food, mean_meets) VALUES ('yes', 5000, 0, 1.0, 10.0, 0.05, 20);

