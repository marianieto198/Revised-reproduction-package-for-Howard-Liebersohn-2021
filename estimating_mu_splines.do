
set scheme s1color
*cd "C:\Users\glhoward\Box Sync\Research\Why Is the Rent So Darn High\data"
//cd "C:\Box Sync\Why Is the Rent So Darn High\data"
*cd "C:\Users\liebersohn.1\Box\Why Is the Rent So Darn High\data"

clear all


// If we want to try other versions of the wages data
/*
merge m:1 msa using "../data/acs_wages/processed_data2_educ", nogen
gen collegeshock=wage_college_resid2010-wage_college_resid2000
replace wageshock=wage_resid2010-wage_resid2000
*/

// If we want to use the college wage shock
//replace wageshock = collegeshock

// If we want to use epop
//replace wageshock = epop_change

// Manufacturing share and Bartik shock
// manufacturing/bartik shock
/*
use "..\data\qcew\2000_msa_industry_shares", clear
keep if agglvl_code==73
gen bartik_shock = (national_emp2018/national_emp2000)*industryshare
gcollapse (sum) bartik industryshare, by(msa)
replace bartik_shock = log(bartik + 1-industryshare) // "missing" industry isnt growing
rename bartik_shock bartik
keep bartik msa
tempfile bartik
save `bartik'
*/
use "..\data\qcew\2000_msa_industry_shares", clear
keep if industry_code=="31-33" | industry_code=="1023"
keep industryshare msa industry_code
replace industry_code = "finance" if industry_code=="1023"
replace industry_code ="manufshare" if industry_code == "31-33"
reshape wide industryshare, i(msa) j(industry_code) string
rename industryshare* *
*merge 1:1 msa using `bartik', nogen
tempfile manuf
save `manuf'



use ../data/combineddata, clear

merge m:1 msa using `manuf', nogen

//merge m:1 msa using ../data/acs_wages/epop_data, keep(3) nogen

//merge m:1 msa using "../data/rent_empirical_bayes", keep(3) nogen
gen incomechange=wageshock
gen incomechange_elasticity=incomechange*elasticity
gen elasticity2 = elasticity^2

gen bartik = bartik_wage

preserve
collapse (mean) elasticity, by(msa)



xtile elasticitybin=elasticity, n(10)
xtile elasticitybin2=elasticity, n(10)

mkspline elasticityspline 10=elasticity, disp pct

//local controls="i.elasticitybin"
//local controls="elasticityspline*"
local controls="i.elasticitybin elasticity"

tempfile elasticitybin
save `elasticitybin'
restore
merge m:1 msa using `elasticitybin', nogen


gen manuf_elasticity = manufshare*elasticity
gen bartik_elasticity = bartik*elasticity

preserve
collapse elasticity, by(elasticitybin)
rename elasticity mean_elasticity
rename elasticitybin bin
tempfile mean_elasticity
save `mean_elasticity'
restore

xtset msa year

reghdfe s18.lognoi c.incomechange#i.elasticitybin  if year==2018, absorb(elasticitybin) vce(robust) nocon 

preserve
parmest, fast level(90)
keep if strmatch(parm,"*elasticitybin*")
gen bin=_n
drop if stderr<.00001

merge 1:1 bin using `mean_elasticity'
gen type=0
tempfile nonparametric_noi
save `nonparametric_noi'
restore

