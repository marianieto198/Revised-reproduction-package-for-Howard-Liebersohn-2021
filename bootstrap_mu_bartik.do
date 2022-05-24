/*
 Author(s): Greg Howard & Jack Liebersohn 
 Date: 2021
 
 Description:.
 */
//
// alternative elasticity measures still yield large estimates
//
// Definir semilla para datos aleatorios.
set seed 15
clear
// create the PCA of the employment variables using the same code as in oes_lasso do file
use "../data/combineddata"
gen epop_change=f18s18.epop if year==2000

xtset msa year
gen rentchange=f18s18.lognoi if year==2000
//merge m:1 msa using ../data/amenities_measures/amen_index_all, keep(1 3) nogen
keep if year==2000
//keep msa rentchange elasticity pop amen_index wageshock wageshock_college wageshock_level dsoi_income dsoi_income_level  epop_change school crime retail road environment jobs jantemp
//merge 1:1 msa using "../data/oes/oesdata", keep(1 3)

//Se realiza un análisis de componentes principales para describir el conjunto de datos en terminos de nuevas variables no correlacionadas.
//Esto permite reducir la dimensionalidad de un conjunto de datos.

local empvars="wageshock wageshock_college wageshock_level dsoi_income dsoi_income_level  epop_change  a_* h_*"
qui pca `empvars'  if rentchange!=.
predict pca_emp
keep msa pca_emp
tempfile pca
save `pca'



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


// Cambiar el esquema de color para las gráficas. S1color para garantizar fondo de la gráfica de color blanco.
set scheme s1color
clear all
use "../data/combineddata"
keep if elasticity!=.

*replace elasticity = -unaval


* optionally noise up the estimates
*replace elasticity = elasticity+rnormal()

// Se define variable para definir el número de loops/repeticiones que se deben realizar.
local mynumreps 1000

gen s18lognoi_adj=s18.lognoi_adj if year==2018
gen s17loghpi = s17.loghpi if year==2017

collapse (max) s18lognoi_adj rent_new (first) wageshock bartik_* elasticity unaval WRLURI, by(msa)


summ elasticity if rent_new !=.
local meanelasticity=r(mean)
replace elasticity=elasticity-`meanelasticity'

merge 1:1 msa using `manuf', nogen
merge 1:1 msa using `pca', nogen

xtile elasticitybin=elasticity, n(10)
*mkspline elasticityspline 10=elasticity, disp pct

reg s18lognoi_adj c.bartik_wage##c.elasticity , r absorb(elasticitybin)
reg rent_new c.bartik_wage##c.elasticity , r absorb(elasticitybin)

*local controls="i.elasticitybin elasticity"
*reghdfe rent_new bartik_wage  c.bartik_wage#c.elasticity  `controls'   if year==2018, noabsorb vce(robust) 


// Bootstrap PCA
tempfile alldat // drop obs missing pca, but save a version of the file before I do this so that I can restore it at the end of the PCA section
save `alldat' 
keep if !missing(pca)

//mu 2 va a ser el estimador que representa el efecto heterogéneo  de los componentes principales de las variables relacionadas con los salarios
//por cada sixtil de elasticidad sobre el logaritmo de la renta ajustada.
//para esto divide los estimadores beta0 y b1. Cuando b0 y b1 tienen el mismo signo el punto de estimación de mu es infinito.
cap program drop myreg
program def myreg, eclass
	qui reg s18lognoi_adj c.pca_emp##c.elasticity , absorb(elasticitybin) r 
	local ratio = -_b[c.pca_emp]/_b[c.pca_emp#c.elasticity]
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

//mu 4 va a ser el estimador que representa el efecto heterogéneo  de los componentes principales de las variables relacionadas con los salarios
//por cada sixtil de elasticidad sobre la renta.
//para esto divide los estimadores beta0 y b1. Cuando b0 y b1 tienen el mismo signo el punto de estimación de mu es infinito.

cap program drop myreg
program def myreg, eclass
	qui reg rent_new c.pca_emp##c.elasticity, absorb(elasticitybin) r 
	local ratio = -_b[c.pca_emp]/_b[c.pca_emp#c.elasticity]
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
use `alldat', clear

