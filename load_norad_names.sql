CREATE TABLE IF NOT EXISTS norad_names(
    sat_name TEXT NOT NULL
);
DELETE FROM norad_names;
.mode csv
.import CMD_PATH/norad_names.txt norad_names
.quit


