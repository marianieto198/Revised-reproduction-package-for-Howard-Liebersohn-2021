/*
Author(s): Greg Howard & Jack Liebersohn
Date:2021

Description: Script para realizar la figura B3
*/

//En este caso se usa el rent index creado por los propios autores
//use "data\rent_index_msa00.dta" , clear

//use "data\rent_index_msa00.dta" , clear
use "../data/rent_index_msa00_2001.dta" , clear
//drop if freq==0

//replace stderr=10 if stderr<.0001

//Los autores utilizan la unidad espacial de MSA (área metropolitana) en lugar de ciudades aisladas
rename city msa

//Merge con combineddata, que es el dta mas completo de este paquete
merge 1:1 msa year using "../data/combineddata"

//Panel de datos
xtset msa year
//Notar que los autores generan nuevas variables en lugar de renombrar las antiguas, 
//ya que estas variables vuelven a ser usadas en distintos dofiles a lo largo del paper
gen rent=fs18.lognoi
gen hp=s17.loghpi

//stderr - standard error of parameter estimate 
replace stderr=f.stderr
//missing value para renta si stderr tiende a cero
replace rent=. if stderr<.00001

//Año 2017 - último año del análisis
keep if year==2017
keep msa rent hp stderr freq
//Mantienen: área metropolitana, renta, house price, standard error y frequency

//Se corre regresión lineal de house price contra renta (positiva). Se predicen los valores en rhat 
reg rent hp
predict rhat
predict resid, r
summ resid, detail
//Predict residuals after regressing

local var_resid=r(sd)^2
disp `var_resid'

//Error estándar al cuadrado
gen var_rent=stderr^2

summ var_rent
local var_rent=r(mean)

//Varianza de los residuales 
local var_rhat=`var_resid'-`var_rent'


if `var_rhat'<0{
	disp "Problem: Variance of rhat is less than zero!"
	stop
}

//Proposición 15 - anexo
gen rent_new=(rent/var_rent+rhat/`var_rhat')/(1/var_rent+1/`var_rhat')
//Para el histograma que se va a sacar después
gen weight=1/var_rent/(1/var_rent+1/`var_rhat')

gen rent_change=rent_new-rent
disp `var_rhat'
summ var_rent


//Se deshacen de los valores cuando el cambio en el logaritmo de renta, ya ajustado por método bayesiano, es missing value. 
gen scatter_weight=1/var_rent
replace scatter_weight=. if rent_new==.

//Preparación para salida
//graph rename histogram, replace
//plot with spikes = cambio en renta ajustada, cambio en renta, house price. Scatter de las mismas variables 

twoway rspike rent_new rent hp , lcolor(dkgreen)  ||  scatter rent rent_new hp, msym(square) ///
	mcolor(dkgreen orange_red) ytitle("Rent Change 2000-2018") xtitle("House Price Change 2000-2017") ///
	legend(label(2 "Rent index based on Trepp data alone") label(3 "Post-empirical-Bayes rent index") col(1) order(2 3))
graph export "../exhibits/empirical_bayes_shrinkage.pdf", as(pdf) replace

//Histograma
hist weight, start(0) width(.05) xtitle("Weight on Trepp Rent Index") frac ytitle("Share in Bin (width=.05)")
graph export "../exhibits/empirical_bayes_histogram.pdf", as(pdf) replace

//Cuando hay missing value en el cambio de la renta, se reemplaza por los valores predichos anteriormente.
replace rent_new=rhat if rent==.
summ weight, detail

keep rent_new msa
//save "../data\rent_empirical_bayes.dta", replace


