{{
    config(
        materialized='incremental',
        unique_key=['click_id', 'event_timestamp']
    )
}}

with purchase_events as (
	select event_timestamp
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
		 , leadInFrame(page_url_path) over (
			partition by click_id order by event_timestamp rows between current row and unbounded following) next_step
		 , case
			   when lower(page_url_path) like '/product_%' then 'product'
			   else substring(lower(page_url_path), 2)
		   end as cur_type
		 , case
			   when lower(next_step) like '/product_%' then 'product'
			   else substring(lower(next_step), 2)
		   end as next_type
	from {{ source('lab08', 'core_events_mv') }}
	where click_id in (select distinct click_id
                           from {{ source('lab08', 'core_events_mv') }}
			   where page_url_path = '/confirmation'
			   )
)
   , purchase_events_third_type as (
	select *
		 , leadInFrame(next_type) over (partition by click_id order by event_timestamp rows between current row and unbounded following) next_type_in_filt
		 , case
		       when lower(page_url_path) like '/product_%' and next_step = '/cart' then 1
			   when lower(page_url_path) = '/cart' and next_step = '/payment' then 1
			   when lower(page_url_path) = '/payment' and next_step = '/confirmation' then 1
			   when lower(page_url_path) = '/confirmation' then 1
			   else 0
		   end as fl_purchase
	from purchase_events
	where fl_purchase = 1
)
   , purchase_events_fourth_type as (
	select click_id
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
	     , leadInFrame(next_type, 2) over (
			partition by click_id order by event_timestamp rows between current row and unbounded following) next_type_in_filt_2
	from purchase_events_third_type
	where not (cur_type = 'cart' and next_type = 'payment' and next_type_in_filt = 'payment')
	  and not (cur_type = 'cart' and next_type = 'payment' and next_type_in_filt = 'cart')
)
   , purchase_events_fourth_type_filtered as (
	select *
		 , case
			   when cur_type = 'product' and  next_type = 'cart' and next_type_in_filt = 'payment' and next_type_in_filt_2 = 'confirmation' then 1
			   when cur_type = 'product' and  next_type = 'cart' and next_type_in_filt != '' and next_type_in_filt_2 != '' then 2
			   else 0
		   end as fl_buy
	from purchase_events_fourth_type
	where (fl_buy > 0
			   or cur_type = 'confirmation')
)
   , conf_time as (
	select click_id
		 , event_timestamp as confirmation_time
	from purchase_events_fourth_type_filtered
	where cur_type = 'confirmation'
)
select pe.click_id
	 , min(c.confirmation_time) as confirmation_time
	 , pe.page_url
	 , pe.event_timestamp as event_timestamp
	 , pe.device_type
	 , pe.device_is_mobile
	 , pe.browser_name
	 , pe.utm_medium
	 , pe.utm_source
	 , pe.utm_content
	 , pe.utm_campaign
	 , pe.user_custom_id
from purchase_events_fourth_type_filtered pe
left join conf_time c
	  on pe.click_id = c.click_id
where cur_type = 'product'
  and c.confirmation_time > pe.event_timestamp
group by pe.click_id
	   , pe.page_url
	   , pe.event_timestamp
	   , pe.device_type
	   , pe.device_is_mobile
	   , pe.browser_name
	   , pe.utm_medium
	   , pe.utm_source
	   , pe.utm_content
	   , pe.utm_campaign
	   , pe.user_custom_id
