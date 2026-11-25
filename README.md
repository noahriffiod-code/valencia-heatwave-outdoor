# Labour productivity cost of the 2026 heatwaves for outdoor work in Valencia

Code and data for the outdoor work section of *Attributing the economic cost of the summer 2026 heatwaves in Valencia to climate change*, N. Riffiod, A.G. Fernández-Garza,
D. Ávila-Velásquez, E. Gielen and M. Pulido-Velazquez (2026).

The analysis estimates the direct cost of the heat-induced loss of work
capacity for outdoor work in the city of Valencia during the three official
AEMET heatwaves of summer 2026 (20-27 June, 2-24 July, 28 July-20 August), and
the part of it attributable to climate change. Wave 4 (2-7 September) is
provisional in the AEMET note and is excluded. It follows
Orlov et al. (2020), applied to hourly data:

1. **Heat stress.** Hourly WBGT in the shade (Orlov et al. 2020, eq. 2.2.1;
   Lemke and Kjellstrom 2012, eq. 8) and in the sun (Liljegren et al. 2008,
   through the R package HeatStressR), from ERA5 (Hersbach et al. 2020).
2. **Work capacity.** HOTHAPS function (Orlov et al. 2020, eq. 2.3.1),
   interpolated in work intensity; intensities from Orlov et al. (2020),
   the 2024 Compendium of Physical Activities (Herrmann et al. 2024) and
   Tudor-Locke et al. (2011).
3. **Cost.** Hours lost on weekdays between 7:00 and 15:00, valued at the
   total labour cost of the INE (ETCL, 2026 Q2) for five sectors:
   construction, water and waste, warehousing, postal and courier, buildings
   and landscape. Employment: Social Security affiliations in the city at
   31 December 2024 (Ajuntament de València 2025).
4. **Climate change.** Counterfactual temperature T - delta, with the monthly
   attributable warming of Barnes et al. (2026), available for June to
   August.

The general equilibrium model used by Orlov et al. (2020) is not reproduced:
only the direct cost is computed.

## Main results (central scenario, all jobs exposed, million EUR)

| Wave | Dates | Working days | Cost | Attributable to climate change |
|---|---|---:|---:|---:|
| 1 | 20-27 Jun | 5 | 2.159 | 1.013 (0.690-1.272) |
| 2 | 2-24 Jul | 17 | 13.098 | 4.969 (3.142-6.568) |
| 3 | 28 Jul-20 Aug | 18 | 17.833 | 6.495 (4.427-8.354) |
| All | | 40 | 33.090 | 12.477 (8.258-16.193) |

Ranges use the bounds of the 95% interval of the attributable warming.
Figures from a run with HeatStressR 3.0.0; the last digit may differ by rounding.
The script also prints every other figure of the outdoor-work section of
the paper: Table 3 (intensity and hourly labour cost), the working days and
WBGT in the sun by wave, the cost by sector (Table 8), the share of hours
lost by sector, the sensitivity to work intensity, to sun or shade exposure
and to the wind height (all on the three waves), the cost with half of the
jobs exposed, and the steepness of the work-capacity function.

## Running the code

Requirements: R and the package HeatStressR 3.0.0 (which installs its
dependency heatindex from CRAN). Open `valencia_heatwave_outdoor.Rproj` (or
set the working directory to the repository root) and run

```r
install.packages("remotes")
remotes::install_github("zyf0717/HeatStressR@v3.0.0")
source("labour_productivity.R")
```

Results are printed and written to `output/labour_productivity_results.csv`.
The script reads only the files in `data/`; nothing is downloaded.

## Data

