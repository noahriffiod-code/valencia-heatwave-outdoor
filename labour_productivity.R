# Labour productivity cost of the 2026 heatwaves for outdoor work in the
# city of Valencia. Run from the repository root (open the .Rproj file).
#
# Method: Orlov et al. (2020), applied to hourly data.
#   WBGT in the shade: Orlov et al. (2020), eq. 2.2.1; Lemke and Kjellstrom (2012), eq. 8
#   WBGT in the sun:   Liljegren et al. (2008), R package HeatStressR (>= 3.0.0)
#   Work capacity:     HOTHAPS function, Orlov et al. (2020), eq. 2.3.1
#   Valuation:         hours lost x labour cost (direct cost only)
#   Climate change:    counterfactual T - delta, Barnes et al. (2026)
#
# Heatwaves: the three final AEMET heatwaves of summer 2026. Wave 4
# (2-7 September) is provisional in the AEMET note and is excluded.
#
# Requires install.packages("HeatStressR"). Results are written to output/.

dir.create("output", showWarnings = FALSE)


# Parameters ----------------------------------------------------------

file_era5   <- "data/era5_valencia_hourly_2026-06-01_2026-09-30.csv"
file_delta  <- "data/delta_barnes_2026_valencia.csv"
file_waves  <- "data/heatwaves_aemet_2026.csv"

# AEMET station 8416 Valencia (sun position)
lat <- 39.48056
lon <- -0.36639

# Working hours: 7:00-15:00, Monday to Friday
hour_start <- 7
hour_end   <- 15

# HeatStressR expects wind at 2 m; ERA5 gives 10 m.
# Allen et al. (1998), FAO-56, eq. 47
wind_factor_2m <- 4.87 / log(67.8 * 10 - 5.42)    # 0.748

# ERA5 radiation is the mean over the preceding hour: the sun position is
# taken at the middle of that hour.
sun_offset_min <- 30

# HOTHAPS parameters at 200, 300 and 400 W (Orlov et al., 2020, eq. 2.3.1)
hothaps <- data.frame(watts = c(200, 300, 400),
                      a1    = c(34.64, 32.93, 30.94),
                      a2    = c(22.72, 17.81, 16.64))

# MET to W: 1 MET = 1 kcal/kg/h (Herrmann et al., 2024), 1 kcal/h = 1.163 W,
# reference body mass 70 kg
met_to_watts <- function(met) met * 1.163 * 70

# Sectors
#  jobs:  Social Security affiliations in the city of Valencia, 31/12/2024
#         (Ajuntament de Valencia, Anuario estadistico 2025, chapter 7)
#  watts: Orlov et al. (2020, sect. 2.6) for construction; 2024 Compendium
#         (Herrmann et al., 2024) and Tudor-Locke et al. (2011) for the other
#         occupations (activity codes in comments)
#  cost_spain: total labour cost per worker and month, INE, ETCL, 2026 Q2,
#         by CNAE section
sectors <- data.frame(
  sector     = c("Construction", "Water and waste", "Warehousing",
                 "Postal and courier", "Buildings and landscape"),
  cnae       = c("F", "E", "52", "53", "81"),
  jobs       = c(21574, 4570, 7108, 4640, 13680),
  exposure   = c("sun", "sun", "shade", "sun", "sun"),
  watts      = c(370,                       # Orlov et al. (2020)
                 met_to_watts(3.8),         # Compendium 11375
                 met_to_watts(4.3),         # Compendium 11862
                 met_to_watts(2.3),         # Compendium 11486
                 met_to_watts(4.0)),        # Compendium 11415
  watts_low  = c(met_to_watts(4.0),         # Compendium 11120
                 met_to_watts(3.0),         # Tudor-Locke 9720
                 met_to_watts(2.3),         # Compendium 11860
                 met_to_watts(1.5),         # Compendium 11487
                 met_to_watts(3.8)),        # Compendium 11375
  watts_high = c(400,                       # Kjellstrom et al. (2018)
                 met_to_watts(4.5),         # Compendium 11476
                 met_to_watts(7.5),         # Compendium 11490
                 met_to_watts(4.5),         # Tudor-Locke 5510
                 met_to_watts(7.3)),        # Compendium 11540
  cost_spain = c(3447.94, 3609.14, 3547.26, 3547.26, 2392.66),
  broad      = c("Construction", "Industry", "Services", "Services", "Services"))

# National cost scaled to the Comunitat Valenciana with the regional / national
# ratio of the broad sector (INE, ETCL, table 6061, 2026 Q2)
cost_ine <- data.frame(
  broad    = c("Construction", "Industry", "Services"),
  valencia = c(3147.54, 3305.70, 2949.34),
  spain    = c(3447.94, 3904.38, 3299.31))

ratio <- with(cost_ine, setNames(valencia / spain, broad))
sectors$cost_month <- sectors$cost_spain * ratio[sectors$broad]


# Functions -----------------------------------------------------------

