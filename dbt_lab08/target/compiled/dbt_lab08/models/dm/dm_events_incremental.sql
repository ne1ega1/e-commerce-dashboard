

select toStartOfHour(event_timestamp) as hr
     , count(1)                       as cnt
from `lab08`.`core_events_mv`
group by (toStartOfHour(event_timestamp))