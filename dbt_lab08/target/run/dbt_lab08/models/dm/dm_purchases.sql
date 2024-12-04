
  
    
    
    
        
         


        insert into `lab08`.`dm_purchases__dbt_backup`
        ("click_id", "confirmation_time", "page_url", "device_type", "device_is_mobile", "browser_name", "utm_medium", "utm_source", "utm_content", "utm_campaign", "user_custom_id")WITH purchase_events AS (
	SELECT event_timestamp
		 , click_id
		 , page_url
		 , page_url_path
		 , device_type
		 , device_is_mobile
		 , browser_name
		 , utm_medium
		 , utm_source
		 , utm_content
		 , utm_campaign
                 , user_custom_id
		 --, row_number() OVER (PARTITION BY click_id ORDER BY event_timestamp) rnk
		 , leadInFrame(page_url_path) OVER (PARTITION BY click_id ORDER BY event_timestamp ROWS BETWEEN CURRENT ROW AND unbounded FOLLOWING) next_step
		 --, count(1) over(PARTITION BY be.click_id) row_cnt
	 	 , CASE
		 	   WHEN lower(page_url_path) LIKE '/product_%' THEN 'product'
		 	   ELSE substring(lower(page_url_path), 2)
		   END AS cur_type
	 	 , CASE
		 	   WHEN lower(next_step) LIKE '/product_%' THEN 'product'
		 	   ELSE substring(lower(next_step), 2)
		 END AS next_type
	FROM `lab08`.`core_events`
	WHERE click_id IN (
			   SELECT DISTINCT click_id
                           FROM core_events
			   WHERE page_url_path = '/confirmation')
	  --AND be.click_id = 'fd9ad1b3-489d-4b4a-9f9a-324ae910d872'
	--ORDER BY click_id
	--	   , event_timestamp
)
   , purchase_events_third_type AS (
SELECT *
	 , leadInFrame(next_type) OVER (PARTITION BY click_id ORDER BY event_timestamp ROWS BETWEEN CURRENT ROW AND unbounded FOLLOWING) next_type_in_filt
	 --, leadInFrame(next_type, 2) OVER (PARTITION BY click_id ORDER BY event_timestamp ROWS BETWEEN CURRENT ROW AND unbounded FOLLOWING) next_type_in_filt_2
	 , CASE
	 	   WHEN lower(page_url_path) LIKE '/product_%' AND next_step = '/cart' THEN 1
	 	   WHEN lower(page_url_path) = '/cart' AND next_step = '/payment' THEN 1
	 	   WHEN lower(page_url_path) = '/payment' AND next_step = '/confirmation' THEN 1
	 	   WHEN lower(page_url_path) = '/confirmation' THEN 1
	 	   ELSE 0
	 END AS fl_purchase
FROM purchase_events
WHERE 1 = 1
  AND fl_purchase = 1
  --AND row_cnt > 4
  --AND cur_type = 'home'
  --AND next_type = 'confirmation'
)
   , purchase_events_fourth_type AS (
SELECT click_id
	 , page_url_path
	 , page_url
	 , event_timestamp
	 , cur_type
	 , next_type
	 , next_type_in_filt
	 , device_type
	 , device_is_mobile
	 , browser_name
	 , utm_medium
	 , utm_source
	 , utm_content
	 , utm_campaign
         , user_custom_id
	 , leadInFrame(next_type, 2) OVER (PARTITION BY click_id ORDER BY event_timestamp ROWS BETWEEN CURRENT ROW AND unbounded FOLLOWING) next_type_in_filt_2
	 --, next_type_in_filt_2
	 --, if(cur_type = 'product' AND  next_type = 'cart' and next_type_in_filt = 'payment' and next_type_in_filt_2 = 'confirmation', 1, 0) fl_buy
FROM purchase_events_third_type
WHERE NOT (cur_type = 'cart' AND next_type = 'payment' and next_type_in_filt = 'payment')
  AND NOT (cur_type = 'cart' AND next_type = 'payment' and next_type_in_filt = 'cart')
)
   , purchase_events_fourth_type_filtered AS (
	SELECT *
		 , CASE
			   WHEN cur_type = 'product' AND  next_type = 'cart' and next_type_in_filt = 'payment' and next_type_in_filt_2 = 'confirmation' THEN 1
			   WHEN cur_type = 'product' AND  next_type = 'cart' and next_type_in_filt != '' and next_type_in_filt_2 != '' THEN 2
			   ELSE 0
		   END as fl_buy
	FROM purchase_events_fourth_type
	WHERE (fl_buy > 0
			   OR cur_type = 'confirmation')
)
   , conf_time AS (
	SELECT click_id
		 , event_timestamp AS confirmation_time
	FROM purchase_events_fourth_type_filtered
	WHERE cur_type = 'confirmation'
)
SELECT pe.click_id
	 , min(c.confirmation_time) AS confirmation_time
	 --, pe.page_url_path
	 , pe.page_url
	 --, pe.event_timestamp
	 --, pe.cur_type
	 --, pe.next_type
	 --, pe.next_type_in_filt
	 , pe.device_type
	 , pe.device_is_mobile
	 , pe.browser_name
	 , pe.utm_medium
	 , pe.utm_source
	 , pe.utm_content
	 , pe.utm_campaign
         , pe.user_custom_id
FROM purchase_events_fourth_type_filtered pe
LEFT JOIN conf_time c
	  ON pe.click_id = c.click_id
WHERE cur_type = 'product'
  AND c.confirmation_time > pe.event_timestamp
GROUP BY pe.click_id
	   --, pe.page_url_path
	   , pe.page_url
	   --, pe.event_timestamp
	   --, pe.cur_type
           --, pe.next_type
	   --, pe.next_type_in_filt
	   , pe.device_type
	   , pe.device_is_mobile
	   , pe.browser_name
	   , pe.utm_medium
	   , pe.utm_source
	   , pe.utm_content
	   , pe.utm_campaign
	   , pe.user_custom_id
  