library(RPostgres)
library(dplyr)
library(dbplyr)
library(sf)

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

deployments_db <- tbl(con, in_schema("telem","tbl_tag_deployments")) |> 
  dplyr::select(speno, deployid, tag_family, deploy_dt, end_dt)  |> 
  rename(tag_type = tag_family)  |>  collect()

spenos_db <- tbl(con, in_schema("capture","for_telem"))  |>  collect()

locs_qry <- "SELECT deployid, ptt, type, error_radius, error_semi_major_axis,
              error_semi_minor_axis, error_ellipse_orientation, locs_dt, quality, geom as geometry
              FROM telem.geo_wc_locs_qa WHERE qa_status != 'tag_actively_transmitting';"

locs_sf <- read_sf(con, query = locs_qry)  |> 
  left_join(deployments_db, by = 'deployid')  |> 
  left_join(spenos_db, by = 'speno')  |> 
  filter(species %in% c('Ribbon seal', 'Spotted seal'))  |> 
  filter(between(locs_dt,deploy_dt,end_dt)) |> 
  mutate(unique_day =
           glue::glue("{lubridate::year(locs_dt)}",
                      "{lubridate::yday(locs_dt)}",
                      .sep = "_"))
dbDisconnect(con)

locs_sf <- locs_sf |> 
  group_by(deployid) |> 
  arrange(locs_dt, error_radius)  |> 
  mutate(
    rank = 1L,
    rank = case_when(duplicated(locs_dt, fromLast = FALSE) ~
                       lag(rank) + 1L, TRUE ~ rank))  |> 
  dplyr::filter(rank == 1)  |>  
  arrange(deployid,locs_dt)  |>  
  dplyr::filter(n() > 30L) |> 
  dplyr::filter(difftime(max(locs_dt),min(locs_dt),units = "days") > 7) |> 
  ungroup()

saveRDS(locs_sf,here::here('data/locs_sf.rds'))
