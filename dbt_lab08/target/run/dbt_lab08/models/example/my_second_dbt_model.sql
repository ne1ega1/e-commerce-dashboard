

  create view `lab08`.`my_second_dbt_model__dbt_tmp` 
  
    
    
  as (
    -- Use the `ref` function to select from other models

select *
from `lab08`.`my_first_dbt_model`
where id = 1
    
  )
      
      
                    -- end_of_sql
                    
                    