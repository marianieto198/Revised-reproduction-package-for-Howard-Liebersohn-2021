/*
 Author(s): Greg Howard & Jack Liebersohn 
 Date: 2021
 
 Description: Script para realizar parte de la tabla 3 y A2.
 */
set seed 15


preserve
use "..\data\qcew\2000_msa_industry_shares", clear
// Solo se utilizan datos de las industrias cuyo código sea "31-33" (manufactureras) o "1023" (financieras).
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
run "../dofiles/cpi_contribution_table.do" // run the do-file that creates a program to calculate the migration channel for any particular mu, lambda variables
use "../data/combineddata", clear
keep if elasticity!=.


*replace elasticity = -unaval


* optionally noise up the estimates
*replace elasticity = elasticity+rnormal()

local mynumreps 1000

gen s18lognoi_adj=s18.lognoi_adj if year==2018
*gen s17loghpi = s17.loghpi if year==2017

// Por MSA (Área Metropolitana) dejar el valor máximo de s18lognoi_adj rent_new y el primer valor de wageshock elasticity unaval WRLURI.
collapse (max) s18lognoi_adj rent_new (first) wageshock elasticity unaval WRLURI, by(msa)

summ elasticity if rent_new !=.
local meanelasticity=r(mean)
// se remplaza la variable elasticity por la desviación de la media de la elasticidad. 
replace elasticity=elasticity-`meanelasticity'

merge 1:1 msa using `manuf', nogen

xtile elasticitybin=elasticity, n(10)

*mkspline elasticityspline 10=elasticity, disp pct

// Se hacen regresiones del cambio logaritmico de la renta ajustado y de la renta regresado por las variables wageshock interactuando con la elasticidad
//y se tiene una variable dummy (elasticitybin) que son los sixtiles de elasticidad. 
reg s18lognoi_adj c.wageshock##c.elasticity, r absorb(elasticitybin)
outreg2 using reg1.doc, ctitle(Model 1)
*reg s17loghpi c.wageshock##c.elasticity, r absorb(elasticitybin)
reg rent_new c.wageshock##c.elasticity, r absorb(elasticitybin)
outreg2 using reg2.doc, append ctitle(Model 2)
*reghdfe rent_new c.elasticity##c.wageshock elasticityspline* , noabsorb vce(robust) nocon

