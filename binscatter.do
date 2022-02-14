

set scheme s1color
clear all
use "../data/combineddata", clear
replace msa=9999 if msa==.
gen elasticity2=elasticity
replace elasticity2=5.35 if msa==9999
keep if elasticity2!=.



xtset msa year

gen s17loghpi = s17.loghpi-.3532 if year==2017

gen s18logpop = fs18.logpop if year==2017
gen s18lognoi_adj=fs18.lognoi_adj if year==2017
gen l18pop=l17.pop if year==2017

gen elasticity3=-elasticity2
xtile elasticitybin= elasticity3 [w=l18pop] , n(6) // if s18lognoi_adj!=., n(6)



preserve

collapse (mean) rent_new s17loghpi s18lognoi_adj s18logpop   elasticity2  [w=l18pop], by(elasticitybin)
pause
rename s18lognoi_adj s18lognoi_adj_mean
rename rent_new rent_new_mean
//rename epop_change epop_change_mean
rename s17loghpi s17loghpi_mean
// rename wageshock wageshock_mean
// rename collegeshock collegeshock_mean
rename elasticity2 elasticity_mean
rename s18logpop s18logpop_mean
//rename amen_index amen_mean
tempfile bins
save `bins'
restore
merge m:1 elasticitybin using `bins'

gsort elasticity
drop if elasticitybin==. 

//cap graph drop rents
scatter s18lognoi_adj elasticity2 [w=l18pop] if  elasticity2<10, msym(Oh) || ///
	scatter s18lognoi_adj_mean elasticity_mean, ///
	msize(2) c(l) yline(0, lcolor(gs8)) yscale(range(-.5 1)) ylabel(-.5(.5)1) ///
	ytitle("Log Rent Change (unadjusted)" "2000-2018") legend(off) name(rents_unadjusted, replace)

scatter rent_new elasticity2 [w=l18pop] if  elasticity2<10, msym(Oh) || ///
	scatter rent_new_mean elasticity_mean, ///
	msize(2) c(l) yline(0, lcolor(gs8)) yscale(range(-.5 1)) ylabel(-.5(.5)1) ///
	ytitle("Log Rent Change, 2000-2018") legend(off) name(rents, replace)
	
qui sum s17loghpi, det


local hpimean = r(mean)
qui sum elasticity, det
local elastmean = r(mean)


scatter s18logpop elasticity2 [w=l18pop]if  elasticity2<10, msym(Oh) ///
	|| scatter s18logpop_mean elasticity_mean, ///
	msize(2) c(l) yline(0, lcolor(gs8))  ///
	ytitle("Log Population Change, 2000-2018") legend(off) name(pop, replace) 


graph combine rents rents_unadjusted pop
graph export "../exhibits/binscatter_rent_pop.pdf", as(pdf) replace
