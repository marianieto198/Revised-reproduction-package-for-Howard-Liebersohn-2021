/*
Author(s): Greg Howard & Jack Liebersohn
Date:2021

Description: Script para producir Tabla A3 - Efectos heterogéneos de cambio en el ingreso sobre costos de housing, sin control de elasticidad
*/

clear all


//industry shares del Quarterly Census of Employment and Wages, manteniendo industrias especificas
use "..\data\qcew\2000_msa_industry_shares", clear
keep if industry_code=="31-33" | industry_code=="1023"
keep industryshare msa industry_code
replace industry_code = "finance" if industry_code=="1023"
replace industry_code ="manufshare" if industry_code == "31-33"
reshape wide industryshare, i(msa) j(industry_code) string
rename industryshare* *
tempfile manuf
save `manuf'
use ../data/combineddata, clear


use ../data/combineddata, clear

merge m:1 msa using `manuf', nogen


gen incomechange=wageshock
gen incomechange_elasticity=incomechange*elasticity
gen elasticity2 = elasticity^2

//interacciones entre la elasticidad y la industry-specific
gen manuf_elasticity = manufshare*elasticity
gen bartik_wage_elasticity = bartik_wage*elasticity
//Panel de datos
xtset msa year


* unlike in the other estimates, here it is necessary to adjust for inflation
//Lo anterior porque no van a controlar por elasticidad
//replace bartik_inc = bartik_inc/1.44 - 1
replace bartik_wage = bartik_wage/1.44 - 1

summ elasticity if year==2000 & rent_new!=.
local meanelasticity=r(mean)
*gen demeanedelasticity=elasticity-`meanelasticity'
gen demeanedelasticity=elasticity

gen bartik_wageelasticity=bartik_wage*demeanedelasticity
gen incomeelasticity=incomechange*demeanedelasticity
gen manufelasticity=manufshare*demeanedelasticity

//Utilizan variables que venían de la tabla A1, sin embargo, 
//son menos porque no se contemplan varias de las interacciones con elasticidad, ni las elasticidades de otros autores.
label var incomechange "Income Change"
label var manufshare "Manufacturing Share"
label var incomeelasticity "Income Change by Elasticity"
label var manufelasticity "Manufacturing Share by Elasticity"
label var bartik_wageelasticity "Bartik by Elast."
label var bartik_wage "Bartik Shock"

//Distinguir entre rents sin ajustar y ajustadas. 
gen rents=s18.lognoi 
label var rents "Rent (raw)"
label var rent_new "Rent"

//Regresiones (para los años 2017 y 2018 según índice de rentas ajustado o no)
//Para este caso, utilizan vce (robust), contrario a la Tabla A1
reg rents  bartik_wage bartik_wageelasticity if year==2018,  vce(robust) 
est sto noi_bartik_wage

reg rents  manufshare manufelasticity if year==2018,  vce(robust) 
est sto noi_manuf

reg rents  incomechange incomeelasticity if year==2018,  vce(robust) 
est sto noi_incomechange

reg rent_new  bartik_wage bartik_wageelasticity  if year==2017,  vce(robust) 
est sto rent_new_bartik_wage

reg rent_new  manufshare manufelasticity if year==2017,  vce(robust) 
est sto rent_new_manuf

reg rent_new  incomechange incomeelasticity if year==2017,  vce(robust) 
est sto rent_new_incomechange

esttab noi_incomechange noi_manuf noi_bartik_wage rent_new_incomechange rent_new_manuf rent_new_bartik_wage using "../exhibits/estimating_mu_diamond.tex", se tex replace label addnote("Robust standard errors.")
