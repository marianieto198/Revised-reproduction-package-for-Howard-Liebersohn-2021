//
//
// Wage replication
//
//

preserve
use "..\data\qcew\2000_msa_industry_shares", clear
keep if industry_code=="31-33" | industry_code=="1023"
keep industryshare msa industry_code
replace industry_code = "finance" if industry_code=="1023"
replace industry_code ="manufshare" if industry_code == "31-33"
reshape wide industryshare, i(msa) j(industry_code) string
rename industryshare* *
tempfile manuf
save `manuf'
restore



set scheme s1color
clear all
use "../data/combineddata"
keep if elasticity!=.




local mynumreps 1000

gen s18lognoi_adj=s18.lognoi_adj if year==2018

collapse (max) s18lognoi_adj rent_new (first) bartik* wageshock elasticity unaval WRLURI, by(msa)

summ elasticity if rent_new !=.
local meanelasticity=r(mean)

merge 1:1 msa using `manuf', nogen


label var s18lognoi_adj "Rent (raw)"
label var rent_new "Rent"

reg s18lognoi_adj c.wageshock#c.elasticity wageshock, r
reg rent_new c.wageshock#c.elasticity wageshock, r


cap program drop myreg
program def myreg, eclass
	qui reg s18lognoi_adj c.wageshock#c.elasticity wageshock, r
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


cap program drop myreg
program def myreg, eclass
	qui reg rent_new c.wageshock#c.elasticity wageshock, r
	local ratio = -_b[c.wageshock]/_b[c.wageshock#c.elasticity]
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

//
//
// Manufacturing Share
//
//

reg s18lognoi_adj c.manufshare#c.elasticity manufshare, r
reg rent_new c.manufshare#c.elasticity manufshare, r

cap program drop myreg
program def myreg, eclass
	qui reg s18lognoi_adj c.manufshare#c.elasticity manufshare, r
	local ratio = -_b[c.manufshare]/_b[c.manufshare#c.elasticity]
	local ratio = 100000*(`ratio'<=0) + `ratio'*(`ratio'>0)
	ereturn scalar ratio=`ratio'
end

tempfile bootdat
bootstrap ratio=e(ratio), reps(`mynumreps') seed(10) saving(`bootdat'): myreg
local mu5=_b[ratio]-(`meanelasticity'+.66667)

preserve
use `bootdat', clear
sum ratio, det
local mu5_p10=r(p10)-(`meanelasticity'+.66667)
local mu5_p5=r(p5)-(`meanelasticity'+.66667)
restore


cap program drop myreg
program def myreg, eclass
	qui reg rent_new c.manufshare#c.elasticity manufshare, r
	local ratio = -_b[c.manufshare]/_b[c.manufshare#c.elasticity]
	local ratio = 100000*(`ratio'<=0) + `ratio'*(`ratio'>0)
	ereturn scalar ratio=`ratio'
end

tempfile bootdat
bootstrap ratio=e(ratio), reps(`mynumreps') seed(10) saving(`bootdat'): myreg
local mu6=_b[ratio]-(`meanelasticity'+.66667)

preserve
use `bootdat', clear
sum ratio, det
local mu6_p5=r(p5)-(`meanelasticity'+.66667)
local mu6_p10=r(p10)-(`meanelasticity'+.66667)
restore

//
//
// Bartik replication
//
//

/*
use "..\data\qcew\2000_msa_industry_shares", clear
keep if agglvl_code==73
gen bartik_wage = (national_emp2018/national_emp2000)*industryshare
gcollapse (sum) bartik industryshare, by(msa)
replace bartik_wage = log(bartik + 1-industryshare) // "missing" industry isnt growing
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



set scheme s1color
clear all
use "../data/combineddata"
keep if elasticity!=.

*replace elasticity = -unaval


* optionally noise up the estimates
*replace elasticity = elasticity+rnormal()

gen s18lognoi_adj=s18.lognoi_adj if year==2018
*gen s17loghpi = s17.loghpi if year==2017

collapse (max) s18lognoi_adj rent_new (first) bartik* elasticity unaval WRLURI, by(msa)

summ elasticity if s18lognoi_adj !=.
local meanelasticity=r(mean)
replace elasticity=elasticity-`meanelasticity'

merge 1:1 msa using `manuf', nogen

xtile elasticitybin=elasticity, n(10)

reg s18lognoi_adj c.bartik_wage c.bartik_wage#c.elasticity, r
reg rent_new c.bartik_wage c.bartik_wage#c.elasticity, r


* unlike in the other estimates, here it is necessary to adjust for inflation and measure it in growth rates
* elsewhere this wont make a difference...
//replace bartik_inc = bartik_inc/1.44 - 1
replace bartik_wage = bartik_wage/1.44 - 1

*replace bartik_inc = log(bartik_inc)
*replace bartik_wage = log(bartik_wage)


// Bootstrap Bartik
cap program drop myreg
program def myreg, eclass
	qui reg s18lognoi_adj c.bartik_wage c.bartik_wage#c.elasticity, r
	local ratio = -_b[c.bartik_wage]/_b[c.bartik_wage#c.elasticity]
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
	qui reg rent_new c.bartik_wage c.bartik_wage#c.elasticity, r
	local ratio = -_b[c.bartik_wage]/_b[c.bartik_wage#c.elasticity]
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


//
//
// Results
//
//


di "diamond oldrent wageshock mean: `mu1' p5: `mu1_p5' p10: `mu1_p10'"
di "diamond oldrent manufshare mean: `mu5' p5: `mu5_p5' p10: `mu5_p10'"
di "diamond oldrent bartik mean: `mu2' p5: `mu2_p5' p10: `mu2_p10'"

di "diamond newrent wageshock mean: `mu3' p5: `mu3_p5' p10: `mu3_p10'"
di "diamond newrent manufshare mean: `mu6' p5: `mu6_p5' p10: `mu6_p10'"
di "diamond newrent bartik mean: `mu4' p5: `mu4_p5' p10: `mu4_p10'"
