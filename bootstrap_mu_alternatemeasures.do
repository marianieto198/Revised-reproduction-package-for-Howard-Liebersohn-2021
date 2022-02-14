

//
// alternative elasticity measures still yield large estimates
//
set seed 15

use "..\data\qcew\2000_msa_industry_shares", clear
keep if agglvl_code==73
gen bartik_shock = (national_emp2018/national_emp2000)*industryshare
collapse (sum) bartik industryshare, by(msa)
replace bartik_shock = log(bartik + 1-industryshare) // "missing" industry isnt growing
keep bartik msa
tempfile bartik
save `bartik'
use "..\data\qcew\2000_msa_industry_shares", clear
keep if industry_code=="31-33" | industry_code=="1023"
keep industryshare msa industry_code
replace industry_code = "finance" if industry_code=="1023"
replace industry_code ="manufshare" if industry_code == "31-33"
reshape wide industryshare, i(msa) j(industry_code) string
rename industryshare* *
merge 1:1 msa using `bartik', nogen
tempfile manuf
save `manuf'



set scheme s1color
clear all
use "../data/combineddata"
keep if elasticity!=.



local mynumreps 1000
	
gen s18lognoi_adj=s18.lognoi_adj if year==2018
*gen s17loghpi = s17.loghpi if year==2017

collapse (max) s18lognoi_adj rent_new (first) gk_elasticity wageshock elasticity unaval WRLURI, by(msa)


summ elasticity if rent_new !=.
local meanelasticity=r(mean)
replace elasticity=elasticity-`meanelasticity'

merge 1:1 msa using `manuf', nogen

xtile elasticitybin=elasticity, n(10)
xtile unavalbin=unaval, n(10)
xtile wrluribin=WRLURI, n(10)
mkspline elasticityspline 10=elasticity, disp pct

cap program drop myreg
program def myreg, eclass
	qui reghdfe s18lognoi_adj c.wageshock##c.elasticity , absorb(elasticitybin unavalbin)
	local ratio = -_b[c.wageshock]/_b[c.wageshock#c.elasticity]
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

cap program drop myreg2
program def myreg2, eclass
	qui reghdfe s18lognoi_adj c.manufshare##c.elasticity , absorb(elasticitybin unavalbin)
	local ratio = -_b[c.manufshare]/_b[c.manufshare#c.elasticity]
	local ratio = 100000*(`ratio'<=0) + `ratio'*(`ratio'>0)
	ereturn scalar ratio=`ratio'
end

tempfile bootdat
bootstrap ratio=e(ratio), reps(`mynumreps') seed(10) saving(`bootdat'): myreg2
local mu2=_b[ratio]-(`meanelasticity'+.66667)

preserve
use `bootdat', clear
sum ratio, det
local mu2_p5=r(p5)-(`meanelasticity'+.66667)
local mu2_p10=r(p10)-(`meanelasticity'+.66667)
restore

cap program drop myreg3
program def myreg3, eclass
	qui reghdfe rent_new c.wageshock##c.elasticity , absorb(elasticitybin unavalbin)
	local ratio = -_b[c.wageshock]/_b[c.wageshock#c.elasticity]
	local ratio = 100000*(`ratio'<=0) + `ratio'*(`ratio'>0)
	ereturn scalar ratio=`ratio'
end

tempfile bootdat
bootstrap ratio=e(ratio), reps(`mynumreps') seed(10) saving(`bootdat'): myreg3
local mu3=_b[ratio]-(`meanelasticity'+.66667)

preserve
use `bootdat', clear
sum ratio, det
local mu3_p5=r(p5)-(`meanelasticity'+.66667)
local mu3_p10=r(p10)-(`meanelasticity'+.66667)
restore

reghdfe rent_new c.manufshare##c.elasticity  , absorb(elasticitybin unavalbin)
cap program drop myreg4
program def myreg4, eclass
	qui reghdfe rent_new c.manufshare##c.elasticity, absorb(elasticitybin unavalbin)
	local ratio = -_b[c.manufshare]/_b[c.manufshare#c.elasticity]
	local ratio = 100000*(`ratio'<=0) + `ratio'*(`ratio'>0)
	ereturn scalar ratio=`ratio'
end

tempfile bootdat
bootstrap ratio=e(ratio), reps(`mynumreps') seed(10) saving(`bootdat'): myreg4
local mu4=_b[ratio]-(`meanelasticity'+.66667)

preserve
use `bootdat', clear
sum ratio, det
local mu4_p5=r(p5)-(`meanelasticity'+.66667)
local mu4_p10=r(p10)-(`meanelasticity'+.66667)
restore


//
// Gorback-keys elasticity
//
cap gen incomechange = wageshock 
cap gen incomechange_gkelasticity=incomechange*gk_elasticity
cap gen rent_old = s18lognoi_adj
xtile gkbin=gk_elasticity, n(10)
replace gk_elasticity = 0 if gk_elasticity<0
cap program drop myreg
program def myreg, eclass
	args name
	reghdfe `name' incomechange gk_elasticity incomechange_gkelasticity,  absorb(gkbin)
	local ratio = -_b[c.incomechange]/_b[incomechange_gkelasticity]
	local ratio = 100000*(`ratio'<=0) + `ratio'*(`ratio'>0)
	ereturn scalar ratio=`ratio'
end

foreach name in rent_new rent_old {

	tempfile bootdat
	bootstrap ratio=e(ratio), reps(`mynumreps') seed(10) saving(`bootdat'): myreg `name'
	local `name'_gkmean=_b[ratio]-(`meanelasticity'+.66667)

	preserve
	use `bootdat', clear
	sum ratio, det
	local `name'_gkp5=r(p5)-(`meanelasticity'+.66667)
	local `name'_gkp10=r(p10)-(`meanelasticity'+.66667)
	restore
}


disp "morecontrols unadjusted wageshock mean: `mu1' p5: `mu1_p5' p10: `mu1_p10'"
disp "morecontrols unadjusted manufacturing mean: `mu2' p5: `mu2_p5' p10: `mu2_p10'"

disp "morecontrols newrent wageshock mean: `mu3' p5: `mu3_p5' p10: `mu3_p10'"
di "morecontrols newrent manufacturing mean: `mu4' p5: `mu4_p5' p10: `mu4_p10'"

// GK elasticity
disp "gk newrent: `rent_old_gkmean' p5: `rent_old_gkp5' p10: `rent_old_gkp10'"
di "gk oldrent: `rent_new_gkmean' p5: `rent_new_gkp5' p10: `rent_new_gkp10'"
