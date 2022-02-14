
clear all
use "../data/combineddata"
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

xtset msa year


replace logrentcpi=logrentcpi-logcpi


scatter s17.lognoi_adj s17.logrentcpi if year==2017 & s17.logrentcpi!=. [w=pop], msym(Oh) || line s17.logrentcpi s17.logrentcpi, ///
	legend(off) ytitle("Log NOI Change") xtitle("Log CPI Rents Change") name(rent_raw) nodraw

scatter rent_new s17.logrentcpi if year==2017 & s17.logrentcpi!=. [w=pop], msym(Oh) || line s17.logrentcpi s17.logrentcpi, ///
	legend(off) ytitle("Rent Change") xtitle("Log CPI Rents Change") name(rent) nodraw
graph combine rent rent_raw
graph export "../exhibits/cpi_comparison.pdf", as(pdf) replace


gen slognoi=s.lognoi_adj
gen slogrentcpi=s.logrentcpi

collapse (mean) slognoi slogrentcpi [w=pop], by(year)
	
line slognoi slogrentcpi year if year>1999, lpattern(solid dash) legend(label( 1 "NOI") label(2 "CPI Rent")) ytitle("Log-Point Change")

graph export "../exhibits/cpi_comparison_time.pdf", as(pdf) replace