cap program drop myreg
//Se programa la misma regresión anterior para convertir los resultados de los estimadores en escalares.
program def myreg, eclass
	qui reg s18lognoi_adj c.wageshock##c.elasticity, r  absorb(elasticitybin)
	local ratio = -_b[c.wageshock]/_b[c.wageshock#c.elasticity]
	local ratio = 100000*(`ratio'<=0) + `ratio'*(`ratio'>0)
	ereturn scalar ratio=`ratio'
end

//Mediante iteraciones se encuentran los valores de los mu's para encontrar los efectos heterogéneos de la regresión.
//Sin embargo, no es claro el procedimiento
tempfile bootdat
bootstrap ratio=e(ratio), reps(`mynumreps') seed(10) saving(`bootdat'): myreg
local mu1=_b[ratio]-(`meanelasticity'+.66667)

preserve
use `bootdat', clear
sum ratio, det
local mu1_p5=r(p5)-(`meanelasticity'+.66667)
local mu1_p10=r(p10)-(`meanelasticity'+.66667)
restore

cap program drop myreg
program def myreg, eclass
	qui reg s18lognoi_adj c.manufshare##c.elasticity , r absorb(elasticitybin)
	local ratio = -_b[c.manufshare]/_b[c.manufshare#c.elasticity]
	local ratio = 100000*(`ratio'<=0) + `ratio'*(`ratio'>0)
	ereturn scalar ratio=`ratio'
end

tempfile bootdat
bootstrap ratio=e(ratio), reps(`mynumreps') seed(10) saving(`bootdat'): myreg
local mu2=_b[ratio]-(`meanelasticity'+.66667)

preserve
use `bootdat', clear
sum ratio, det
local mu2_p5=r(p5)-(`meanelasticity'+.66667)
local mu2_p10=r(p10)-(`meanelasticity'+.66667)
restore

cap program drop myreg
program def myreg, eclass
	qui reg rent_new c.wageshock##c.elasticity , r absorb(elasticitybin)
	local ratio = -_b[c.wageshock]/_b[c.wageshock#c.elasticity]
	local ratio = 100000*(`ratio'<=0) + `ratio'*(`ratio'>0)
	ereturn scalar ratio=`ratio'
end

tempfile bootdat
bootstrap ratio=e(ratio), reps(`mynumreps') seed(10) saving(`bootdat'): myreg
local mu3=_b[ratio]-(`meanelasticity'+.66667)

preserve
use `bootdat', clear
sum ratio, det
local mu3_p5=r(p5)-(`meanelasticity'+.66667)
local mu3_p10=r(p10)-(`meanelasticity'+.66667)

// Calculate distribution of implied geo channel by looping through bootstrap draws and calculating the implied geography channel
gen mu = ratio-(`meanelasticity'+.66667)
gen geo_channel = .
gen geo_channel_CPI = .
gen frac_cpi = .
gen frac_rent = .
di "Calculating distribution of geography channel"
forv i=1/`=_N' {
	local thismu = mu in `i'
	qui {
	if `thismu'>9999 {
		calculate_geo_channel inf `=2/3'
	}
	else {
		calculate_geo_channel `thismu'  `=2/3'
	}
	replace frac_cpi = `=r(pct_cpi)' in `i'
	replace frac_rent = `=r(pct_avg)' in `i'
	replace geo_channel = `=r(geochannel)' in `i'
	replace geo_channel_CPI = `=r(geochannel_CPI)' in `i'
	}
}
sum mu, det
sum frac_cpi, det
sum frac_rent, det
sum geo_channel, det
sum geo_channel_CPI, det

restore


cap program drop myreg
program def myreg, eclass
	qui reg rent_new c.manufshare##c.elasticity , r absorb(elasticitybin)
	local ratio = -_b[c.manufshare]/_b[c.manufshare#c.elasticity]
	local ratio = 100000*(`ratio'<=0) + `ratio'*(`ratio'>0)
	ereturn scalar ratio=`ratio'
end

tempfile bootdat
bootstrap ratio=e(ratio), reps(`mynumreps') seed(10) saving(`bootdat'): myreg
local mu4=_b[ratio]-(`meanelasticity'+.66667)

preserve
use `bootdat', clear
sum ratio, det
local mu4_p5=r(p5)-(`meanelasticity'+.66667)
local mu4_p10=r(p10)-(`meanelasticity'+.66667)
restore

disp "basic unadjusted wageshock mean: `mu1' p5: `mu1_p5' p10: `mu1_p10'"
disp "basic unadjusted manufacturing mean: `mu2' p5: `mu2_p5' p10: `mu2_p10'"

disp "basic newrent wageshock mean: `mu3' p5: `mu3_p5' p10: `mu3_p10'"
di "basic newrent manufacturing mean: `mu4' p5: `mu4_p5' p10: `mu4_p10'"
// disp "basic unadjusted wageshock mean: `mu1' p5: `mu1_p5' p10: `mu1_p10'"
//basic unadjusted wageshock mean: 15.63796716272455 p5: -.8279255967387655 p10: -.1719848256358603//

//disp "basic unadjusted manufacturing mean: `mu2' p5: `mu2_p5' p10: `mu2_p10'"
//basic unadjusted manufacturing mean:  p5:  p10: 

//disp "basic newrent wageshock mean: `mu3' p5: `mu3_p5' p10: `mu3_p10'"
basic newrent wageshock mean: 99996.79630705307 p5: 3.832046236490299 p10: 21.04070326278119

//di "basic newrent manufacturing mean: `mu4' p5: `mu4_p5' p10: `mu4_p10'"
basic newrent manufacturing mean: 99996.79630705307 p5: 7.436384644006779 p10: 20.70361372420697//