| File | Content | Source |
|---|---|---|
| `era5_valencia_hourly_2026-06-01_2026-09-30.csv` | ERA5 hourly, local and UTC time | Open-Meteo archive API (Zippenfenig 2023), `models=era5`, `elevation=nan`, `cell_selection=land`, nearest land cell to AEMET station 8416, retrieved 4 Nov 2026 |
| `delta_barnes_2026_valencia.csv` | Attributable warming by month, 95% interval | Computed from Barnes et al. (2026), [doi:10.5281/zenodo.22228326](https://doi.org/10.5281/zenodo.22228326), city ES003C |
| `heatwaves_aemet_2026.csv` | Dates of the 2026 heatwaves | AEMET, note of 9 Sep 2026, [link](https://www.aemet.es/es/noticias/2026/09/olas_de_calor_2026) |

Employment, labour costs and work intensities are entered in
`labour_productivity.R` with their source.

### Data sources and licences

- **ERA5**: Contains modified Copernicus Climate Change Service information
  2026. Neither the European Commission nor ECMWF is responsible for any use
  that may be made of the Copernicus information or data it contains.
  Weather data by [Open-Meteo.com](https://open-meteo.com/), licensed under
  [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/); column names
  changed.
- **AEMET**: © AEMET. Information prepared using, among others, data from
  the Agencia Estatal de Meteorología. Reused under the AEMET terms
  ([nota legal](https://www.aemet.es/es/nota_legal)); AEMET does not endorse
  this work.
- **INE**: Own elaboration with data extracted from the INE website,
  www.ine.es. Reused under CC BY 4.0
  ([aviso legal](https://ine.es/dyngs/AYU/index.htm?cid=125)); the INE does
  not endorse this work.
- **Barnes et al. (2026)**: monthly values derived from the authors' data
  and code (doi:10.5281/zenodo.22228326, CC BY 4.0).
- **Employment**: figures from the Ajuntament de València statistical
  yearbook (Social Security affiliations; source Ministerio de Trabajo y
  Economía Social).
- **Work intensities**: MET values from Herrmann et al. (2024) and
  Tudor-Locke et al. (2011), cited by activity code, not reproduced.
- **HeatStressR** (Zheng, with code from the HeatStress package of
  A. Casanueva) is GPL-3. It is called as an R dependency and is not
  distributed with this repository.

## Main assumptions

- All Social Security affiliations of each sector are exposed (high
  assumption; undeclared jobs are not counted).
- Work from 7:00 to 15:00, Monday to Friday; public holidays and August
  holidays not removed.
- Sun exposure for construction, water and waste, postal and courier,
  buildings and landscape; shade for warehousing.
- ERA5 wind at 10 m converted to 2 m with FAO-56 eq. 47 (Allen et al. 1998),
  as HeatStressR expects wind at 2 m.
- Sun position at the middle of the hour, ERA5 radiation being the mean of
  the preceding hour.
- MET converted to watts with a 70 kg reference body mass.
- Counterfactual: same dew point (capped at the new temperature), wind,
  radiation and pressure.

## License

Code: MIT (see `LICENSE`). Data files remain under the terms of their
providers listed above.

## Citation

See `CITATION.cff`.

## References

AEMET (2026). España registra 61 días bajo ola de calor en 2026, más que en
ningún otro año. Agencia Estatal de Meteorología, 9 September 2026.
https://www.aemet.es/es/noticias/2026/09/olas_de_calor_2026

Ajuntament de València (2025). Anuario estadístico 2025, chapter 7, file
070401_AfiliacionSS.xlsx (Social Security affiliations at 31 December 2024).
https://www.valencia.es/val/estadistica/anuari-estadistica?capitulo=7

Allen, R. G., Pereira, L. S., Raes, D., Smith, M. (1998). *Crop
evapotranspiration: guidelines for computing crop water requirements*. FAO
Irrigation and Drainage Paper 56. FAO, Rome.

Barnes, C., Masselot, P., Xi, D., Clarke, B., Rayner, A., Chen, X., Wang, R.,
Raju, E., Theokritoff, E., Mistry, M., Gasparrini, A., Otto, F.,
Vicedo-Cabrera, A. M., Konstantinoudis, G. (2026). Heat-related urban
mortality attributable to human-induced climate change in Europe from 2000
to 2025. *Nature Health*. https://doi.org/10.1038/s44360-026-00209-8. Data
and code: https://doi.org/10.5281/zenodo.22228326

Herrmann, S. D., Willis, E. A., Ainsworth, B. E., et al. (2024). 2024 Adult
Compendium of Physical Activities: a third update of the energy costs of human
activities. *Journal of Sport and Health Science*, 13(1), 6-12.
https://doi.org/10.1016/j.jshs.2023.10.010

Hersbach, H., Bell, B., Berrisford, P., et al. (2020). The ERA5 global
reanalysis. *Quarterly Journal of the Royal Meteorological Society*,
146(730), 1999-2049. https://doi.org/10.1002/qj.3803

INE (2026). Encuesta Trimestral de Coste Laboral, table 6061 and press
release for the second quarter of 2026. Instituto Nacional de Estadística.
https://www.ine.es/jaxiT3/files/t/es/csv_bdsc/6061.csv ;
https://www.ine.es/dyngs/Prensa/ETCL2T26.pdf

Kjellstrom, T., Freyberg, C., Lemke, B., Otto, M., Briggs, D. (2018).
Estimating population heat exposure and impacts on working people in
conjunction with climate change. *International Journal of Biometeorology*,
62(3), 291-306. https://doi.org/10.1007/s00484-017-1407-0

Lemke, B., Kjellstrom, T. (2012). Calculating workplace WBGT from
meteorological data: a tool for climate change assessment. *Industrial
Health*, 50(4), 267-278. https://doi.org/10.2486/indhealth.MS1352

Liljegren, J. C., Carhart, R. A., Lawday, P., Tschopp, S., Sharp, R. (2008).
Modeling the wet bulb globe temperature using standard meteorological
measurements. *Journal of Occupational and Environmental Hygiene*, 5(10),
645-655. https://doi.org/10.1080/15459620802310770

Orlov, A., Sillmann, J., Aunan, K., Kjellstrom, T., Aaheim, A. (2020).
Economic costs of heat-induced reductions in worker productivity due to
global warming. *Global Environmental Change*, 63, 102087.
https://doi.org/10.1016/j.gloenvcha.2020.102087

Tudor-Locke, C., Ainsworth, B. E., Washington, T. L., Troiano, R. (2011).
Assigning metabolic equivalent values to the 2002 census occupational
classification system. *Journal of Physical Activity and Health*, 8(4),
581-586. https://doi.org/10.1123/jpah.8.4.581

Zheng, Y. (2026). HeatStressR: calculate heat stress indices. R package
version 3.0.0 (fork of HeatStress by A. Casanueva). CRAN.
https://github.com/cran/HeatStressR

Zippenfenig, P. (2023). Open-Meteo.com Weather API. Zenodo.
https://doi.org/10.5281/zenodo.7970649
