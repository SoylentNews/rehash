update stories set time = date_add(now(), INTERVAL -2 day) where sid = '00/01/25/1430236';
update stories set time = date_add(now(), INTERVAL -1 day) where sid = '00/01/25/1236215';
update discussions set flags = 'hitparade_dirty';
