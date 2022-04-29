/*
Author(s): Greg Howard & Jack Liebersohn
Date:2021

Description: Script para realizar la figura 4
*/
//Los autores utilizan combineddata tanto en este dofile como en varios otros,
//debido a que no proporcionan los datos usados de forma aislada sino que se suministra la base combinada.
use "../data/combineddata", clear


//Notar que si bien los autores nos proporcionan el script original, no se corren estas líneas porque la dta ya viene combinada 
//merge m:1 msa using  "../data\property_characteristics\sizegrowth_ahs"
//Además, notar que usan el año 2017 porque se analizan datos del 2000 al 2017 únicamente 
gen dlogh = dsize_per_ahs if year==2017
* replace dlogh =0 

//Panel de datos
xtset msa year

//Se generan las variables ya trabajadas en figuras anteriores, pero ahora para el año 2017 y solo se mantienen los datos de este año
gen dlogR=rent_new if year==2017
replace dlogR=0 if elasticity==.

gen dlogL = s17.logpop if year==2017

replace elasticity=5.35 if elasticity==. 

by msa : egen pop2000=total(pop*(year==2000))
keep if year==2017

* original supply shock
//Notar que como aquí se está multiplicando por elasticidad, ya se han reemplazado todos los missing values de esta variable por el valor del percentil 99
gen supplyshock= dlogL+dlogh-dlogR*elasticity if year==2017

//Siendo L=población; h=housing demand; R=rent 

//Oferta - cálculo 
cap program drop calc_supply
program def calc_supply, rclass
	args lambda mu
	
	quietly {
	preserve
	
	gen lambda = `lambda'
	gen mu = `mu'
	
	gen inv_slmu = 1/(lambda+mu+elasticity)
	gen s_slmu = elasticity/(elasticity+lambda+mu)

	
	foreach name in inv_slmu dlogL dlogh {
		qui sum `name' [w=pop2000]
		local mean_`name' = r(mean)
	}
	// this is taken by comparing the long-difference AHS in 1999 and 2017
	local mean_dlogh = log(700)-log(720) // change from 720 to 700 in published tables
	// https://www.census.gov/programs-surveys/ahs/data/interactive/ahstablecreator.html?s_areas=00000&s_year=2017&s_tablename=TABLE2&s_bygroup1=1&s_bygroup2=1&s_filtergroup1=1&s_filtergroup2=1
	// https://www.census.gov/content/dam/Census/programs-surveys/ahs/data/2001/h150-01.pdf


	* term 1 //Desarrollo de Proposición 13 - Housing supply channel - Correlación positiva con la elasticidad
	gen term1 = `mean_inv_slmu' * (`mean_dlogL' + `mean_dlogh')

	* term2 
	corr inv_slmu dlogL [w=pop2000], cov
	gen term2 = r(cov_12)

	* term3
	corr inv_slmu dlogh [w=pop2000], cov
	gen term3 = r(cov_12)

	* term4
	sum s_slmu [w=pop2000]
	local mean_s_slmu = r(mean)
	sum dlogR [w=pop2000]
	local mean_dlogr = r(mean)
	gen term4 = `mean_s_slmu'*`mean_dlogr'

	* term5
	corr s_slmu dlogR [w=pop2000], cov
	gen term5 = r(cov_12)

	keep supplyshock elasticity pop2000 msa dlogR dlogh dlogL lambda mu term*

	gen denom=(elasticity+lambda)/(lambda+mu+elasticity)
	qui sum denom [w=pop2000]
	local mean_denom = r(mean)
	
	gen numerator = -supplyshock/(elasticity+lambda+mu)
	sum numerator [w=pop2000]
	local supplycontribution_old = `=r(mean)'/`mean_denom'
	return local supplycontribution_old = `supplycontribution_old'
	
	return local numerator_old =r(mean)

	gen numerator2 = -(term1 + term2 + term3 - term4 - term5)
	sum numerator2 [w=pop2000]
	local supplycontribution_new =  `=r(mean)'/`mean_denom'
	return local supplycontribution_new = `supplycontribution_new'
	
	restore
	}
end
	
//Habiendo calculado housing supply contribution, a continuación= notar que si bien mu tiende a infinito, nuevamente en esta gráfica se representará hasta 10 (9.9)
cap postclose paramvalues
tempfile paramvalues
postfile paramvalues lambda mu supplycontribution_old supplycontribution_new using `paramvalues'
forv i=1/102 {
	local mu=`i'/10-.1
	if `mu' > 10 {
		local mu=1000000000
	}
	foreach lambda in 0 `=2/3' 1 {
		calc_supply `lambda' `mu'
	post paramvalues (`lambda') (`mu') (`=r(supplycontribution_old)') (`=r(supplycontribution_new)')
	}
}
postclose paramvalues
use `paramvalues', clear

//Missing value para todo mu mayor a 10, que es el límite establecido para esta salida. Posteriormente, estos missing values se reemplazan por maxmuplusone

replace mu=. if mu>10
gen mu2=11 if mu==.

//Generar variable local de promedio de logaritmo de renta
local dlogRmean = 6.2

//Se procede a preparar la salida de la gráfica. 
line supplycontribution_new mu if lambda==0 ,lpattern(shortdash) || line supplycontribution_new mu if abs(lambda-2/3)<.01 || ///
	line supplycontribution_new mu if lambda==1 , lpattern(dash)  || scatter supplycontribution_new mu2 if lambda==1, color(navy) || ///
	scatter supplycontribution_new mu2 if lambda==0, color(forest_green)  || scatter supplycontribution_new mu2 if abs(lambda-2/3)<.01, color(dkorange) ///
	, ytitle("Contribution of Housing Supply") xtitle("{&mu}") legend(order(1 2 3) label(1 "{&lambda}=0") label(2 "{&lambda}=2/3") label(3 "{&lambda}=1")) ///
	yscale(range(0 .1)) ylabel(#4) yline(0, lcolor(gs10)) yline(`dlogRmean', lcolor(maroon) lpattern(dash)) xline(10.5, lcolor(gs10) lpattern(dot))   xlabel( 0 "0" 5 "5" 10 "10" 11 "{&infinity}") name(supply,replace)
graph export "../exhibits/housingsupplycontribution.pdf", replace