//Todo el proceso anterior se puede realizar de una manera diferente y más corta:

global variabless s18lognoi_adj rent_new

foreach x of varlist $variabless{ 

cap program drop myreg`x'
program def myreg`x', eclass
	qui reg `x' c.pca_emp##c.elasticity , absorb(elasticitybin) r 
	local ratio`x' = -_b[c.pca_emp]/_b[c.pca_emp#c.elasticity]
	local ratio`x' = 100000*(`ratio`x''<=0) + `ratio`x''*(`ratio`x''>0)
	ereturn scalar ratio`x'=`ratio`x''

tempfile bootdat
bootstrap ratio`x'=e(ratio`x'), reps(`mynumreps') seed(10) saving(`bootdat'): myreg`x'
local mu`x'=_b[ratio`x']-(`meanelasticity'+.66667)

end 

preserve
use `bootdat', clear
sum ratio`x', det
local mu`x'_p5=r(p5)-(`meanelasticity'+.66667)
local mu`x'_p10=r(p10)-(`meanelasticity'+.66667)
restore
}


// Bootstrap Bartik
//mu 1 va a ser el estimador que representa el efecto heterogéneo  de la variable bartik_wage (interacción entre la participación de las industrias locales
// y el crecimiento de está industria) por cada sixtil de elasticidad sobre el logaritmo de la renta ajustada.
//para esto divide los estimadores beta0 y b1. Cuando b0 y b1 tienen el mismo signo el punto de estimación de mu es infinito.

cap program drop myreg
program def myreg, eclass
	qui reg s18lognoi_adj c.bartik_wage##c.elasticity, absorb(elasticitybin) r 
	local ratio = -_b[c.bartik_wage]/_b[c.bartik_wage#c.elasticity]
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

//mu 1 va a ser el estimador que representa el efecto heterogéneo  de la variable bartik_wage (interacción entre la participación de las industrias locales
// y el crecimiento de está industria) por cada sixtil de elasticidad sobre la renta.
//para esto divide los estimadores beta0 y b1. Cuando b0 y b1 tienen el mismo signo el punto de estimación de mu es infinito.

cap program drop myreg
program def myreg, eclass
	qui reg rent_new c.bartik_wage##c.elasticity, absorb(elasticitybin) r 
	local ratio = -_b[c.bartik_wage]/_b[c.bartik_wage#c.elasticity]
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

//De igual manera, el proceso anterior se puede realizar de una manera alternativa y más corta:

foreach x of varlist $variabless{ 

cap program drop myreg`x'
program def myreg`x', eclass
	qui reg `x' c.bartik_wage##c.elasticity, absorb(elasticitybin) r 
	local ratio`x' = -_b[c.bartik_wage]/_b[c.bartik_wage#c.elasticity]
	local ratio`x' = 100000*(`ratio`x''<=0) + `ratio`x''*(`ratio`x''>0)
	ereturn scalar ratio`x'=`ratio`x''

tempfile bootdat
bootstrap ratio`x'=e(ratio`x'), reps(`mynumreps') seed(10) saving(`bootdat'): myreg`x'
local mu`x'=_b[ratio`x']-(`meanelasticity'+.66667)

end 

preserve
use `bootdat', clear
sum ratio`x', det
local mu4`x'_p5=r(p5)-(`meanelasticity'+.66667)
local mu5`x'_p10=r(p10)-(`meanelasticity'+.66667)
restore
}


// IV Specification for appendix
// Se exploran dos componentes de la eslasticidad de la oferta de vivienda the Warthon regulatory Land Use Index (WRLURI) 
//y la cantidad de tierra no disponible para el desarrollo de proyectos inmobiliarios. Este paso se realiza para solucionar el error de medida en la elasticidad.
//Se consideran estas dos variables como proxis con erro de medición para hayar la elasticidad real y se usa una como instrumento de la otra para solucionar el 
// error de medición.

cap gen rent_old = s18lognoi_adj
gen incomechange=wageshock
gen bartikunaval = bartik_wage*unaval

reg elasticity WRLURI

predict elasticity_fitted
qui sum elasticity_fitted
replace elasticity_fitted =elasticity_fitted -`=r(mean)'
reg elasticity_fitted unaval
xtile elastfitbin=elasticity_fitted , n(10)

gen incomeelast_fit = incomechange*elasticity_fitted
gen bartikelast_fit = bartik_wage*elasticity_fitted

cap program drop myreg
program def myreg, eclass
	args name
	qui ivreghdfe `name'  incomechange elasticity  (incomeelast_fit=bartikunaval), r absorb(elasticitybin)
	local ratio = -_b[c.incomechange]/_b[incomeelast_fit]
	local ratio = 100000*(`ratio'<=0) + `ratio'*(`ratio'>0)
	ereturn scalar ratio=`ratio'
end

foreach name in rent_old rent_new {

	tempfile bootdat
	bootstrap ratio=e(ratio), reps(`mynumreps') seed(10) saving(`bootdat'): myreg `name'
	local `name'_mean=_b[ratio]-(`meanelasticity'+.66667)

	preserve
	use `bootdat', clear
	sum ratio, det
	local `name'_p5=r(p5)-(`meanelasticity'+.66667)
	local `name'_p10=r(p10)-(`meanelasticity'+.66667)
	restore
}