reghdfe s18.lognoi incomechange_elasticity incomechange `controls'  if year==2018, noabsorb vce(robust) nocon

nlcom (e0: _b[incomechange]+0*_b[incomechange_elasticity]) ///
	(e1: _b[incomechange]+1*_b[incomechange_elasticity]) ///
	(e2: _b[incomechange]+2*_b[incomechange_elasticity]) ///
	(e3: _b[incomechange]+3*_b[incomechange_elasticity]) ///
	(e4: _b[incomechange]+4*_b[incomechange_elasticity]) ///
	(e5: _b[incomechange]+5*_b[incomechange_elasticity]) ///
	(e6: _b[incomechange]+6*_b[incomechange_elasticity]) ///
	(e7: _b[incomechange]+7*_b[incomechange_elasticity]), post
preserve
parmest, fast level(90)
gen bin=_n-1
gen type=1
append using `nonparametric_noi'
twoway line estimate min90 max90 bin if type==1, lpattern(solid dash dash)  ylabel(,grid)  ///
	lcolor(navy navy navy) yscale(range(0 1)) || scatter estimate mean_elasticity if type==0, color(orange) || ///
	(rspike  min90 max90 mean_elasticity if type==0, lcolor(orange )),  name(rent, replace) ///
	xtitle(Elasticity) ytitle("Effect of Income on Rents (unadjusted)") legend(off)
	
	
graph export "../exhibits/estimating_rent_old.pdf", as(pdf) replace
tempfile noi_estimates
save `noi_estimates'
restore


///////
// House prices
/////

reghdfe s17.loghpi c.incomechange#i.elasticitybin  `controls' if year==2017, noabsorb vce(robust) nocon
preserve
parmest, fast
keep if strmatch(parm,"*elasticitybin*")
drop if stderr<.00001
gen bin=_n
merge 1:1 bin using `mean_elasticity'
//line estimate min95 max95 mean_elasticity, lpattern(solid dash dash) lcolor(navy navy navy) yscale(range(0 1))  || scatter estimate mean_elasticity, color(navy) name(hpi, replace) nodraw xtitle(Elasticity) ytitle(Effect of Income on House Price) legend(off)
gen type=0
tempfile nonparametric_hpi
save `nonparametric_hpi'
restore

reghdfe s17.loghpi incomechange_elasticity incomechange `controls' if year==2017, noabsorb vce(robust) nocon
nlcom (e0: _b[incomechange]+0*_b[incomechange_elasticity]) ///
	(e1: _b[incomechange]+1*_b[incomechange_elasticity]) ///
	(e2: _b[incomechange]+2*_b[incomechange_elasticity]) ///
	(e3: _b[incomechange]+3*_b[incomechange_elasticity]) ///
	(e4: _b[incomechange]+4*_b[incomechange_elasticity]) ///
	(e5: _b[incomechange]+5*_b[incomechange_elasticity]) ///
	(e6: _b[incomechange]+6*_b[incomechange_elasticity]) ///
	(e7: _b[incomechange]+7*_b[incomechange_elasticity]), post
preserve
parmest, fast
gen bin=_n-1
gen type=1
append using `nonparametric_hpi'
twoway line estimate min95 max95 bin if type==1, lpattern(solid dash dash) ylabel(,grid)  ///
	lcolor(navy navy navy) yscale(range(0 1)) || scatter estimate mean_elasticity if type==0, color(orange) || ///
	(rspike  min95 max95 mean_elasticity if type==0, lcolor(orange )),  nodraw name(hpi, replace) ///
	xtitle(Elasticity) ytitle(Effect of Income on House Price) legend(off)
tempfile hpi_estimates
save `hpi_estimates'
restore





//
// Population
//
reghdfe fs18.logpop c.incomechange#i.elasticitybin   if year==2017,  absorb(elasticitybin) vce(robust) nocon
preserve
parmest, fast level(90)
gen bin=_n
keep if strmatch(parm,"*elasticitybin*")
drop if stderr<.00001
merge 1:1 bin using `mean_elasticity'
gen type=0
tempfile nonparametric_pop
save `nonparametric_pop'
restore

reghdfe f2s18.logpop incomechange_elasticity incomechange   `controls'  if year==2016, noabsorb vce(robust) nocon
nlcom (e0: _b[incomechange]+0*_b[incomechange_elasticity]) ///
	(e1: _b[incomechange]+1*_b[incomechange_elasticity]) ///
	(e2: _b[incomechange]+2*_b[incomechange_elasticity]) ///
	(e3: _b[incomechange]+3*_b[incomechange_elasticity]) ///
	(e4: _b[incomechange]+4*_b[incomechange_elasticity]) ///
	(e5: _b[incomechange]+5*_b[incomechange_elasticity]) ///
	(e6: _b[incomechange]+6*_b[incomechange_elasticity]) ///
	(e7: _b[incomechange]+7*_b[incomechange_elasticity]), post
