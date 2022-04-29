/*
Author(s): Greg Howard & Jack Liebersohn
Date:2021

Description: Script para producir Tabla A1 - Efectos heterogéneos de cambio en el ingreso sobre costos de housing, por elasticidad 
*/

//Fondo color blanco para la salida

set scheme s1color
*cd "C:\Users\glhoward\Box Sync\Research\Why Is the Rent So Darn High\data"
*cd "C:\Users\liebersohn.1\Box\Why Is the Rent So Darn High\data"
//cd "C:\Users\liebersohn.1\Box\Why Is the Rent So Darn High\data"

clear all


// create the PCA of the employment variables using the same code as in oes_lasso do file
// use "../data/epop/epop_msa", clear
// xtset msa year
// gen epop_change=s18.epop
// keep if year==2018
// drop year
// cap log close
*log using ../dofiles/oes_lasso.txt, text replace

//Especificar valor inicial
set seed 10
//Se usa combineddata como en la mayoría de dofiles
use "../data/combineddata"
//Cambio en población para año 2000
gen epop_change=f18s18.epop if year==2000
//Panel de datos
xtset msa year
//Utilizan el cambio en renta transformado para el año 2000
gen rentchange=rent_new if year==2000
//merge m:1 msa using ../data/amenities_measures/amen_index_all, keep(1 3) nogen
keep if year==2000
//keep msa rentchange elasticity pop amen_index wageshock wageshock_college wageshock_level dsoi_income dsoi_income_level  epop_change school crime retail gk_elasticity road environment jobs jantemp 
//merge 1:1 msa using "../data/oes/oesdata", keep(1 3)

local empvars="wageshock wageshock_college wageshock_level dsoi_income dsoi_income_level  epop_change  a_* h_*"
//Principal component analysis si hay missing values en variables distintas a rentchange (rent transformada año 2000) - predecir
qui pca `empvars'  if rentchange!=.
predict pca_emp
keep msa pca_emp
tempfile pca
save `pca'

// manufacturing/bartik shock
use "..\data\qcew\2000_msa_industry_shares", clear
keep if agglvl_code==73

//Bartik shock predicts local job growth using the interaction of local labor shares and industry-specific wage growth in other regions. 
gen bartik_inc = (national_emp2018/national_emp2000)*industryshare
collapse (sum) /*bartik*/ industryshare, by(msa)
*replace bartik_wage = log(bartik_wage + 1-industryshare) // "missing" industry isnt growing
keep msa
tempfile bartik
save `bartik'

//En este dofile se usan los industry shares del Quarterly Census of Employment and Wages (u)
use "..\data\qcew\2000_msa_industry_shares", clear
//Se mantienen industrias específicas (string)
keep if industry_code=="31-33" | industry_code=="1023"
//En la base de datos no es claro a qué corresponden los códigos de estas industries, pero a continuación se especifica (finance o manufshare)
keep industryshare msa industry_code
replace industry_code = "finance" if industry_code=="1023"
replace industry_code ="manufshare" if industry_code == "31-33"
//i (lugar - área metropolitana) 
reshape wide industryshare, i(msa) j(industry_code) string
rename industryshare* *
*merge 1:1 msa using `bartik', nogen
tempfile manuf
save `manuf'

set scheme s1color
clear all
use "../data/combineddata"

keep if elasticity!=.

*replace elasticity = -unaval


* optionally noise up the estimates
*replace elasticity = elasticity+rnormal()

local mynumreps 500
//Se generan variables diferenciadas para 2017 y 2018. Tener en cuenta que en general el análisis se ha realizado hasta 2017 hasta el momento en el paper

gen s18lognoi_adj=s18.lognoi_adj if year==2018
gen s17loghpi = s17.loghpi if year==2017

//Preparación de variables para la tabla. Se destaca que en este caso sí se esta incluyendo la elasticidad 
collapse (max) s18lognoi_adj s17loghpi rent_new (first) bartik* wageshock gk_elasticity elasticity unaval WRLURI, by(msa)

summ elasticity if rent_new !=.
local meanelasticity=r(mean)
replace elasticity=elasticity-`meanelasticity'

//Gorback-Keys elasticity
summ gk_elasticity if rent_new !=.
local meangk=r(mean)
replace gk_elasticity=gk_elasticity-`meangk'

sum unaval if rent_new!=.
replace unaval =unaval-`=r(mean)'

reg elasticity WRLURI

