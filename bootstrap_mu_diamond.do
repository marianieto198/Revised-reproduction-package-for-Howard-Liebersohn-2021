/*
 Author(s): Greg Howard & Jack Liebersohn 
 Date: 2021
 
 Description: Crear tabla A4. Se replica el código y los precedimientos de bootstrap_mu_bartik.do pero se utilizan los supuestos de Diamond (2016) en el que
 los choques no observados de la demanda por trabajo no están correlacionados con la elasticidad de la vivienda.
 */
 
//
// Wage replication
//
//

preserve
use "..\data\qcew\2000_msa_industry_shares", clear
keep if industry_code=="31-33" | industry_code=="1023"
keep industryshare msa industry_code
replace industry_code = "finance" if industry_code=="1023"
replace industry_code ="manufshare" if industry_code == "31-33"
reshape wide industryshare, i(msa) j(industry_code) string
rename industryshare* *
tempfile manuf
save `manuf'
restore


// Cambiar el esquema de color para las gráficas. S1color para garantizar fondo de la gráfica de color blanco.
set scheme s1color
clear all
use "../data/combineddata"
keep if elasticity!=.



// Se define variable para definir el número de loops/repeticiones que se deben realizar.
local mynumreps 1000

gen s18lognoi_adj=s18.lognoi_adj if year==2018

collapse (max) s18lognoi_adj rent_new (first) bartik* wageshock elasticity unaval WRLURI, by(msa)

summ elasticity if rent_new !=.
local meanelasticity=r(mean)

merge 1:1 msa using `manuf', nogen


label var s18lognoi_adj "Rent (raw)"
label var rent_new "Rent"

reg s18lognoi_adj c.wageshock#c.elasticity wageshock, r
reg rent_new c.wageshock#c.elasticity wageshock, r