preserve
parmest, fast level(90)
gen bin=_n-1
gen type=1
append using `nonparametric_pop'

//gen expected_pop_change=.7*(bin+2/3) if bin<=3

twoway line estimate min90 max90 bin if type==1, lpattern(solid dash dash) ///
	ylabel(,grid)  lcolor(navy navy navy) yscale(range(0 1)) || ///
	scatter estimate mean_elasticity if type==0, color(orange) || ///
	rspike  min90 max90 mean_elasticity if type==0, lcolor(orange) name(pop, replace) ///
	xtitle(Elasticity) ytitle(Effect of Income on Population) legend(off)
	

	

graph export "../exhibits/estimating_mu_pop.pdf", as(pdf) replace
restore

//
// New Rent
//
reghdfe rent_new c.incomechange#i.elasticitybin  if year==2018 ,  absorb(elasticitybin) vce(robust) nocon
preserve
parmest, fast level(90)
gen bin=_n
keep if strmatch(parm,"*elasticitybin*")
drop if stderr<.00001
merge 1:1 bin using `mean_elasticity'
gen type=0
tempfile nonparametric_pop
save `nonparametric_pop'
restore

reghdfe rent_new incomechange_elasticity incomechange  `controls'  if year==2016, noabsorb vce(robust) nocon
nlcom (e0: _b[incomechange]+0*_b[incomechange_elasticity]) ///
	(e1: _b[incomechange]+1*_b[incomechange_elasticity]) ///
	(e2: _b[incomechange]+2*_b[incomechange_elasticity]) ///
	(e3: _b[incomechange]+3*_b[incomechange_elasticity]) ///
	(e4: _b[incomechange]+4*_b[incomechange_elasticity]) ///
	(e5: _b[incomechange]+5*_b[incomechange_elasticity]) ///
	(e6: _b[incomechange]+6*_b[incomechange_elasticity]) ///
	(e7: _b[incomechange]+7*_b[incomechange_elasticity]) , post
preserve
parmest, fast level(90)
gen bin=_n-1
gen type=1
append using `nonparametric_pop'
twoway line estimate min90 max90 bin if type==1, lpattern(solid dash dash) ylabel( ,grid) ///
	lcolor(navy navy navy) yscale(range(0 1)) || scatter estimate mean_elasticity if type==0, color(orange) || ///
	rspike  min90 max90 mean_elasticity if type==0,   lcolor(orange) name(rent_new, replace) ///
	xtitle(Elasticity) ytitle(Effect of Income on Rent) legend(off) yscale(range(-1 3)) ylabel(#5)
graph export "../exhibits/estimating_rent_new.pdf", as(pdf) replace
restore

//
// graph combine  rent_new rent pop, ycommon
//
//
// graph export "../exhibits/estimating_mu.pdf", as(pdf) replace


summ elasticity if year==2000 & rent_new!=.
local meanelasticity=r(mean)
gen demeanedelasticity=elasticity-`meanelasticity'


gen bartikelasticity=bartik*demeanedelasticity
gen incomeelasticity=incomechange*demeanedelasticity
gen manufelasticity=manufshare*demeanedelasticity

label var incomechange "Income Change"
label var manufshare "Manufacturing Share"
label var incomeelasticity "Income Change by Elasticity"
label var manufelasticity "Manufacturing Share by Elasticity"
label var bartikelasticity "Bartik by Elast."
label var bartik "Bartik Shock"
label var rent_new "Rent"

gen rents=s18.lognoi 
label var rents "Raw Rent"
gen houseprices =s17.loghpi

label var houseprices "House Price"

