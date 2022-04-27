/*
 Author(s): Greg Howard & Jack Liebersohn 
 Date: 2021
 
 Description: Script para realizar la figura 3.B
 */


 //Cambiar el esquema de color para las gráficas. S1color para garantizar fondo de la gráfica de color blanco.
 
set scheme s1color

set seed 21
local maxmu=10

use "../data/combineddata", clear
//merge m:1 msa using "../data/cpi_rent/used_in_cpi", gen(hasCPI)
drop if year==1998

//Se destaca que se está trabajando con un panel de datos
xtset msa year
//Se definen las variables para contener sólo los datos del año 2000 en logaritmos (población, renta y máximo de la renta)
gen dlogL= f18s18.logpop if year==2000
*gen dlogR= f18s18.lognoi if year==2000
gen dlogR= rent_new if year==2000
keep dlogL dlogR pop elasticity year hasCPI
keep if year==2000

//Se reemplazan los missing values por cero para que las observaciones no se pierdan en la estimación y se mantega el tamaño de la muestra.
replace dlogR=0 if elasticity==.
replace elasticity=5.35 if elasticity==. 
// 5.35 representa la elasticidad del percentil 99 por la población en el año 2000 (this is the 99th percentile, by population 2000)

//Se guarda esta base de datos sólo con los logaritmos de población, renta y máximo de la renta para el año 2000
gen dlogL= f18s18.logpop if year==2000
tempfile thingtouse
save `thingtouse'

//Se obtiene la media del logaritmo de renta si el Consumer Price Index es igual a 3 y tiene elasticidad y sólo si cuenta con elasticidad. Estos datos 
//Se guardan en dos locals.
summ dlogR [w=pop] if elasticity!=. & hasCPI==3
local dlogRmean_CPI=r(mean)

summ dlogR [w=pop] if elasticity!=.
local dlogRmean=r(mean)

//Ahora bien, se quiere obtener la covarianza del logaritmo de la derivada de la población que se encuentra ubicada en las ciudades por 1 sobre la suma entre
//lambda, sigma y mu.
//Adicionalmente se haya covarianza de la derivada del logaritmo de la derivada de la renta en la ciudad i por una ponderación definida enre sigma, lambda (2/3) y mu.
//Estas correlaciones y elasticidades pretenden hallar el equilibrio de locación de la demanda para las ciudades que cuentan con datos CPI para 
//definir el canal de locacion de la demanda que quieren demostrar los autores en estas ciudades.

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

//En este loop se espera hallar como se mencionó anteriormente las fracciones que multiplicarán los logarimos de la renta y de la población en las ciudades
//con CPI para hallar el canala de locación de la demanda para los valores intermedios de mu. Los límites a medida que mu tiene a cero o a infinito
//corresponden a otras formulas que no se tratan en ese código.
		
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
		
//Para una mejor compresión del procedimiento que sigue a continuación, referirse a la ecuación que corresponde a la proposición 3.		
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

//Se definen los intervalos y límites que utilizarán los valores de mu para la representación gráfica. 
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

//Se empieza a construir la figura 3.B definiendo los intervalos de confianza y las líneas que representarán los diferentes niveles de lambda para 
//interpretacion del lector. En este caso, los autores escogieron 0, 1 y 2/3 (el recomendado por la literatura)

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


//RESUTADOS
//mu: 0.34 lambda: 1.00 geochannel: 0.01 geochannel_CPI: 0.01 pctavg: 0.08 pctcpi: 0.09
//mu: 1.07 lambda: 1.00 geochannel: 0.01 geochannel_CPI: 0.03 pctavg: 0.17 pctcpi: 0.23
//mu: 1.31 lambda: 1.00 geochannel: 0.02 geochannel_CPI: 0.04 pctavg: 0.20 pctcpi: 0.26
//mu: 2.50 lambda: 1.00 geochannel: 0.02 geochannel_CPI: 0.05 pctavg: 0.28 pctcpi: 0.38
//mu: 5.10 lambda: 1.00 geochannel: 0.03 geochannel_CPI: 0.07 pctavg: 0.36 pctcpi: 0.50
//mu: inf lambda: 1.00 geochannel: 0.04 geochannel_CPI: 0.11 pctavg: 0.53 pctcpi: 0.74
//mu: inf lambda: 0.67 geochannel: 0.05 geochannel_CPI: 0.11 pctavg: 0.58 pctcpi: 0.77
//mu: inf lambda: 0.50 geochannel: 0.05 geochannel_CPI: 0.11 pctavg: 0.61 pctcpi: 0.79
//mu: inf lambda: 0.00 geochannel: 0.06 geochannel_CPI: 0.12 pctavg: 0.73 pctcpi: 0.85

