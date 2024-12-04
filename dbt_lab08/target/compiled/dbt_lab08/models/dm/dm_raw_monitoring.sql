with counts as (
	select file_key_date
	     , 'raw_browser_events' as table_name
	     , count(1)             as cnt
	from raw_browser_events
	group by file_key_date

	union all

	select file_key_date
	     , 'raw_device_events' as table_name
	     , count(1)            as cnt
	from raw_device_events
	group by file_key_date

	union all

	select file_key_date
	     , 'raw_geo_events' as table_name
	     , count(1)         as cnt
	from raw_geo_events 
	group by file_key_date

	union all
	select file_key_date 
	     , 'raw_location_events' as table_name
	     , count(1)              as cnt
	from raw_location_events
	group by file_key_date
)
select *
from counts
order by file_key_date
       , table_name