

set scheme s1color
clear all
use "../data/combineddata", clear
replace msa=9999 if msa==.
//merge m:1 msa using "../data/acs_wages/processed_data2", nogen
//gen collegeshock=wage_college_resid2010-wage_college_resid2000
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

collapse (mean) rent_new s18loghomeowner s18logcollege s18lognoncollege s18logusborn s18lognoncitizen s18logforeignborn s18logrenter s17loghpi s18lognoi_adj s18logpop  elasticity2  [w=l18pop], by(elasticitybin)

rename s18lognoi_adj s18lognoi_adj_mean
rename rent_new rent_new_mean
rename s17loghpi s17loghpi_mean
//rename wageshock wageshock_mean
//rename collegeshock collegeshock_mean
rename elasticity2 elasticity_mean
rename s18logcollege s18logcollege_mean
rename s18lognoncollege s18lognoncollege_mean
rename s18lognoncitizen s18lognoncitizen_mean
rename s18logforeignborn s18logforeignborn_mean
rename s18logrenter s18logrenter_mean
rename s18logpop s18logpop_mean
rename s18loghomeowner s18loghomeowner_mean
rename s18logusborn s18logusborn_mean
tempfile bins
save `bins'
restore
merge m:1 elasticitybin using `bins'

gsort elasticity
drop if elasticitybin==. 

*s18logrenter s18lognoncitizen s18logforeignborn

//cap graph drop rents
scatter s18lognoncollege elasticity2 [w=l18pop]if  elasticity2<10, msym(Oh) ///
	|| scatter s18lognoncollege_mean elasticity_mean, ///
	msize(2) c(l) yline(0, lcolor(gs8))  ///
	ytitle("Log Non-College Change") title("Non-College") legend(off) name(noncollege, replace)  nodraw

scatter s18logcollege elasticity2 [w=l18pop]if  elasticity2<10, msym(Oh) ///
	|| scatter s18logcollege_mean elasticity_mean, ///
	msize(2) c(l) yline(0, lcolor(gs8))  yscale(range(0)) ylabel(#5) ///
	ytitle("Log College Change") title("College") legend(off) name(college, replace)   nodraw

// scatter s18lognoncitizen elasticity2 [w=l18pop]if  elasticity2<10, msym(Oh) ///
// 	|| scatter s18lognoncitizen_mean elasticity_mean, ///
// 	msize(2) c(l) yline(0, lcolor(gs8))  ///
// 	ytitle("Log Non-Citizen Change") title("Non-Citizen") legend(off) name(noncitizen, replace)   nodraw

scatter s18logforeignborn elasticity2 [w=l18pop]if  elasticity2<10 & s18logforeignborn<1, msym(Oh) ///
	|| scatter s18logforeignborn_mean elasticity_mean, ///
	msize(2) c(l) yline(0, lcolor(gs8))  ///
	ytitle("Log Foreign-Born Change") title("Foreign-Born") legend(off) name(foreignborn, replace)   nodraw


scatter s18logrenter elasticity2 [w=l18pop]if  elasticity2<10, msym(Oh) ///
	|| scatter s18logrenter_mean elasticity_mean, ///
	msize(2) c(l) yline(0, lcolor(gs8))  ///
	ytitle("Log Renter Change") title("Renters") legend(off) name(renter, replace)   nodraw


scatter s18loghomeowner elasticity2 [w=l18pop]if  elasticity2<10, msym(Oh) ///
	|| scatter s18loghomeowner_mean elasticity_mean, ///
	msize(2) c(l) yline(0, lcolor(gs8)) ///
	ytitle("Log Home-Owners Change") title("Home-Owners") legend(off) name(owner, replace)   nodraw
scatter s18logusborn elasticity2 [w=l18pop]if  elasticity2<10, msym(Oh) ///
	|| scatter s18logusborn_mean elasticity_mean, ///
	msize(2) c(l) yline(0, lcolor(gs8))  ///
	ytitle("Log Native-Born Change") title("Native Born") legend(off) name(usborn, replace)   nodraw
	
//cap graph drop housing

// scatter s18logpop elasticity2 [w=l18pop]if  elasticity2<10, msym(Oh) ///
// 	|| scatter s18logpop_mean elasticity_mean, ///
// 	msize(2) c(l) yline(0, lcolor(gs8))  ///
// 	ytitle("Log Population Change") title("Total Population") legend(off) name(pop, replace)   nodraw
//
// graph combine pop noncitizen foreignborn usborn owner  renter college noncollege , row(4) col(2) xsize(7) ysize(12)
// graph export "../exhibits/binscatter_immigrants_renters_extended.pdf", as(pdf) replace

graph combine foreignborn usborn owner  renter college noncollege , ycommon row(3) col(2) xsize(7) ysize(12)
graph export "../exhibits/binscatter_immigrants_renters.pdf", as(pdf) replace
