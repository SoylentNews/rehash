update stories set writestatus = 1;
update stories set time = date_add(now(), INTERVAL -2 day) where sid like '%14%';
update stories set time = date_add(now(), INTERVAL -1 day) where sid like '%16%';
update stories set time = now() where sid like '%17%';
update newstories set writestatus = 1;
update newstories set time = date_add(now(), INTERVAL -2 day) where sid like '%14%';
update newstories set time = date_add(now(), INTERVAL -1 day) where sid like '%16%';
update newstories set time = now() where sid like '%17%';