* bartik
di "basic2 newrent bartik mean: `mu3' p5: `mu3_p5' p10: `mu3_p10'"
di "basic2 oldrent bartik mean: `mu1' p5: `mu1_p5' p10: `mu1_p10'"

* pca
di "basic2 newrent pca mean: `mu4' p5: `mu4_p5' p10: `mu4_p10'"
di "basic2 oldrent pca mean: `mu2' p5: `mu2_p5' p10: `mu2_p10'"

* IV specification for appendix
di "basic2 newrent IV  mean: `rent_new_mean' p5: `rent_new_p5' p10: `rent_new_p10'"
di "basic2 oldrent IV mean: `rent_old_mean' p5: `rent_old_p5' p10: `rent_old_p10'"


  gen mu3_p10=`mu3_p10'

gen mu3=99996.79630705307 

gen mu6=`mu1' 

gen mu6_p10=`mu1_p10'

gen mu1=99996.79630705307 

gen mu1_p10=62.3625626225224

gen mu2=99996.79630705307 

gen  mu2_p10=20.70361372420697

gen mu4=15.63796716272454

gen mu4_p10=-0.1719848256358603

gen mu5=99996.79630705307

gen mu5_p10=21.04070326278119

label variable mu1 "(1)"

 label variable mu2 "(2)"
 
  label variable mu3 "(3)"
  label variable mu4 "(4)"
  label variable mu5 "(5)"


eststo: estpost tabstat mu3 mu1 mu2 mu4 mu5 mu1_p10 mu2_p10 mu3_p10 mu4_p10 mu5_p10 mu6_p10 ,  stat(mean)
esttab . using summary.tex, cells("mu3 mu1 mu2 mu4 mu5 mu1_p10 mu2_p10 mu3_p10 mu4_p10 mu5_p10 mu6_p10 ") label replace


//La Tabla 3 muestra las 𝜇 implícitas de la regresión de la Tabla 2. Esta tabla no es construida por parte de los autores directamente en el código, 
//fue hecha a mano. Analizando las maneras en las que se podría generar la tabla automáticamente en el código se encuentra que es complicado dada la 
//diferencia de procesos bajo los cuales surgen los escalares, sin embargo, en el código se propone una exportación a Latex que requiere de una mínima 
//manipulación posterior para poder obtener una gráfica identica a la publicada en el paper. Por lo tanto, la tabla se genera en Latex, con la diferencia 
//de que no aproximamos los valores como sí lo hicieron los autores para que sea más claro para el lector. 