reghdfe rents  bartik bartikelasticity  `controls'   if year==2018, noabsorb vce(robust) nocon
est sto noi_bartik
estadd local elast_control "X"


nlcom (impliedinvmu:_b[bartikelasticity]/_b[bartik]), post l(90)
est sto noi_manuf_mu

reghdfe rents  manufshare demeanedelasticity manufelasticity  `controls'  if year==2018, noabsorb vce(robust) nocon
est sto noi_manuf
estadd local elast_control "X"

nlcom (impliedinvmu:_b[manufelasticity]/_b[manufshare]), post l(90)
est sto noi_manuf_mu

reghdfe rents  incomechange demeanedelasticity incomeelasticity `controls'   if year==2018, noabsorb vce(robust) nocon
est sto noi_incomechange
estadd local elast_control "X"

nlcom (impliedinvmu:_b[incomeelasticity]/_b[incomechange]), post l(90)
est sto noi_income_mu

/*
reghdfe houseprices   bartik demeanedelasticity bartikelasticity  `controls'   if year==2017, noabsorb vce(robust) nocon
est sto hpi_bartik
reghdfe houseprices  manufshare demeanedelasticity manufelasticity  `controls'  if year==2017, noabsorb vce(robust) nocon
est sto hpi_manuf
nlcom (impliedinvmu:_b[manufelasticity]/_b[manufshare]), post l(90)
est sto hpi_manuf_mu
reghdfe houseprices  incomechange demeanedelasticity incomeelasticity  `controls'  if year==2017, noabsorb vce(robust) nocon
est sto hpi_incomechange
nlcom (impliedinvmu:_b[incomeelasticity]/_b[incomechange]), post l(90)
est sto hpi_income_mu
*/
reghdfe incomechange bartik bartikelasticity  `controls'   if year==2018, noabsorb vce(robust) 
est sto incomechange_bartik
estadd local elast_control "X"

reghdfe rent_new bartik bartikelasticity  `controls'   if year==2018, noabsorb vce(robust) 
est sto rent_new_bartik
estadd local elast_control "X"

reghdfe rent_new  manufshare demeanedelasticity manufelasticity  `controls'  if year==2017, noabsorb vce(robust) nocon
est sto rent_new_manuf
estadd local elast_control "X"

nlcom (impliedinvmu:_b[manufelasticity]/_b[manufshare]), post l(90)
est sto rent_new_manuf_mu

reghdfe rent_new  incomechange demeanedelasticity incomeelasticity  `controls'  if year==2017, noabsorb vce(robust) nocon
est sto rent_new_incomechange
estadd local elast_control "X"

nlcom (impliedinvmu:_b[incomeelasticity]/_b[incomechange]), post l(90)
est sto rent_new_income_mu

local note "Robust standard errors. Specifications include controls for deciles of elasticity and a linear control."
esttab rent_new_incomechange rent_new_manuf rent_new_bartik  noi_incomechange noi_manuf noi_bartik using "../exhibits/estimating_mu_table.tex", ///
	keep(bartik bartikelasticity  manufshare manufelasticity incomechange incomeelasticity) se tex replace label star(* .1 ** .05 *** .01) addnote("`note'") scalars("elast_control Controls")
// esttab rent_new_income_mu rent_new_manuf_mu noi_income_mu noi_manuf_mu using "../exhibits/impliedinvmu_table.tex",  ci tex replace label level(90) addnote("`note'") scalars("elast_control Controls")


//esttab incomechange_bartik rent_new_bartik, drop(`controls' _cons)
//
// ivreg2 rent_new (incomechange incomeelasticity=bartik  bartikelasticity) `controls'   if year==2018,  robust partial( `controls' )
// e//st sto rent_new_bartik
//
//
//
// ivreg2 rents (incomechange incomeelasticity=bartik  bartikelasticity) `controls'   if year==2018,  robust 
// //est sto rent_new_bartik
//stop


esttab rent_new_incomechange rent_new_manuf rent_new_bartik  noi_incomechange noi_manuf noi_bartik, ///
	ci keep(income* bartik* manuf*) level(90) star(* .1 ** .05 *** .01)


