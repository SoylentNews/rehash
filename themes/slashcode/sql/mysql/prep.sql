# $Id$
UPDATE stories SET time = DATE_ADD(NOW(), INTERVAL -2 DAY) WHERE sid = '00/01/25/1430236';
UPDATE stories SET time = DATE_ADD(NOW(), INTERVAL -1 DAY) WHERE sid = '00/01/25/1236215';
UPDATE discussions SET flags = 'hitparade_dirty';
UPDATE sections SET defaultsubsection=section WHERE type != "collected";
UPDATE sections SET defaultsection='articles' WHERE section='index';