//mu 1 va a ser el estimador que representa el efecto heterogéneo  de los choques en el salario por cada sixtil de elasticidad sobre 
//el logaritmo de la renta ajustada.
//para esto divide los estimadores beta0 y b1. Cuando b0 y b1 tienen el mismo signo el punto de estimación de mu es infinito.
cap program drop myreg
program def myreg, eclass
	qui reg s18lognoi_adj c.wageshock#c.elasticity wageshock, r
	local ratio = -_b[c.wageshock]/_b[c.wageshock#c.elasticity]
	local ratio = 100000*(`ratio'<=0) + `ratio'*(`ratio'>0)
	ereturn scalar ratio=`ratio'
end

// Ahora es necesario tomar el ratio y restarle el valor definido por los autores como lambda (2/3) y se le resta el promedio de la elasticidad.
//con el bootstrap se extraen samples de los datos para hacer varias estimaciones y obtener una distribución de los mu estimados.
tempfile bootdat
bootstrap ratio=e(ratio), reps(`mynumreps') seed(10) saving(`bootdat'): myreg
local mu1=_b[ratio]-(`meanelasticity'+.66667)

preserve
use `bootdat', clear
sum ratio, det
local mu1_p5=r(p5)-(`meanelasticity'+.66667)
local mu1_p10=r(p10)-(`meanelasticity'+.66667)
restore

//mu 3 va a ser el estimador que representa el efecto heterogéneo  de los choques en el salario por cada sixtil de elasticidad sobre la renta.
//para esto divide los estimadores beta0 y b1. Cuando b0 y b1 tienen el mismo signo el punto de estimación de mu es infinito.
cap program drop myreg
program def myreg, eclass
	qui reg rent_new c.wageshock#c.elasticity wageshock, r
	local ratio = -_b[c.wageshock]/_b[c.wageshock#c.elasticity]
	local ratio = 100000*(`ratio'<=0) + `ratio'*(`ratio'>0)
	ereturn scalar ratio=`ratio'
end
// Ahora es necesario tomar el ratio y restarle el valor definido por los autores como lambda (2/3) y se le resta el promedio de la elasticidad.
//con el bootstrap se extraen samples de los datos para hacer varias estimaciones y obtener una distribución de los mu estimados.
tempfile bootdat
bootstrap ratio=e(ratio), reps(`mynumreps') seed(10) saving(`bootdat'): myreg
local mu3=_b[ratio]-(`meanelasticity'+.66667)

preserve
use `bootdat', clear
sum ratio, det
local mu3_p5=r(p5)-(`meanelasticity'+.66667)
local mu3_p10=r(p10)-(`meanelasticity'+.66667)
restore

//Para simplificar lo anterior y presentar una manera alternativa de llegar al mismo resultado se propone:
foreach x of varlist $variabless{ 
global variabless s18lognoi_adj rent_new
cap program drop myreg`x'
program def myreg`x', eclass
	qui reg `x' c.wageshock#c.elasticity wageshock, r
	local ratio`x' = -_b[c.wageshock]/_b[c.wageshock#c.elasticity]
	local ratio`x' = 100000*(`ratio`x''<=0) + `ratio`x''*(`ratio`x''>0)
	ereturn scalar ratio`x'=`ratio`x''

tempfile bootdat
bootstrap ratio`x'=e(ratio`x'), reps(`mynumreps') seed(10) saving(`bootdat'): myreg`x'
local mu3`x'=_b[ratio`x']-(`meanelasticity'+.66667)

end 

preserve
use `bootdat', clear
sum ratio`x', det
local mu3`x'_p5=r(p5)-(`meanelasticity'+.66667)
local mu3`x'_p10=r(p10)-(`meanelasticity'+.66667)
restore
}




//
// Manufacturing Share
//
//

reg s18lognoi_adj c.manufshare#c.elasticity manufshare, r
reg rent_new c.manufshare#c.elasticity manufshare, r

//mu 5 va a ser el estimador que representa el efecto heterogéneo  de la participación de la industria manufacturera por cada sixtil de elasticidad sobre
//el logaritmo de la renta ajustada.
//para esto divide los estimadores beta0 y b1. Cuando b0 y b1 tienen el mismo signo el punto de estimación de mu es infinito.
cap program drop myreg
program def myreg, eclass
	qui reg s18lognoi_adj c.manufshare#c.elasticity manufshare, r
	local ratio = -_b[c.manufshare]/_b[c.manufshare#c.elasticity]
	local ratio = 100000*(`ratio'<=0) + `ratio'*(`ratio'>0)
	ereturn scalar ratio=`ratio'
end

// Ahora es necesario tomar el ratio y restarle el valor definido por los autores como lambda (2/3) y se le resta el promedio de la elasticidad.
//con el bootstrap se extraen samples de los datos para hacer varias estimaciones y obtener una distribución de los mu estimados.
tempfile bootdat
bootstrap ratio=e(ratio), reps(`mynumreps') seed(10) saving(`bootdat'): myreg
local mu5=_b[ratio]-(`meanelasticity'+.66667)

preserve
use `bootdat', clear
sum ratio, det
local mu5_p10=r(p10)-(`meanelasticity'+.66667)
local mu5_p5=r(p5)-(`meanelasticity'+.66667)
restore

//mu 6 va a ser el estimador que representa el efecto heterogéneo  de la participación de la industria manufacturera por cada sixtil de elasticidad sobre
//la renta.
//para esto divide los estimadores beta0 y b1. Cuando b0 y b1 tienen el mismo signo el punto de estimación de mu es infinito.

cap program drop myreg
program def myreg, eclass
	qui reg rent_new c.manufshare#c.elasticity manufshare, r
	local ratio = -_b[c.manufshare]/_b[c.manufshare#c.elasticity]
	local ratio = 100000*(`ratio'<=0) + `ratio'*(`ratio'>0)
	ereturn scalar ratio=`ratio'
end

// Ahora es necesario tomar el ratio y restarle el valor definido por los autores como lambda (2/3) y se le resta el promedio de la elasticidad.
//con el bootstrap se extraen samples de los datos para hacer varias estimaciones y obtener una distribución de los mu estimados.
tempfile bootdat
bootstrap ratio=e(ratio), reps(`mynumreps') seed(10) saving(`bootdat'): myreg
local mu6=_b[ratio]-(`meanelasticity'+.66667)

preserve
use `bootdat', clear
sum ratio, det
local mu6_p5=r(p5)-(`meanelasticity'+.66667)
local mu6_p10=r(p10)-(`meanelasticity'+.66667)
restore

////De igual manera, para simplificar lo anterior y llegar al mismo resultado se propone:
foreach x of varlist $variabless{ 
cap program drop myreg`x'
program def myreg`x', eclass
	qui reg `x' c.manufshare#c.elasticity manufshare
	local ratio`x' = -_b[c.manufshare]/_b[c.manufshare#c.elasticity]
	local ratio`x' = 100000*(`ratio`x''<=0) + `ratio`x''*(`ratio`x''>0)
	ereturn scalar ratio`x'=`ratio`x''

tempfile bootdat
bootstrap ratio`x'=e(ratio`x'), reps(`mynumreps') seed(10) saving(`bootdat'): myreg`x'
local mu3`x'=_b[ratio`x']-(`meanelasticity'+.66667)

end 

preserve
use `bootdat', clear
sum ratio`x', det
local mu3`x'_p5=r(p5)-(`meanelasticity'+.66667)
local mu3`x'_p10=r(p10)-(`meanelasticity'+.66667)
restore
}
//
// Bartik replication
//
//

/*
use "..\data\qcew\2000_msa_industry_shares", clear
keep if agglvl_code==73
gen bartik_wage = (national_emp2018/national_emp2000)*industryshare
gcollapse (sum) bartik industryshare, by(msa)
replace bartik_wage = log(bartik + 1-industryshare) // "missing" industry isnt growing
keep bartik msa
tempfile bartik
save `bartik'
*/
use "..\data\qcew\2000_msa_industry_shares", clear
keep if industry_code=="31-33" | industry_code=="1023"
keep industryshare msa industry_code
replace industry_code = "finance" if industry_code=="1023"
replace industry_code ="manufshare" if industry_code == "31-33"
reshape wide industryshare, i(msa) j(industry_code) string
rename industryshare* *
*merge 1:1 msa using `bartik', nogen
tempfile manuf
save `manuf'



set scheme s1color
clear all
use "../data/combineddata"
keep if elasticity!=.

*replace elasticity = -unaval


* optionally noise up the estimates
*replace elasticity = elasticity+rnormal()

gen s18lognoi_adj=s18.lognoi_adj if year==2018
*gen s17loghpi = s17.loghpi if year==2017

collapse (max) s18lognoi_adj rent_new (first) bartik* elasticity unaval WRLURI, by(msa)

summ elasticity if s18lognoi_adj !=.
local meanelasticity=r(mean)
replace elasticity=elasticity-`meanelasticity'

merge 1:1 msa using `manuf', nogen

xtile elasticitybin=elasticity, n(10)

reg s18lognoi_adj c.bartik_wage c.bartik_wage#c.elasticity, r
reg rent_new c.bartik_wage c.bartik_wage#c.elasticity, r


* unlike in the other estimates, here it is necessary to adjust for inflation and measure it in growth rates
* elsewhere this wont make a difference...
//replace bartik_inc = bartik_inc/1.44 - 1
replace bartik_wage = bartik_wage/1.44 - 1

*replace bartik_inc = log(bartik_inc)
*replace bartik_wage = log(bartik_wage)


// Bootstrap Bartik
//mu 2 va a ser el estimador que representa el efecto heterogéneo  de la variable bartik_wage (interacción entre la participación de las industrias locales
// y el crecimiento de está industria) por cada sixtil de elasticidad sobre el logaritmo de la renta ajustada.
//para esto divide los estimadores beta0 y b1. Cuando b0 y b1 tienen el mismo signo el punto de estimación de mu es infinito.
cap program drop myreg
program def myreg, eclass
	qui reg s18lognoi_adj c.bartik_wage c.bartik_wage#c.elasticity, r
	local ratio = -_b[c.bartik_wage]/_b[c.bartik_wage#c.elasticity]
	local ratio = 100000*(`ratio'<=0) + `ratio'*(`ratio'>0)
	ereturn scalar ratio=`ratio'
end

// Ahora es necesario tomar el ratio y restarle el valor definido por los autores como lambda (2/3) y se le resta el promedio de la elasticidad.
//con el bootstrap se extraen samples de los datos para hacer varias estimaciones y obtener una distribución de los mu estimados.

tempfile bootdat
bootstrap ratio=e(ratio), reps(`mynumreps') seed(10) saving(`bootdat'): myreg
local mu2=_b[ratio]-(`meanelasticity'+.66667)

preserve
use `bootdat', clear
sum ratio, det
local mu2_p5=r(p5)-(`meanelasticity'+.66667)
local mu2_p10=r(p10)-(`meanelasticity'+.66667)
restore

//mu 4 va a ser el estimador que representa el efecto heterogéneo  de la variable bartik_wage (interacción entre la participación de las industrias locales
// y el crecimiento de está industria) por cada sixtil de elasticidad sobre la renta ajustada.
//para esto divide los estimadores beta0 y b1. Cuando b0 y b1 tienen el mismo signo el punto de estimación de mu es infinito.
cap program drop myreg
program def myreg, eclass
	qui reg rent_new c.bartik_wage c.bartik_wage#c.elasticity, r
	local ratio = -_b[c.bartik_wage]/_b[c.bartik_wage#c.elasticity]
	local ratio = 100000*(`ratio'<=0) + `ratio'*(`ratio'>0)
	ereturn scalar ratio=`ratio'
end
// Ahora es necesario tomar el ratio y restarle el valor definido por los autores como lambda (2/3) y se le resta el promedio de la elasticidad.
//con el bootstrap se extraen samples de los datos para hacer varias estimaciones y obtener una distribución de los mu estimados.
tempfile bootdat
bootstrap ratio=e(ratio), reps(`mynumreps') seed(10) saving(`bootdat'): myreg
local mu4=_b[ratio]-(`meanelasticity'+.66667)

preserve
use `bootdat', clear
sum ratio, det
local mu4_p5=r(p5)-(`meanelasticity'+.66667)
local mu4_p10=r(p10)-(`meanelasticity'+.66667)
restore


////Asimismo, una manera alternativa de llegar al mismo resultado es:
foreach x of varlist $variabless{ 
global variabless s18lognoi_adj rent_new
cap program drop myreg`x'
program def myreg`x', eclass
	qui reg `x' c.bartik_wage c.bartik_wage#c.elasticity, r
	local ratio`x' =  -_b[c.bartik_wage]/_b[c.bartik_wage#c.elasticity]
	local ratio`x' = 100000*(`ratio`x''<=0) + `ratio`x''*(`ratio`x''>0)
	ereturn scalar ratio`x'=`ratio`x''

tempfile bootdat
bootstrap ratio`x'=e(ratio`x'), reps(`mynumreps') seed(10) saving(`bootdat'): myreg`x'
local mu3`x'=_b[ratio`x']-(`meanelasticity'+.66667)

end 

preserve
use `bootdat', clear
sum ratio`x', det
local mu3`x'_p5=r(p5)-(`meanelasticity'+.66667)
local mu3`x'_p10=r(p10)-(`meanelasticity'+.66667)
restore
}
//
// Results
//Los mu estimados de estas especificaciones son más pequeños y más alineados con los hallazgos de la literatura previa.En este caso recordamos que no hay 
//controles de elasticidad en estas especificaciones.
//


di "diamond oldrent wageshock mean: `mu1' p5: `mu1_p5' p10: `mu1_p10'"
di "diamond oldrent manufshare mean: `mu5' p5: `mu5_p5' p10: `mu5_p10'"
di "diamond oldrent bartik mean: `mu2' p5: `mu2_p5' p10: `mu2_p10'"

di "diamond newrent wageshock mean: `mu3' p5: `mu3_p5' p10: `mu3_p10'"
di "diamond newrent manufshare mean: `mu6' p5: `mu6_p5' p10: `mu6_p10'"
di "diamond newrent bartik mean: `mu4' p5: `mu4_p5' p10: `mu4_p10'"
