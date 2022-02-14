set scheme s1color

set seed 21
local maxmu=10

use "../data/combineddata", clear
//merge m:1 msa using "../data/cpi_rent/used_in_cpi", gen(hasCPI)
drop if year==1998

xtset msa year
gen dlogL= f18s18.logpop if year==2000
*gen dlogR= f18s18.lognoi if year==2000
gen dlogR= rent_new if year==2000
keep dlogL dlogR pop elasticity year hasCPI
keep if year==2000

replace dlogR=0 if elasticity==.
replace elasticity=5.35 if elasticity==. // this is the 99th percentile, by population 2000

tempfile thingtouse
save `thingtouse'


summ dlogR [w=pop] if elasticity!=. & hasCPI==3
local dlogRmean_CPI=r(mean)

summ dlogR [w=pop] if elasticity!=.
local dlogRmean=r(mean)


corr dlogR elasticity [w=pop], cov
local covR=r(cov_12)
summ elasticity [w=pop]
local elasticity_mean=r(mean)

local muinftylambda0=-`covR'/`elasticity_mean'               +`dlogRmean_CPI'-`dlogRmean'          
local muinftylambda23=-`covR'/(`elasticity_mean'+2/3)        +`dlogRmean_CPI'-`dlogRmean'         
local muinftylambda12=-`covR'/(`elasticity_mean'+1/2)        +`dlogRmean_CPI'-`dlogRmean'         
local muinftylambda1=-`covR'/(`elasticity_mean'+1)           +`dlogRmean_CPI'-`dlogRmean'          

disp `muinftylambda0'
disp `muinftylambda13'
disp `muinftylambda1'

clear all
tempfile lambdamu
gen lambda=.
gen mu=.
gen geochannel=.
save `lambdamu'
foreach lambda in 0  .6666666 1{
	forvalues mu= 0(.2)`maxmu'{
		use `thingtouse'
		
		
		gen oneoverSML=1/(elasticity+`lambda'+`mu')
		gen SLoverSML=(elasticity+`lambda')/(elasticity+`lambda'+`mu')
		corr SLoverSML dlogL [w=pop], cov
		local covL=r(cov_12) 
		corr SLoverSML dlogR [w=pop], cov
		local covR=r(cov_12)
		summ SLoverSML [w=pop]
		local denom=r(mean)
		summ dlogL [w=pop]
		local dlogLbar=r(mean)
		summ dlogR [w=pop]
		local dlogrbar=r(mean)
		
		
		local dustar=-(`covL'+`mu'*`covR')/`denom'-`dlogLbar'-`mu'*`dlogrbar'
		
		gen rdiff=(dlogL+`mu'*dlogR+`dustar')/(elasticity+`mu'+`lambda')
		
		summ rdiff [w=pop] if hasCPI==3
		local geochannel_CPI=r(mean)
		summ rdiff [w=pop] 
		local geochannel=r(mean)
		
		clear all
		set obs 1
		gen lambda=`lambda'
		gen mu = `mu'
		gen geochannel=`geochannel' 
		gen geochannel_CPI=`geochannel_CPI'
		append using `lambdamu'
		save `lambdamu', replace
	}
}


local obs1=_N+1
set obs `obs1'

gen dlogRmean_CPI=`dlogRmean_CPI'
replace mu=11 if mu==.
gsort mu

local maxmuplusone=`maxmu'+1
local maxmuplushalf=`maxmu'+.5


local dlogRmean_CPI12=`dlogRmean_CPI'/2
local dlogRmean_CPI14=`dlogRmean_CPI'/4
local dlogRmean_CPI34=`dlogRmean_CPI'/4*3


line geochannel_CPI mu if lambda==0, lpattern(shortdash) || line geochannel_CPI mu if abs(lambda-.666666)<.01 || line geochannel_CPI mu if lambda==1, lpattern(dash) ///
	|| scatteri `muinftylambda0' `maxmuplusone', color(forest_green) || scatteri `muinftylambda23' `maxmuplusone', color(orange) || scatteri `muinftylambda1' `maxmuplusone', color(navy) ///
	|| line dlogRmean_CPI mu, yaxis(2) lcolor(maroon) lpattern(dot) ytitle("Contribution of Migration Demand") xtitle("{&mu}") ///
	legend(order(1 2 3 7) label(1 "{&lambda}=0") label(2 "{&lambda}=2/3") label(3 "{&lambda}=1") label(7 "Total Rent Increase")) ///
	yscale(range(-.02 .2)) ylabel(#4) yline(0, lcolor(gs10)) ///
	xline(`maxmuplushalf', lcolor(gs10) lpattern(dot)) xlabel( 0 "0" 5 "5" 10 "10" 11 "{&infinity}") ///
	yscale(range(-.02 .2) axis(2)) ylabel(0 "0" `dlogRmean_CPI14' "25" `dlogRmean_CPI12' "50" `dlogRmean_CPI34' "75" `dlogRmean_CPI' "100", axis(2)) ytitle("Percent of Rent Increase", axis(2))

	
graph export "../exhibits/contribution_cpi.pdf", as(pdf) replace

disp `dlogRmean_CPI' 
disp `muinftylambda0' `=`muinftylambda0'/`dlogRmean_CPI''
disp `muinftylambda12' `=`muinftylambda12'/`dlogRmean_CPI''
disp `muinftylambda23' `=`muinftylambda23'/`dlogRmean_CPI''
disp `muinftylambda1' `=`muinftylambda1'/`dlogRmean_CPI''
