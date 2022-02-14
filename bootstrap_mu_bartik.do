
//
// alternative elasticity measures still yield large estimates
//
set seed 15
clear
// create the PCA of the employment variables using the same code as in oes_lasso do file
use "../data/combineddata"
gen epop_change=f18s18.epop if year==2000

xtset msa year
gen rentchange=f18s18.lognoi if year==2000
//merge m:1 msa using ../data/amenities_measures/amen_index_all, keep(1 3) nogen
keep if year==2000
//keep msa rentchange elasticity pop amen_index wageshock wageshock_college wageshock_level dsoi_income dsoi_income_level  epop_change school crime retail road environment jobs jantemp
//merge 1:1 msa using "../data/oes/oesdata", keep(1 3)
local empvars="wageshock wageshock_college wageshock_level dsoi_income dsoi_income_level  epop_change  a_* h_*"
qui pca `empvars'  if rentchange!=.
predict pca_emp
keep msa pca_emp
tempfile pca
save `pca'



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



set scheme s1color
clear all
use "../data/combineddata"
keep if elasticity!=.

*replace elasticity = -unaval


* optionally noise up the estimates
*replace elasticity = elasticity+rnormal()

local mynumreps 1000

gen s18lognoi_adj=s18.lognoi_adj if year==2018
gen s17loghpi = s17.loghpi if year==2017

collapse (max) s18lognoi_adj rent_new (first) wageshock bartik_* elasticity unaval WRLURI, by(msa)


summ elasticity if rent_new !=.
local meanelasticity=r(mean)
replace elasticity=elasticity-`meanelasticity'

merge 1:1 msa using `manuf', nogen
merge 1:1 msa using `pca', nogen

xtile elasticitybin=elasticity, n(10)
*mkspline elasticityspline 10=elasticity, disp pct

reg s18lognoi_adj c.bartik_wage##c.elasticity , r absorb(elasticitybin)
reg rent_new c.bartik_wage##c.elasticity , r absorb(elasticitybin)

*local controls="i.elasticitybin elasticity"
*reghdfe rent_new bartik_wage  c.bartik_wage#c.elasticity  `controls'   if year==2018, noabsorb vce(robust) 