# Saturation vapour pressure (hPa), Magnus formula
sat_vapour_pressure <- function(t) 6.112 * exp(17.62 * t / (243.12 + t))

# Psychrometric wet-bulb temperature: root of the psychrometric equation
wet_bulb <- function(ta, td, p) {
  td <- min(td, ta)
  e <- sat_vapour_pressure(td)
  f <- function(tw) sat_vapour_pressure(tw) - 0.00066 * (1 + 0.00115 * tw) * p * (ta - tw) - e
  uniroot(f, c(td - 1, ta + 1), tol = 1e-6)$root
}

wbgt_shade <- function(ta, td, p) {
  0.67 * mapply(wet_bulb, ta, td, p) + 0.33 * ta
}

wbgt_sun <- function(w, ta, wind) {
  HeatStressR::wbgt_liljegren(
    tas = ta, dewp = pmin(w$td, ta), wind = wind, radiation = w$radiation,
    time = w$time - 60 * sun_offset_min, lon = lon, lat = lat,
    pressure = w$p, direct_fraction = w$direct_share, dewpoint_policy = "cap")
}

# Share of the hour still worked (HOTHAPS), interpolated in work intensity
work_capacity <- function(wbgt, watts) {
  a1 <- approx(hothaps$watts, hothaps$a1, watts, rule = 2)$y
  a2 <- approx(hothaps$watts, hothaps$a2, watts, rule = 2)$y
  0.1 + 0.9 / (1 + (wbgt / a1)^a2)
}

working_days_in_month <- function(first_day) {
  days <- seq(first_day, seq(first_day, by = "month", length.out = 2)[2] - 1, by = "day")
  sum(!format(days, "%u") %in% c("6", "7"))
}


# Data ----------------------------------------------------------------

raw <- read.csv(file_era5)
weather <- data.frame(
  time      = as.POSIXct(raw$utc_datetime, format = "%Y-%m-%d %H:%M", tz = "UTC"),
  day       = as.Date(raw$local_date),
  hour      = raw$local_hour,
  ta        = raw$era5_t2m_C,
  td        = raw$era5_td2m_C,
  p         = raw$era5_psurf_hPa,
  wind10    = raw$era5_wind10m_ms,
  radiation = raw$era5_swrad_Wm2)
weather$direct_share <- ifelse(weather$radiation > 0,
                               pmin(1, raw$era5_dirrad_Wm2 / weather$radiation), 0.8)

delta <- read.csv(file_delta)      # month, delta, delta_low, delta_high
waves <- read.csv(file_waves)      # wave, start, end, status
waves <- waves[waves$status != "provisional", ]

# Periods: each wave and all waves
wave_days <- lapply(seq_len(nrow(waves)), function(i)
  seq(as.Date(waves$start[i]), as.Date(waves$end[i]), by = "day"))
names(wave_days) <- paste("Wave", waves$wave)

periods <- c(wave_days, list("All waves" = do.call(c, unname(wave_days))))

weather <- weather[weather$day %in% do.call(c, unname(periods)), ]
month   <- as.integer(format(weather$day, "%m"))
stopifnot(all(month %in% delta$month))
weather$worked <- !format(weather$day, "%u") %in% c("6", "7") &
                  weather$hour >= hour_start & weather$hour < hour_end
first_day <- as.Date(format(weather$day, "%Y-%m-01"))
months    <- unique(first_day)
n_working <- sapply(seq_along(months), function(i) working_days_in_month(months[i]))
weather$working_days <- n_working[match(first_day, months)]


# Observed and counterfactual WBGT -------------------------------------

wind2 <- weather$wind10 * wind_factor_2m

weather$wbgt_shade   <- wbgt_shade(weather$ta, weather$td, weather$p)
weather$wbgt_sun     <- wbgt_sun(weather, weather$ta, wind2)
weather$wbgt_sun_w10 <- wbgt_sun(weather, weather$ta, weather$wind10)

# Counterfactual: temperature minus the monthly delta, same dew point (capped
# at the new temperature), wind, radiation and pressure.
for (d in c("delta", "delta_low", "delta_high")) {
  ta_cf <- weather$ta - delta[[d]][match(month, delta$month)]
  weather[[paste0("shade_", d)]]   <- wbgt_shade(ta_cf, pmin(weather$td, ta_cf), weather$p)
  weather[[paste0("sun_", d)]]     <- wbgt_sun(weather, ta_cf, wind2)
  weather[[paste0("sun_w10_", d)]] <- wbgt_sun(weather, ta_cf, weather$wind10)
}


# Cost ----------------------------------------------------------------

