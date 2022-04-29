/*
Author(s): Greg Howard & Jack Liebersohn
Date:2021

Description: Script para realizar las figuras B1 y B2
*/

clear all

//Los autores utilizan combineddata tanto en este dofile como en varios otros, 
//debido a que no proporcionan los datos usados de forma aislada sino que se suministra la base combinada.
use "../data/combineddata"
//Notar que si bien los autores nos proporcionan el script original, no se corren estas líneas porque la dta ya viene combinada 
//merge 1:1 msa year using "../data/cpi_rent/cpi_rent"


// preserve
// clear all
// freduse CPALTT01USA661S
//
// gen year=year(daten)
// gen logcpi=log(CPALTT)
// replace logcpi=logcpi-4.285695
// keep year logcpi
// tempfile cpi
// save `cpi'
// restore
//
// merge m:1 year using `cpi', nogen

//Panel de datos. Recordar que el análisis se realiza por unidad espacial de MSA (área metropolitana)
xtset msa year


replace logrentcpi=logrentcpi-logcpi
//logNOI = rents after doing the Empirical Bayes adjustment
//Se realiza scatter entre el cambio en LOG CPI rents contra el cambio en rentas "crudo" y contra el cambio en rentas ajustado.
//No se grafican de manera aislada sino en conjunto. Notar que solo se realiza para 2017 y se omiten todos los missing values de 
//variables distintas a s17.logrentcpi 

//Preparación para Figura B1

//AD- Para ambos casos, en el paper los símbolos aparecen desproporcionados en la salida final, para mejorar este aspecto, se cambia el tamaño de los mismos en msym

//Cambio en rentas ajustado
scatter s17.lognoi_adj s17.logrentcpi if year==2017 & s17.logrentcpi!=. [w=pop], msym(oh) || line s17.logrentcpi s17.logrentcpi, ///
	legend(off) ytitle("Log NOI Change") xtitle("Log CPI Rents Change") name(rent_raw) nodraw

//Cambio en rentas sin ajustar
scatter rent_new s17.logrentcpi if year==2017 & s17.logrentcpi!=. [w=pop], msym(oh) || line s17.logrentcpi s17.logrentcpi, ///
	legend(off) ytitle("Rent Change") xtitle("Log CPI Rents Change") name(rent) nodraw
graph combine rent rent_raw
graph export "../exhibits/cpi_comparison.pdf", as(pdf) replace

//Preparación para Figura B2
gen slognoi=s.lognoi_adj
gen slogrentcpi=s.logrentcpi

collapse (mean) slognoi slogrentcpi [w=pop], by(year)
//Fluctuaciones anuales para todo año después de 1999, diferenciando entre cambio en rentas ajustado y cambio en rentas sin ajustar	
line slognoi slogrentcpi year if year>1999, lpattern(solid dash) legend(label( 1 "NOI") label(2 "CPI Rent")) ytitle("Log-Point Change")

graph export "../exhibits/cpi_comparison_time.pdf", as(pdf) replace
