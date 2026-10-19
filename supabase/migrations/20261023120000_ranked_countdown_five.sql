-- The ranked lobby starts five seconds after the minimum table is reached.
update internal.config set value = '5' where key = 'ranked_countdown';