// Bootstrap PCA
tempfile alldat // drop obs missing pca, but save a version of the file before I do this so that I can restore it at the end of the PCA section
save `alldat' 
keep if !missing(pca)

cap program drop myreg
program def myreg, eclass
	qui reg s18lognoi_adj c.pca_emp##c.elasticity , absorb(elasticitybin) r 
	local ratio = -_b[c.pca_emp]/_b[c.pca_emp#c.elasticity]
	local ratio = 100000*(`ratio'<=0) + `ratio'*(`ratio'>0)
	ereturn scalar ratio=`ratio'
end

tempfile bootdat
bootstrap ratio=e(ratio), reps(`mynumreps') seed(10) saving(`bootdat'): myreg
local mu2=_b[ratio]-(`meanelasticity'+.66667)

preserve
use `bootdat', clear
sum ratio, det
local mu2_p5=r(p5)-(`meanelasticity'+.66667)
local mu2_p10=r(p10)-(`meanelasticity'+.66667)
restore


cap program drop myreg
program def myreg, eclass
	qui reg rent_new c.pca_emp##c.elasticity, absorb(elasticitybin) r 
	local ratio = -_b[c.pca_emp]/_b[c.pca_emp#c.elasticity]
	local ratio = 100000*(`ratio'<=0) + `ratio'*(`ratio'>0)
	ereturn scalar ratio=`ratio'
end

tempfile bootdat
bootstrap ratio=e(ratio), reps(`mynumreps') seed(10) saving(`bootdat'): myreg
local mu4=_b[ratio]-(`meanelasticity'+.66667)

preserve
use `bootdat', clear
sum ratio, det
local mu4_p5=r(p5)-(`meanelasticity'+.66667)
local mu4_p10=r(p10)-(`meanelasticity'+.66667)
restore
use `alldat', clear



// Bootstrap Bartik
cap program drop myreg
program def myreg, eclass
	qui reg s18lognoi_adj c.bartik_wage##c.elasticity, absorb(elasticitybin) r 
	local ratio = -_b[c.bartik_wage]/_b[c.bartik_wage#c.elasticity]
	local ratio = 100000*(`ratio'<=0) + `ratio'*(`ratio'>0)
	ereturn scalar ratio=`ratio'
end

tempfile bootdat
bootstrap ratio=e(ratio), reps(`mynumreps') seed(10) saving(`bootdat'): myreg
local mu1=_b[ratio]-(`meanelasticity'+.66667)

preserve
use `bootdat', clear
sum ratio, det
local mu1_p5=r(p5)-(`meanelasticity'+.66667)
local mu1_p10=r(p10)-(`meanelasticity'+.66667)
restore


cap program drop myreg
program def myreg, eclass
	qui reg rent_new c.bartik_wage##c.elasticity, absorb(elasticitybin) r 
	local ratio = -_b[c.bartik_wage]/_b[c.bartik_wage#c.elasticity]
	local ratio = 100000*(`ratio'<=0) + `ratio'*(`ratio'>0)
	ereturn scalar ratio=`ratio'
end

tempfile bootdat
bootstrap ratio=e(ratio), reps(`mynumreps') seed(10) saving(`bootdat'): myreg
local mu3=_b[ratio]-(`meanelasticity'+.66667)

preserve
use `bootdat', clear
sum ratio, det
local mu3_p5=r(p5)-(`meanelasticity'+.66667)
local mu3_p10=r(p10)-(`meanelasticity'+.66667)
restore



// IV Specification for appendix
cap gen rent_old = s18lognoi_adj
gen incomechange=wageshock
gen bartikunaval = bartik_wage*unaval

reg elasticity WRLURI

predict elasticity_fitted
qui sum elasticity_fitted
replace elasticity_fitted =elasticity_fitted -`=r(mean)'
reg elasticity_fitted unaval
xtile elastfitbin=elasticity_fitted , n(10)

gen incomeelast_fit = incomechange*elasticity_fitted
gen bartikelast_fit = bartik_wage*elasticity_fitted

cap program drop myreg
program def myreg, eclass
	args name
	qui ivreghdfe `name'  incomechange elasticity  (incomeelast_fit=bartikunaval), r absorb(elasticitybin)
	local ratio = -_b[c.incomechange]/_b[incomeelast_fit]
	local ratio = 100000*(`ratio'<=0) + `ratio'*(`ratio'>0)
	ereturn scalar ratio=`ratio'
end

foreach name in rent_old rent_new {

	tempfile bootdat
	bootstrap ratio=e(ratio), reps(`mynumreps') seed(10) saving(`bootdat'): myreg `name'
	local `name'_mean=_b[ratio]-(`meanelasticity'+.66667)

	preserve
	use `bootdat', clear
	sum ratio, det
	local `name'_p5=r(p5)-(`meanelasticity'+.66667)
	local `name'_p10=r(p10)-(`meanelasticity'+.66667)
	restore
}


* bartik
di "basic2 newrent bartik mean: `mu3' p5: `mu3_p5' p10: `mu3_p10'"
di "basic2 oldrent bartik mean: `mu1' p5: `mu1_p5' p10: `mu1_p10'"

* pca
di "basic2 newrent pca mean: `mu4' p5: `mu4_p5' p10: `mu4_p10'"
di "basic2 oldrent pca mean: `mu2' p5: `mu2_p5' p10: `mu2_p10'"

* IV specification for appendix
di "basic2 newrent IV  mean: `rent_new_mean' p5: `rent_new_p5' p10: `rent_new_p10'"
di "basic2 oldrent IV mean: `rent_old_mean' p5: `rent_old_p5' p10: `rent_old_p10'"
