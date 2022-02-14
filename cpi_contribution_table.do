set scheme s1color

cap program drop calculate_geo_channel
program def calculate_geo_channel, rclass
	args mu lambda

	preserve
	qui {
	clear
	use "../data/combineddata", clear
	//merge m:1 msa using "../data/cpi_rent/used_in_cpi", gen(hasCPI)
	xtset msa year
	gen dlogL= f18s18.logpop if year==2000
	*gen dlogR= f18s18.lognoi if year==2000
	gen dlogR= rent_new if year==2000
	keep dlogL dlogR pop elasticity year hasCPI
	keep if year==2000

	// do it once for all values, then only for the regions wtih CPI
	summ dlogR [w=pop] if elasticity!=. & hasCPI==3
	local dlogRmean_CPI=r(mean)

	summ dlogL [w=pop]
	local dlogLbar=r(mean)

	summ dlogR [w=pop] if elasticity!=.
	local dlogRmean=r(mean)
	
	replace dlogR=0 if elasticity==.
	replace elasticity=5.35 if elasticity==. // this is the 99th percentile, by population 2000

	summ dlogR [w=pop] if elasticity!=.
	local dlogRmean=r(mean)

	corr dlogR elasticity [w=pop], cov
	local covR=r(cov_12)
	summ elasticity [w=pop]
	local elasticity_mean=r(mean)

	if "`mu'"=="inf" {
		local geochannel =-`covR'/(`elasticity_mean'+`lambda')
		local geochannel_CPI=-`covR'/(`elasticity_mean'+`lambda') +`dlogRmean_CPI'-`dlogRmean'          
	}
	else {
		gen oneoverSML=1/(elasticity+`lambda'+`mu')
		gen SLoverSML=(elasticity+`lambda')/(elasticity+`lambda'+`mu')
		corr oneoverSML dlogL [w=pop], cov
		local covL=r(cov_12) 
		corr SLoverSML dlogR [w=pop], cov
		local covR=r(cov_12)
		summ SLoverSML [w=pop]
		local denom=r(mean)

		local geochannel=(`covL'-`covR')/`denom'
		
		local dustar=-(`covL'+`mu'*`covR')/`denom'-`dlogLbar'-`mu'*`dlogRmean'
		gen rdiff=(dlogL+`mu'*dlogR+`dustar')/(elasticity+`mu'+`lambda')
		
		summ rdiff [w=pop] if hasCPI==3
		local geochannel_CPI=r(mean)
		summ rdiff [w=pop] 
		local geochannel2=r(mean)		
		}
	}
	restore
	
	local pct_avg = `geochannel'/`dlogRmean'
	local pct_cpi = `geochannel_CPI'/`dlogRmean_CPI'
*	di `dlogRmean_CPI'

	if "`mu'"=="inf" {
		di "mu: `mu' lambda: " %4.2f `lambda' " geochannel: "  %4.2f `geochannel' " geochannel_CPI: "  %4.2f `geochannel_CPI' " pctavg: "  %4.2f `pct_avg'  " pctcpi: "  %4.2f `pct_cpi'
	}
	else {
		di "mu: " %4.2f `mu' " lambda: " %4.2f `lambda' " geochannel: "  %4.2f `geochannel' " geochannel_CPI: "  %4.2f `geochannel_CPI' " pctavg: "  %4.2f `pct_avg'  " pctcpi: "  %4.2f `pct_cpi'
	}
	foreach name in geochannel pct_avg pct_cpi geochannel_CPI {
		return local `name'=``name''
	}
	
end

foreach set in ".34 1" "1.07 1" "1.31 1" "2.5 1" "5.1 1" "inf 1" "inf `=2/3'" "inf .5" "inf 0" {
	calculate_geo_channel `set'
}
