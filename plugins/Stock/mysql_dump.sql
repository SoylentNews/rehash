INSERT INTO blocks (bid, block, seclev, type, description, section, ordernum, title, portal, url, rdf, retrieve) VALUES ('stockquotes','',500,'static','','index',8,'Stock Quotes',1,'','',0);

INSERT INTO stocks (name, stockorder, exchange, symbol, url) VALUES ('currency',-1,'_DATA','USD','Preferred currency.');
INSERT INTO stocks (name, stockorder, exchange, symbol, url) VALUES ('timeformat',-1,'_DATA','%R %Z','Date::Format template for last_update time format');

INSERT INTO stocks (name, stockorder, exchange, symbol, url) VALUES ('VA Linux',10,'nasdaq','LNUX','http://finance.yahoo.com/q?s=LNUX&d=t');
INSERT INTO stocks (name, stockorder, exchange, symbol, url) VALUES ('Red Hat',20,'nasdaq','RHAT','http://qs.money.cnn.com/apps/stockquote?symbols=RHAT');
INSERT INTO stocks (name, stockorder, exchange, symbol, url) VALUES ('IBM',30,'nasdaq','IBM','http://quotes.nasdaq.com/quote.dll?page=charting&mode=basics&symbol=IBM&selected=IBM');
INSERT INTO stocks (name, stockorder, exchange, symbol, url) VALUES ('Microsoft',40,'nasdaq','MSFT','http://mwprices.ft.com/custom/ft-com/quotechartnews.asp?ftsite=&searchtype=&expanded=&countrycode=US&symb=MSFT&sid=3140&site=');
INSERT INTO stocks (name, stockorder, exchange, symbol, url) VALUES ('G.E.',50,'nyse','GE','http://www.hoovers.com/co/capsule/4/0,2163,10634,00.html');

