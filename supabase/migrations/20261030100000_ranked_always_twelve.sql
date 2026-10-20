-- Ranked tables are always 12: no smaller tables, whatever the wait.
update internal.config set value = '12' where key = 'ranked_small_min';