predict elasticity_fitted
qui sum elasticity_fitted
replace elasticity_fitted =elasticity_fitted -`=r(mean)'
reg elasticity_fitted unaval

//Elast. deciles
xtile elastfitbin=elasticity_fitted , n(10)


merge 1:1 msa using `manuf', nogen
merge 1:1 msa using `pca', nogen

xtile elasticitybin=elasticity, n(10)

xtile unavalbin=unaval, n(10)

xtile gkbin=gk_elasticity, n(10)

//Generar las variables finales y las interacciones 
gen incomechange=wageshock
gen bartikelasticity=bartik_wage*elasticity
gen incomeunaval = incomechange*unaval
gen manufshareunaval = manufshare*unaval
gen incomechange_elasticity=incomechange*elasticity
gen incomechange_gkelasticity=incomechange*gk_elasticity
gen manuf_elasticity = manufshare*elasticity

gen bartikelast_fit = bartik_wage*elasticity_fitted
gen bartikunaval = bartik_wage*unaval

gen incomeelast_fit = incomechange*elasticity_fitted

//Descripción de las variables tal como aparecerá en la tabla
label var bartikelasticity "Bartik by Elast."
label var bartik_wage "Bartik Shock"
label var incomeunaval "Income Change by Unavailable Land"
label var incomechange "Income Change"
label var manufshare "Manufacturing Share"
label var manufshareunaval "Manuf. Share by Unavailable Land"
label var unaval "Unavailable Land"
label var incomechange_elasticity "Income Chg. by Elast."
label var manuf_elasticity "Mnf. Share by Elast."
label var gk_elasticity "Gorback-Keys Elasticity"
label var incomechange_gkelasticity "Income Chg by Gorback-Keys Elast."
label var incomeelast_fit "Income Chg by Regulation"

* create new rent and rent (unadjusted) variables for the IV specificaitons
* this makes it easier for them to have their own labels
gen rent_new_iv = rent_new
label var rent_new_iv "Rent (IV)"
gen s18lognoi_adj_iv=s18lognoi_adj
label var s18lognoi_adj_iv  "Rent (unadjusted, IV)"

gen pcaelasticity=pca_emp*elasticity

label var pcaelasticity "PCA Emp by Elasticity"
label var pca_emp "PCA Employment"

label var s18lognoi_adj "Rent (undadjusted)"
label var rent_new "Rent"


//Regresiones
reghdfe s18lognoi_adj incomechange elasticity incomechange_elasticity,  absorb(unavalbin elasticitybin)
est sto noi_unaval
estadd local elast_control "X"
estadd local unaval_control "X"

reghdfe rent_new incomechange elasticity incomechange_elasticity,  absorb(unavalbin elasticitybin)
est sto rent_new_unaval
estadd local elast_control "X"
estadd local unaval_control "X"

reghdfe s18lognoi_adj manufshare elasticity manuf_elasticity,  absorb(unavalbin elasticitybin)
est sto noi_manufunaval
estadd local elast_control "X"
estadd local unaval_control "X"

reg s18lognoi_adj pca_emp elasticity pcaelasticity, r absorb(elasticitybin)
est sto noi_pca
estadd local elast_control "X"

reghdfe rent_new manufshare elasticity manuf_elasticity,  absorb(unavalbin elasticitybin)
est sto rent_new_manufunaval
estadd local elast_control "X"
estadd local unaval_control "X"



reg rent_new pca_emp elasticity pcaelasticity, r absorb(elasticitybin)
est sto rent_new_pca
estadd local elast_control "X"


reghdfe rent_new incomechange gk_elasticity incomechange_gkelasticity,  absorb(gkbin)
est sto rent_new_gkelast
estadd local gk_control "X"
estadd local elast_control "X"

reghdfe s18lognoi_adj incomechange gk_elasticity incomechange_gkelasticity,  absorb(gkbin)
est sto noi_gkelast
estadd local gk_control "X"
estadd local elast_control "X"

ivreghdfe s18lognoi_adj_iv  incomechange elasticity  (incomeelast_fit=bartikunaval), r absorb(elasticitybin) first
est sto elast_fit_noi
estadd local elast_control "X"
estadd local unaval_control "X"

ivreghdfe rent_new_iv  incomechange elasticity  (incomeelast_fit=bartikunaval), r absorb(elasticitybin) first
est sto elast_fit_rentnew
estadd local elast_control "X"
estadd local unaval_control "X"

//Notar que se genera una tabla inferior en la que se marcan con "X" si cada una de las regresiones concuerda :
//elasticity deciles, unavailable deciles, gorback-keys elasticity (estimaciones de estos autores en 2020)

//Preparación para salida

//AD- A esta tabla le hace falta una nota al pie para quedar como la que está publicada, se agrega.

esttab rent_new_unaval rent_new_manufunaval rent_new_pca  noi_unaval noi_manufunaval noi_pca rent_new_gkelast noi_gkelast elast_fit_rentnew elast_fit_noi  /*noi_bartik hpi_bartik*/ ///
	using "../exhibits/estimating_mu_appendixtable.tex", drop(elasticity _cons) se tex replace label star(* .1 ** .05 *** .01) ///
	addnote("Robust standard errors.") addnote("Standard errors in parentheses.")  scalars("elast_control Elast. Deciles" "unaval_control Unavail. Deciles" "gk_control Gorback-Keys Elast.")
