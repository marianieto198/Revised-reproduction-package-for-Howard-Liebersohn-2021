/*
Author(s): Greg Howard & Jack Liebersohn
Date:2021

*/

//Se establece fondo blanco para las salidas, sin embargo de este dofile en específico no salen gráficas

set scheme s1color

//Cálculo geochannel
//Notar que se inicia con el año 2000. Las variables que se mantienen son logaritmo de la población, 
//logaritmo de la renta, población, elasticidad, año y una variable dummy que toma el valor de 1 si en esa
//ciudad se mide el CPI. De lo contrario toma el valor de 3.

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
		local denom=r(mean) //denominador= promedio de la renta

		local geochannel=(`covL'-`covR')/`denom' //geochannel es la diferencia entre la covarianza de población menos la covarianza de renta, sobre el promedio de la renta 
		
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

//AD - No se encuentran errores en el script, sin embargo, se copian los resultados aquí mismo por si eventualmente se presentan problemas en la salida de la tabla debido a falta de información original.

// Resultados
/*mu: 0.34 lambda: 1.00 geochannel: 0.01 geochannel_CPI: 0.01 pctavg: 0.08 pctcpi: 0.09
mu: 1.07 lambda: 1.00 geochannel: 0.01 geochannel_CPI: 0.03 pctavg: 0.17 pctcpi: 0.23
mu: 1.31 lambda: 1.00 geochannel: 0.02 geochannel_CPI: 0.04 pctavg: 0.20 pctcpi: 0.26
mu: 2.50 lambda: 1.00 geochannel: 0.02 geochannel_CPI: 0.05 pctavg: 0.28 pctcpi: 0.38
mu: 5.10 lambda: 1.00 geochannel: 0.03 geochannel_CPI: 0.07 pctavg: 0.36 pctcpi: 0.50
mu: inf lambda: 1.00 geochannel: 0.04 geochannel_CPI: 0.11 pctavg: 0.53 pctcpi: 0.74
mu: inf lambda: 0.67 geochannel: 0.05 geochannel_CPI: 0.11 pctavg: 0.58 pctcpi: 0.77
mu: inf lambda: 0.50 geochannel: 0.05 geochannel_CPI: 0.11 pctavg: 0.61 pctcpi: 0.79
mu: inf lambda: 0.00 geochannel: 0.06 geochannel_CPI: 0.12 pctavg: 0.73 pctcpi: 0.85
*/
