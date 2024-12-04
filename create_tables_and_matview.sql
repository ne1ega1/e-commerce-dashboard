create table lab08.raw_browser_events 
(
    event_id String,  
    event_timestamp DateTime64(6),
    event_type String,
    click_id String,
    browser_name String,
    browser_user_agent String,
    browser_language String,
    file_key_date DateTime
) 
engine = MergeTree()
order by event_timestamp;

create table lab08.raw_device_events 
(
    click_id String,  
    os String,
    os_name String,
    os_timezone String,
    device_type String,
    device_is_mobile UInt8,
    user_custom_id String,
    user_domain_id String,
    file_key_date DateTime
) 
engine = MergeTree()
order by click_id;

create table lab08.raw_location_events 
(
    event_id String,  
    page_url String,
    page_url_path String,
    referer_url String,
    referer_medium String,
    utm_medium String,
    utm_source String,
    utm_content String,
    utm_campaign String,
    file_key_date DateTime
) 
engine = MergeTree()
order by event_id;

create table lab08.raw_geo_events 
(
    click_id String,
    geo_country String,
    geo_timezone String,
    geo_region_name String,
    ip_address IPv4,
    geo_latitude Float64,
    geo_longitude Float64,
    file_key_date DateTime
) 
engine = MergeTree()
order by click_id;

create materialized view core_events_mv 
engine = MergeTree()
partition by toYYYYMMDDhhmmss(file_key_date)
order by event_timestamp 
settings index_granularity = 8192 as (
with browser as (
    select event_id 
         , event_timestamp 
         , event_type 
         , click_id 
         , browser_name 
         , browser_user_agent 
         , browser_language
         , file_key_date 
    from lab08.raw_browser_events
)
   , location as (
	select event_id 
		 , page_url 
		 , page_url_path 
		 , referer_url 
		 , referer_medium 
		 , utm_medium
		 , utm_source 
		 , utm_content 
		 , utm_campaign  
	from lab08.raw_location_events
)
   , geo as (
	select click_id 
		 , geo_country 
		 , geo_timezone 
		 , geo_region_name 
		 , ip_address 
		 , geo_latitude 
		 , geo_longitude 
		 , row_number() over(
			partition by click_id, geo_country, geo_timezone, geo_region_name
			, ip_address, geo_latitude, geo_longitude) as rn
	from lab08.raw_geo_events
)
   , device as (
	select click_id 
		 , os
		 , os_name 
		 , os_timezone 
		 , device_type 
		 , device_is_mobile 
		 , user_custom_id 
		 , user_domain_id 
		 , row_number() over(
			partition by click_id, os, os_name, os_timezone, device_type
			, device_is_mobile, user_custom_id, user_domain_id) as rn
	FROM lab08.raw_device_events
)
select b.event_id        as event_id
	 , b.event_timestamp as event_timestamp
	 , b.event_type 
	 , b.click_id        as click_id
	 , b.browser_name 
	 , b.browser_user_agent 
	 , b.browser_language 
	 , l.page_url 
	 , l.page_url_path 
	 , l.referer_url 
	 , l.referer_medium 
	 , l.utm_medium
	 , l.utm_source 
	 , l.utm_content 
	 , l.utm_campaign
	 , g.geo_country 
	 , g.geo_timezone 
	 , g.geo_region_name 
	 , g.ip_address 
	 , g.geo_latitude 
	 , g.geo_longitude
	 , d.os
	 , d.os_name 
	 , d.os_timezone 
	 , d.device_type 
	 , d.device_is_mobile 
	 , d.user_custom_id 
	 , d.user_domain_id
	 , b.file_key_date
from browser b
left join location l
	  on b.event_id = l.event_id
left join geo g
	  on b.click_id = g.click_id
	 and g.rn = 1 
left join device d
	  on b.click_id = d.click_id
	 and d.rn = 1 
);
