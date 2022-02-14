//use "data\rent_index_msa00.dta" , clear
use "../data/rent_index_msa00_2001.dta" , clear
//drop if freq==0

//replace stderr=10 if stderr<.0001


rename city msa

merge 1:1 msa year using "../data/combineddata"

xtset msa year
gen rent=fs18.lognoi
gen hp=s17.loghpi


replace stderr=f.stderr

replace rent=. if stderr<.00001


keep if year==2017
keep msa rent hp stderr freq

reg rent hp
predict rhat
predict resid, r
summ resid, detail

local var_resid=r(sd)^2
disp `var_resid'

gen var_rent=stderr^2

summ var_rent
local var_rent=r(mean)

local var_rhat=`var_resid'-`var_rent'


if `var_rhat'<0{
	disp "Problem: Variance of rhat is less than zero!"
	stop
}

gen rent_new=(rent/var_rent+rhat/`var_rhat')/(1/var_rent+1/`var_rhat')

gen weight=1/var_rent/(1/var_rent+1/`var_rhat')

gen rent_change=rent_new-rent
disp `var_rhat'
summ var_rent



gen scatter_weight=1/var_rent
replace scatter_weight=. if rent_new==.

//graph rename histogram, replace
twoway rspike rent_new rent hp , lcolor(dkgreen)  ||  scatter rent rent_new hp, msym(square) ///
	mcolor(dkgreen orange_red) ytitle("Rent Change 2000-2018") xtitle("House Price Change 2000-2017") ///
	legend(label(2 "Rent index based on Trepp data alone") label(3 "Post-empirical-Bayes rent index") col(1) order(2 3))
graph export "../exhibits/empirical_bayes_shrinkage.pdf", as(pdf) replace

hist weight, start(0) width(.05) xtitle("Weight on Trepp Rent Index") frac ytitle("Share in Bin (width=.05)")
graph export "../exhibits/empirical_bayes_histogram.pdf", as(pdf) replace


replace rent_new=rhat if rent==.
summ weight, detail

keep rent_new msa
//save "../data\rent_empirical_bayes.dta", replace


