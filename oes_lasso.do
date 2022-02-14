clear all
use "../data/combineddata"
gen epop_change=f18s18.epop if year==2000
xtset msa year
*gen rentchange=f18s18.lognoi if year==2000
gen rentchange=rent_new if year==2000
//merge m:1 msa using "../data/amenities_measures/amen_index_all", keep(1 3) nogen
keep if year==2000
//keep msa rentchange elasticity pop amen_index wageshock wageshock_college wageshock_level dsoi_income dsoi_income_level  epop_change school crime retail road environment jobs jantemp

replace elasticity=5.35 if msa==9999

local amenityvars="school crime retail road environment jobs jantemp"
local empvars="wageshock wageshock_college wageshock_level dsoi_income dsoi_income_level  epop_change  a_* h_*"

local allvars="`amenityvars' `empvars'"



file open table_lasso using "../exhibits/table_lasso.tex", write replace


file write table_lasso "\begin{tabular}{llccc}" _n
file write table_lasso "\hline \hline" _n
file write table_lasso "& & (1) & (2) & (3) \\ " _n
file write table_lasso " &  & Number of &  \$R^2 \$ of & Percent of Location \\" _n
file write table_lasso "Variables & Method & Regressors&rent changes & Channel Explained \\" _n
file write table_lasso "\hline" _n
file write table_lasso "\\" _n



corr elasticity rentchange [w=pop], cov
local denom=r(cov_12)
disp `denom'

foreach xxx in amenityvars empvars allvars{
	local varset="``xxx''"
	
	file write table_lasso "&  Principal Component &  1 & " 

	pca `varset' if rentchange!=.
	cap drop pca1
	predict pca1
	reg rentchange pca1 [w=pop]
	local myr2=e(r2)
	file write table_lasso %6.2f (`myr2') " &"
	cap drop shock_index
	predict shock_index
	corr shock_index elasticity [w=pop] if rentchange!=., cov
	local numer=r(cov_12)
	disp `numer'
	local contrib=`numer'/`denom'
	file write table_lasso %6.2f (`contrib') 
	file write table_lasso " \\" _n 
	
	
	
	if "`xxx'"=="amenityvars" file write table_lasso "Amenities & "
	if "`xxx'"=="empvars" file write table_lasso "Wages & "
	if "`xxx'"=="allvars" file write table_lasso "Both & "
	
		
	lassoregress rentchange `varset' [w=pop]
	local lasso_`xxx'=e(varlist_nonzero)
	
	reg rentchange `=e(varlist_nonzero)' [w=pop]

	local myr2=e(r2)
	mat myb=e(b)
	local myN=colsof(myb)-1
	file write table_lasso "LASSO & `myN' & "
	file write table_lasso %6.2f (`myr2') "&"
	cap drop shock_lasso
	predict shock_lasso
	corr shock_lasso elasticity [w=pop] if rentchange!=., cov
	local numer=r(cov_12)
	local contrib=`numer'/`denom'
	file write table_lasso %6.2f (`contrib') " \\" _n

	
	reg rentchange `varset' [w=pop]
	local myr2=e(r2)
	mat myb=e(b)
	local myN=colsof(myb)-1
	file write table_lasso "& OLS & `myN' &" %6.2f ( `myr2') " &"
	cap drop shock_ols
	predict shock_ols
	corr shock_ols elasticity [w=pop] if rentchange!=., cov
	local numer=r(cov_12)
	disp `numer'
	local contrib=`numer'/`denom'
	disp `contrib'
	file write table_lasso %6.2f (`contrib') "\\ " _n
	file write table_lasso " \\ " _n
}


file write table_lasso "\hline \hline" _n "\end{tabular}" _n _n



file close table_lasso


//
//
// pca `amenityvars' if rentchange!=.
// predict pca_amen
//
// reg rentchange pca_amen [w=pop]
// predict shock_amen_index
//
//
// corr shock_amen_index elasticity [w=pop], cov
// local cov_pca_amen=r(cov_12)
// disp `cov_pca_amen'
// disp `denom'
// local contrib_pca_amen=`cov_pca_amen'/`denom'
// local r2_pca_amen=e(r2)
// local num_pca_amen=e(df_m)
//
//
//
// pca `empvars' if rentchange!=.
// predict emp_index
//
// reg rentchange emp_index [w=pop]
// predict shock_wage_growth
//
//
//
//
// pca `empvars' `amenityvars' if rentchange!=.
// predict both_index
//
// reg rentchange both_index [w=pop]
// predict shock_both_growth
//
//
// reg rentchange `amenityvars' [w=pop]
// predict shock_amenity
//
// lassoregress rentchange `amenityvars' [w=pop]
// reg rentchange `=e(varlist_nonzero)' [w=pop]
// predict shock_lasso_amenity
// reg rentchange `empvars' [w=pop]
// predict shock_emp
//
// lassoregress rentchange `empvars' [w=pop]
// reg rentchange `=e(varlist_nonzero)' [w=pop]
// predict shock_lasso_emp
//
// reg rentchange `amenityvars' `empvars' [w=pop]
// predict shock_both
//
// lassoregress rentchange  `empvars' `amenityvars' [w=pop]
// reg rentchange `=e(varlist_nonzero)' [w=pop]
// predict shock_lasso
//
// corr elasticity shock_* rentchange [w=pop], cov
//
//
//
//



//
// log close


pca `amenityvars'
predict pca_amen

pca `empvars'
predict emp_index


xtile elasticitybin= elasticity [w=pop] if rentchange!=., n(6) 

preserve
collapse (mean) pca_amen  emp_index elasticity [w=pop], by(elasticitybin)

rename pca_amen amen_mean
rename emp_index emp_mean
rename elasticity elasticity_mean
tempfile bins
save `bins'
restore
merge m:1 elasticitybin using `bins', nogen

gsort elasticity
drop if elasticitybin==. 



scatter pca_amen elasticity [w=pop] if  elasticity<10, msym(Oh) msize(1) || ///
	scatter amen_mean elasticity_mean, ///
	msize(2) c(l) yline(0, lcolor(gs8)) yscale(range(-.5 1)) ///
	ytitle("Amenities, 1st Principal Component") legend(off) name(rents, replace)

graph export "../exhibits/binscatter_amenity_pc.pdf", as(pdf) replace

scatter emp_index elasticity [w=pop] if  elasticity<10, msym(Oh) msize(1) || ///
	scatter amen_mean elasticity_mean, ///
	msize(2) c(l) yline(0, lcolor(gs8)) yscale(range(-.5 1))  ///
	ytitle("Wages, 1st Principal Component") legend(off) name(wages, replace)


graph export "../exhibits/binscatter_wages_pc.pdf", as(pdf) replace