# Cost for one sector, one WBGT ("shade", "sun" or "sun_w10") and one work
# intensity, for every period. The hourly cost is the monthly cost divided by
# the potential working hours of the month (working days x 8 h).
sector_cost <- function(s, type, watts, scenario) {
  hourly_cost <- s$cost_month / (weather$working_days * (hour_end - hour_start))
  loss <- function(wbgt) ifelse(weather$worked, 1 - work_capacity(wbgt, watts), 0)

  loss_obs <- loss(weather[[paste0("wbgt_", type)]])
  loss_cf  <- lapply(c("delta", "delta_low", "delta_high"),
                     function(d) loss(weather[[paste0(type, "_", d)]]))

  do.call(rbind, lapply(names(periods), function(name) {
    h <- weather$day %in% periods[[name]]
    meur <- function(x) s$jobs * sum(x[h] * hourly_cost[h]) / 1e6
    total   <- meur(loss_obs)
    climate <- sapply(loss_cf, function(x) total - meur(x))
    data.frame(period = name, sector = s$sector, scenario = scenario,
               loss_pct = 100 * mean(loss_obs[h & weather$worked]),
               cost_meur = total,
               climate_meur = climate[1], climate_low_meur = climate[2], climate_high_meur = climate[3])
  }))
}

results <- do.call(rbind, lapply(seq_len(nrow(sectors)), function(i) {
  s <- sectors[i, ]
  variant <- function(type) if (s$exposure == "sun") type else s$exposure
  rbind(sector_cost(s, s$exposure,          s$watts,      "Central"),
        sector_cost(s, s$exposure,          s$watts_low,  "Low intensity"),
        sector_cost(s, s$exposure,          s$watts_high, "High intensity"),
        sector_cost(s, variant("shade"),    s$watts,      "All in the shade"),
        sector_cost(s, variant("sun_w10"),  s$watts,      "Wind at 10 m"))
}))


# Results -------------------------------------------------------------

sum_by <- function(x, by) {
  aggregate(x[c("cost_meur", "climate_meur", "climate_low_meur", "climate_high_meur")], x[by], sum)
}
round3 <- function(x) { num <- sapply(x, is.numeric); x[num] <- round(x[num], 3); x }

central <- results[results$scenario == "Central", ]

cat("\nCost by period, central scenario (million EUR)\n")
by_period <- sum_by(central, "period")
print(round3(by_period[match(names(periods), by_period$period), ]), row.names = FALSE)

cat("\nCost by sector and period (million EUR)\n")
print(round(xtabs(cost_meur ~ sector + period, central), 3))

cat("\nTable 8: cost by sector, all waves (million EUR)\n")
t8 <- central[central$period == "All waves", c("sector", "cost_meur", "climate_meur")]
t8 <- rbind(t8, data.frame(sector = "Total", cost_meur = sum(t8$cost_meur), climate_meur = sum(t8$climate_meur)))
t8$share_pct <- round(100 * t8$climate_meur / t8$cost_meur)
print(round3(t8), row.names = FALSE)

cat("\nMean share of working hours lost by sector and period (%)\n")
print(round(xtabs(loss_pct ~ sector + period, central), 2))

cat("\nSensitivity, all waves (million EUR; change relative to the central scenario, %)\n")
sens <- sum_by(results[results$period == "All waves", ], "scenario")
ref  <- sens[sens$scenario == "Central", ]
sens$cost_change_pct    <- round(100 * (sens$cost_meur / ref$cost_meur - 1), 1)
sens$climate_change_pct <- round(100 * (sens$climate_meur / ref$climate_meur - 1), 1)
print(round3(sens), row.names = FALSE)

cat("\nHalf of the jobs exposed, all waves (million EUR):",
    round(0.5 * by_period$climate_meur[by_period$period == "All waves"], 2), "\n")

# Table 3 of the paper: work intensity (W, bounded to the 200-400 W domain
# of the function) and hourly labour cost in July 2026
july <- as.Date("2026-07-01")
cat("\nSectors (Table 3)\n")
print(data.frame(sector = sectors$sector, jobs = sectors$jobs,
                 watts = round(pmin(pmax(sectors$watts, 200), 400)), exposure = sectors$exposure,
                 cost_hour_july = round(sectors$cost_month / (working_days_in_month(july) * (hour_end - hour_start)), 2)),
      row.names = FALSE)

cat("\nWorking days and WBGT in the sun (degC) by wave\n")
print(do.call(rbind, lapply(names(wave_days), function(name) {
  h <- weather$day %in% wave_days[[name]]
  daily_max <- tapply(weather$wbgt_sun[h], weather$day[h], max)
  data.frame(period = name, working_days = length(unique(weather$day[h & weather$worked])),
             mean_daily_max = round(mean(daily_max), 1), peak = round(max(daily_max), 1))
})), row.names = FALSE)

cat("\nSteepness of the function at 370 W: increase of the lost fraction for +0.3 degC of WBGT\n")
for (w in c(28, 32))
  cat(sprintf("  at %d degC: %+.0f%%\n", w,
              100 * ((1 - work_capacity(w + 0.3, 370)) / (1 - work_capacity(w, 370)) - 1)))

write.csv(results, "output/labour_productivity_results.csv", row.names = FALSE)
