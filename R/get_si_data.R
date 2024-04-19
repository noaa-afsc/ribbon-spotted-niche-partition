library(RPostgres)
library(dplyr)
library(dbplyr)
library(tidyr)
library(SIBER)
library(tibble)

tryCatch({
  con <- dbConnect(RPostgres::Postgres(),
                   dbname = 'pep', 
                   host = Sys.getenv('PEP_PG_IP'),
                   user = keyringr::get_kc_account("pgpep_londonj"),
                   password = keyringr::decrypt_kc_pw("pgpep_londonj"))
},
error = function(cond) {
  print("Unable to connect to Database.")
})
on.exit(dbDisconnect(con))

spenos_db <- tbl(con, in_schema("capture","geo_captures"))  |>  
  select(speno, common_name, capture_dt, age_class, sex) |> 
  collect()

si_qry <- "select * from capture.tbl_sample_results
where result_type_lku in ('D13C','D15N');"

si_data <- dbGetQuery(con, si_qry)

si_data <- si_data |> 
  dplyr::left_join(spenos_db, by = 'speno') |> 
  dplyr::filter(common_name %in% c('Ribbon seal','Spotted seal')) |> 
  dplyr::select(speno,common_name,capture_dt,age_class,sex,result_type_lku,
                whisker_segment_num, whisker_to_cm, result_value) |> 
  dplyr::rename(result_type = result_type_lku) |> 
  dplyr::mutate(result_value = as.numeric(result_value))

saveRDS(si_data, here::here('data/si_data.rds'))
