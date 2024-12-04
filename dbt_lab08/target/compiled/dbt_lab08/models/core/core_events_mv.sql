

WITH browser AS (
	SELECT event_id
	     , event_timestamp
	     , event_type
	     , click_id
	     , browser_name
	     , browser_user_agent
	     , browser_language
	     , file_key_date
	FROM `lab08`.`raw_browser_events`
)
   , location AS (
	SELECT event_id
	     , page_url
	     , page_url_path
	     , referer_url
	     , referer_medium
	     , utm_medium
	     , utm_source
	     , utm_content
	     , utm_campaign
	FROM `lab08`.`raw_location_events`
)
   , geo AS (
	SELECT click_id
	     , geo_country
	     , geo_timezone
	     , geo_region_name
	     , ip_address
	     , geo_latitude
	     , geo_longitude
	     , row_number() over(partition by click_id, geo_country, geo_timezone, geo_region_name, ip_address, geo_latitude, geo_longitude) AS rn
	FROM `lab08`.`raw_geo_events`
)
   , device AS (
	SELECT click_id
	     , os
	     , os_name
	     , os_timezone
	     , device_type
	     , device_is_mobile
	     , user_custom_id
	     , user_domain_id
	     , row_number() over(partition by click_id, os, os_name, os_timezone, device_type, device_is_mobile, user_custom_id, user_domain_id) AS rn
	FROM `lab08`.`raw_device_events`
)
SELECT b.event_id as event_id
     , b.event_timestamp
     , b.event_type
     , b.click_id as click_id
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
FROM browser b
LEFT JOIN location l
	  ON b.event_id = l.event_id
LEFT JOIN geo g
	   ON b.click_id = g.click_id
	  AND g.rn = 1
LEFT JOIN device d
	   ON b.click_id = d.click_id
	  AND d.rn = 1