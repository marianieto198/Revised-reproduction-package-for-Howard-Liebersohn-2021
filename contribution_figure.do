/*
Author(s): Greg Howard & Jack Liebersohn
Date:2021

Description: Script para realizar la figura 3.A
*/

//Fondo blanco para gráfica 
set scheme s1color

//Como mu tiende a infinito, para el caso de esta gráfica se cortará en 10
local maxmu=10

//Los autores utilizan combineddata tanto en este dofile como en varios otros
//debido a que no proporcionan los datos usados de forma aislada sino que se suministra la base combinada.
use "../data/combineddata", clear
//Panel de datos
xtset msa year
//Generar variables para el año 2000 
//Población
gen dlogL= f18s18.logpop if year==2000
*gen dlogR= f18s18.lognoi if year==2000
//Renta
gen dlogR= rent_new if year==2000
//Mantienen las siguientes variables:
keep dlogL dlogR pop elasticity year
//Solo mantienen los datos del año 2000
keep if year==2000

//Para missing values en elasticidad, asignan valor de cero en el logaritmo de la renta
replace dlogR=0 if elasticity==.
//Asignan valor de elasticidad para esos missing values (elasticidad del percentil 99)
replace elasticity=5.35 if elasticity==. // this is the 99th percentile, by population 2000
//Guardar esta base reducida
tempfile thingtouse
save `thingtouse'

//Estadísticas descriptivas de dlogR cuando haya missing values exceptuando la variable de elasticidad (se acaba de reemplazar los que había)
summ dlogR [w=pop] if elasticity!=.
local dlogRmean=r(mean)

//Correlación entre logaritmo de renta y elasticidad
corr dlogR elasticity [w=pop], cov
local covR=r(cov_12)
summ elasticity [w=pop]
//En las siguientes líneas se generan variables temporales para cada uno de los valores de lambda que los autores analizan - los obtienen de la literatura 
local elasticity_mean=r(mean)

local muinftylambda0=-`covR'/`elasticity_mean'                         
local muinftylambda23=-`covR'/(`elasticity_mean'+2/3)                 
local muinftylambda12=-`covR'/(`elasticity_mean'+1/2)                  
local muinftylambda1=-`covR'/(`elasticity_mean'+1)                     

//Lambda= 0 ; Lambda= 2/3; Lambda= 1
disp `muinftylambda0'
disp `muinftylambda23'
disp `muinftylambda1'
//Quietly - Generan variables con missing values que se utilizarán en el loop descrito a continuación. 
//Búsqueda de fracciones - lambda (notar 2/3). Usan la base reducida creada al inicio del dofile - datos del año 2000 específicamente.

qui {

clear all
tempfile lambdamu
gen lambda=.
gen mu=.
gen geochannel=.
save `lambdamu'
foreach lambda in 0 .66667 1{
	forvalues mu= 0(.2)`maxmu'{
		use `thingtouse'
		
		gen oneoverSML=1/(elasticity+`lambda'+`mu')
		gen SLoverSML=(elasticity+`lambda')/(elasticity+`lambda'+`mu')
		corr oneoverSML dlogL [w=pop], cov
		local covL=r(cov_12) 
		corr SLoverSML dlogR [w=pop], cov
		local covR=r(cov_12)
		summ SLoverSML [w=pop]
		local denom=r(mean)
		
		local geochannel=(`covL'-`covR')/`denom'
		clear all
		set obs 1
		gen lambda=`lambda'
		gen mu = `mu'
		gen geochannel=`geochannel'               
		append using `lambdamu'
		save `lambdamu', replace
	}
}

}

local maxmuplusone=`maxmu'+1
local maxmuplushalf=`maxmu'+.5

local obs1=_N+1
set obs `obs1'

//Generar promedio de logaritmo de la renta y posteriormente sacarle las fracciones 1/2, 1/4 y 3/4 . 
gen dlogRmean=`dlogRmean'

local dlogRmean12=`dlogRmean'/2
local dlogRmean14=`dlogRmean'/4
local dlogRmean34=`dlogRmean'/4*3

//Valor de 11 corresponde a maxmuplusone  
replace mu=11 if mu==.
//Ordenar los valores de mu de manera ascendente
gsort mu

//Construir la figura 3.A - Líneas distintas dependiendo del valor de Lambda (tomado de la literatura).
//AD - Se cambiará el patrón de las líneas debido a que en el paper se publicaron todas en línea continua y no dashed,
//como aparece en el script suministrado originalmente. Así mismo, se cambia el patrón de la línea que indica el 100% de incremento en renta
line geochannel mu if lambda==0 , lpattern(solid) || line geochannel mu if abs(lambda-.66667)<.01 || line geochannel mu if lambda==1, lpattern(solid) ///
	|| scatteri `muinftylambda0' `maxmuplusone', color(forest_green) || scatteri `muinftylambda23' `maxmuplusone', color(orange) || scatteri `muinftylambda1' `maxmuplusone', color(navy) ///
	|| line dlogRmean mu, yaxis(2) lcolor(maroon) lpattern(dash) ytitle("Log-Points") xtitle("{&mu}") ///
	legend(order(1 2 3 7) label(1 "{&lambda}=0") label(2 "{&lambda}=2/3") label(3 "{&lambda}=1") label(7 "Total Rent Increase")) ///
	yscale(range(0 .1)) ylabel(#4) yline(0, lcolor(gs10))  xline(`maxmuplushalf', lcolor(gs10) lpattern(dot)) xlabel( 0 "0" 5 "5" 10 "10" 11 "{&infinity}") ///
	yscale(range(0 .1) axis(2))	ylabel(0 "0" `dlogRmean14' "25" `dlogRmean12' "50" `dlogRmean34' "75" `dlogRmean' "100", axis(2)) ytitle("Percent of Rent Increase", axis(2))
	
graph export "../exhibits/contribution.pdf", as(pdf) replace

di "Average rents: .096"

disp `dlogRmean'
disp `muinftylambda0' `=`muinftylambda0'/`dlogRmean''
disp `muinftylambda12'  `=`muinftylambda12'/`dlogRmean''
disp `muinftylambda23'   `=`muinftylambda23'/`dlogRmean''
disp `muinftylambda1'    `=`muinftylambda1'/`dlogRmean''

