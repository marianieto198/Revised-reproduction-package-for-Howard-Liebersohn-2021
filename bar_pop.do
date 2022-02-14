clear all
set scheme s1color
use "../data/combineddata"
xtset msa year



gen invelasticity=1/elasticity
replace invelasticity=0 if invelasticity==9999
gen s18logpop=s18.logpop if year==2018
gen s18lognoi=s18.lognoi if year==2018

replace s18lognoi=. if msa==9999

label define abovemedian 1 "Above Median" 0 "Below Median"

gen wrluri_fake=WRLURI
replace wrluri_fake=-10 if WRLURI==.
summ wrluri_fake [w=pop] if year==2000, detail
local wrluri_median=r(p50)
gen abovemedianWRLURI=wrluri_fake>`wrluri_median'
label values abovemedianWRLURI abovemedian
drop wrluri_fake

gen gk_fake=gk_elasticity
replace gk_elasticity = .46 if missing(gk_elasticity) & !missing(elasticity)
replace gk_fake=-10 if gk_elasticity==.
summ gk_fake [w=pop] if year==2000, detail
local gk_median=r(p50)
gen abovemediangk=gk_fake>`gk_median'
label values abovemediangk abovemedian
drop gk_fake


gen unaval_fake=unaval
replace unaval_fake=-10 if unaval==.
summ unaval_fake [w=pop] if year==2000, detail
local unaval_median=r(p50)
gen abovemedianunaval=unaval_fake>`unaval_median'
label values abovemedianunaval abovemedian
drop unaval_fake

gen elasticity_fake=elasticity
replace elasticity_fake=100 if elasticity==.
summ elasticity_fake [w=pop] if year==2000, detail
local elasticity_median=r(p50)
gen abovemedianelasticity=elasticity_fake>`elasticity_median'
label values abovemedianelasticity abovemedian
drop elasticity_fake

label var s18lognoi "Log Rent Change (unadjusted), 2000-2018"
label var rent_new "Log Rent Change, 2000-2018"

foreach var of varlist rent_new s18lognoi {

	local mylabel : var label `var'

	preserve
	collapse (mean) `var'  [w=l18.pop], by(abovemedianWRLU)
	graph bar `var', over(abovemedianWRLURI)  ylabel(-.05(.05).2) ytitle("`mylabel'")  blabel(bar, format(%10.3f)) name(Regulation_`var', replace) nodraw title("Land-Use Regulation")
	restore

	preserve
	collapse (mean) `var'  [w=l18.pop], by(abovemedianunaval)
	graph bar `var', over(abovemedianunaval)  ylabel(-.05(.05).2) ytitle("")  blabel(bar, format(%10.3f)) name(UnavailableLand_`var', replace) nodraw title("Unavailable Land")
	restore

	preserve
	collapse (mean) `var'  [w=l18.pop], by(abovemedianelasticity)
	graph bar `var', over(abovemedianelasticity)  ylabel(-.05(.05).2) ytitle("`mylabel'")  blabel(bar, format(%10.3f)) name(Elasticity_`var', replace) nodraw yscale(range(-.021 .2)) // title("Housing Supply Elasticity")
	restore

	preserve
	collapse (mean) `var'  [w=l18.pop], by(abovemediangk)
	graph bar `var', over(abovemediangk)  ylabel(-.05(.05).2) ytitle("`mylabel'")  blabel(bar, format(%10.3f)) name(GKElasticity_`var', replace) nodraw yscale(range(-.021 .2))  title("Gorback-Keys Elasticity")
	graph bar `var', over(abovemediangk)  ylabel(-.05(.05).2) ytitle("`mylabel'")  blabel(bar, format(%10.3f)) name(GKElasticity_`var', replace) nodraw yscale(range(-.021 .2))  title("Gorback-Keys Elasticity")
	restore

}

preserve
collapse (mean) s18logpop  [w=l18.pop], by(abovemedianWRLU)
graph bar s18logpop, over(abovemedianWRLURI)  ylabel(-.05(.05).2) ytitle("Log Population Change, 2000-2018")  blabel(bar, format(%10.3f)) name(Regulation_s18logpop, replace) nodraw
restore

preserve
collapse (mean) s18logpop  [w=l18.pop], by(abovemedianunaval)
graph bar s18logpop, over(abovemedianunaval)  ylabel(-.05(.05).2) ytitle("")  blabel(bar, format(%10.3f)) name(UnavailableLand_s18logpop, replace) nodraw
restore

preserve
collapse (mean) s18logpop  [w=l18.pop], by(abovemedianelasticity)
graph bar s18logpop, over(abovemedianelasticity)  ylabel(-.05(.05).2) ytitle("Log Population Change, 2000-2018")  blabel(bar, format(%10.3f)) name(Elasticity_s18logpop, replace) nodraw
restore


preserve
collapse (mean) s18logpop  [w=l18.pop], by(abovemediangk)
graph bar s18logpop, over(abovemediangk)  ylabel(-.05(.05).2) ytitle("Log Population Change, 2000-2018")  blabel(bar, format(%10.3f)) name(GKElasticity_s18logpop, replace) nodraw
restore

//graph combine  Regulation_s18lognoi UnavailableLand_s18lognoi Elasticity_s18lognoi Regulation_s18logpop UnavailableLand_s18logpop Elasticity_s18logpop, row(2) ycommon
// graph combine  Elasticity_rent_new Elasticity_s18logpop, row(1) ycommon
// graph export "../exhibits/bargraph.pdf", as(pdf) replace
//
// graph combine  Elasticity_s18lognoi, row(1) ycommon
// graph export "../exhibits/bargraph_robust.pdf", as(pdf) replace
//
// graph combine  GKElasticity_rent_new GKElasticity_s18logpop, row(1) ycommon
// graph export "../exhibits/bargraph_gk.pdf", as(pdf) replace


graph display Elasticity_rent_new
graph export "../exhibits/bargraph_rent.pdf", as(pdf) replace
graph display Elasticity_s18logpop
graph export "../exhibits/bargraph_pop.pdf", as(pdf) replace
