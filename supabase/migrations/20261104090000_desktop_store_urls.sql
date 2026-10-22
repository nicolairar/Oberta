-- Desktop ships only through Steam: no public GitHub releases (the code
-- repository is private, so those links were 404 for players). Until the
-- Steam store page exists, the "Update required" button on desktop opens the
-- landing page. Only the old defaults are replaced: a URL set by hand stays.
update internal.config
set value = 'https://charliemobile.dev/oberta/'
where key in ('store_url_macos', 'store_url_windows', 'store_url_linux')
  and value = 'https://github.com/nicolairar/Oberta/releases/latest';
