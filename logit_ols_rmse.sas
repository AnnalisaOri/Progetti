
/* PROV*/
/* LOGIT + OLS, con variabili già selezionate */


proc import
    datafile="C:\Users\aori004\Desktop\Letteratura\Output SAS\model_data.xlsx"
    out=model_data
    dbms=xlsx
    replace;
    sheet="model_data";
    getnames=yes;
run;




/* retail */
proc reg data=model_data;
    model lgd_retail_logit =
          d_euribor_l2
          d_oil_l2
          d_btp_l7
          dummy_covid
		  
          / vif;
		  output out=pred_logit_retail
p=logit_hat_retail
r=resid_logit_retail;
run;
quit;
/* R^2 adj = 51.70, 3 sign, controllati */



/* senza BTP */
proc reg data=model_data;
    model lgd_retail_logit =
          d_euribor_l2
          d_oil_l2
          
          dummy_covid
		  
          / vif;
run;
quit;
/* riporto in tesi R^2 che senza BTP è + basso */




data pred_logit_retail;
    set pred_logit_retail;

    lgd_retail_hat =
         exp(logit_hat_retail)
         /(1+exp(logit_hat_retail));

    err_ret     = lgd_retail - lgd_retail_hat;
    abs_err_ret = abs(err_ret);
    sq_err_ret  = err_ret**2;
run;
proc means data=pred_logit_retail noprint;
    var abs_err_ret sq_err_ret;

    output out=metrics_ret
        mean(abs_err_ret)=mae
        mean(sq_err_ret)=mse;
run;

data metrics_ret;
    set metrics_ret;

    rmse = sqrt(mse);
run;

proc print data=metrics_ret;
run;

ods listing gpath="C:\Users\aori004\Desktop\Letteratura\Grafici Residui Logit";

ods graphics / reset
               imagename="QQPlot_Retail_Residuals"
               imagefmt=png
               width=6in
               height=5in;

proc univariate data=pred_logit_retail normal;

    var resid_logit_retail;

    histogram resid_logit_retail / normal;

    qqplot resid_logit_retail /
           normal(mu=est sigma=est);

run;


ods listing gpath="C:\Users\aori004\Desktop\Letteratura\Grafici Residui Logit";

ods graphics / reset
               imagename="Retail_ACF_PACF"
               imagefmt=png;


proc arima data=pred_logit_retail plots(unpack)=all;
    identify var=resid_logit_retail
             nlag=8;
run;








proc arima data=pred_logit_retail;
    identify var=resid_logit_retail stationarity=(adf=(0,1,2,3));
run;
quit;


proc arima data=model_data;

    identify var=lgd_retail_logit
             stationarity=(adf=(0,1,2,3));

run;
quit;


ods listing gpath="C:\Users\aori004\Desktop\Letteratura\Grafici MSE";

ods graphics / reset
               imagename="Retail_Observed_vs_Fitted"
               imagefmt=png
               width=8in
               height=5in;

proc sgplot data=pred_logit_retail;

    series x=date_sas y=lgd_retail /
        lineattrs=(thickness=2)
        legendlabel="Observed LGD";

    series x=date_sas y=lgd_retail_hat /
        lineattrs=(pattern=dash thickness=2)
        legendlabel="Fitted LGD";

    xaxis label="Quarter";
    yaxis label="LGD";

run;







/* corporate */
proc reg data=model_data;
    model lgd_corp_logit =
          d_euribor_l2
          d_oil_l2
          d_btp_l7
          dummy_covid
          / vif;

    output out=pred_logit_corp
           p=logit_hat_corp
r=resid_logit_corp;
run;
quit;

/* corporate senza btp */

proc reg data=model_data;
    model lgd_corp_logit =
          d_euribor_l2
          d_oil_l2
          
          dummy_covid
          / vif;

run;
quit;


data pred_logit_corp;
    set pred_logit_corp;

    lgd_corp_hat =
         exp(logit_hat_corp) /
         (1+exp(logit_hat_corp));

    err_corp     = lgd_corporate - lgd_corp_hat;
    abs_err_corp = abs(err_corp);
    sq_err_corp  = err_corp**2;
run;

proc means data=pred_logit_corp noprint;
    var abs_err_corp sq_err_corp;

    output out=metrics_corp
        mean(abs_err_corp)=mae
        mean(sq_err_corp)=mse;
run;

data metrics_corp;
    set metrics_corp;

    rmse = sqrt(mse);
run;

proc print data=metrics_corp;
run;

ods listing gpath="C:\Users\aori004\Desktop\Letteratura\Grafici Residui Logit";

ods graphics / reset
               imagename="QQPlot_Corporate_Residuals"
               imagefmt=png
               width=6in
               height=5in;
proc univariate data=pred_logit_corp normal;

    var resid_logit_corp;

    histogram resid_logit_corp / normal;

    qqplot resid_logit_corp /
           normal(mu=est sigma=est);

run;



ods listing gpath="C:\Users\aori004\Desktop\Letteratura\Grafici Residui Logit";

ods graphics / reset
               imagename="Corporate_ACF_PACF"
               imagefmt=png;

proc arima data=pred_logit_corp plots(unpack)=all;
   identify var=resid_logit_corp nlag=8;
run;
quit;

proc arima data=pred_logit_corp;
    identify var=resid_logit_corp stationarity=(adf=(0,1,2,3));
run;
quit;



ods listing gpath="C:\Users\aori004\Desktop\Letteratura\Grafici MSE";

ods graphics / reset
               imagename="Corporate_Observed_vs_Fitted"
               imagefmt=png
               width=8in
               height=5in;

proc sgplot data=pred_logit_corp;

    series x=date_sas y=lgd_corporate /
        lineattrs=(thickness=2)
        legendlabel="Observed LGD";

    series x=date_sas y=lgd_corp_hat /
        lineattrs=(pattern=dash thickness=2)
        legendlabel="Fitted LGD";

    xaxis label="Quarter";
    yaxis label="LGD";

run;







/* institutions */
proc reg data=model_data;
    model lgd_inst_logit =
          d_euribor_l2
          d_oil_l2
          d_btp_l7
          dummy_covid
          / vif;

    output out=pred_logit_inst
           p=logit_hat_inst
r=resid_logit_inst;
run;
quit;


/* institutions senza btp */
proc reg data=model_data;
    model lgd_inst_logit =
          d_euribor_l2
          d_oil_l2
          
          dummy_covid
          / vif;

run;



data pred_logit_inst;
    set pred_logit_inst;

    lgd_inst_hat =
         exp(logit_hat_inst) /
         (1+exp(logit_hat_inst));

    err_inst    = lgd_institutions - lgd_inst_hat;
    abs_err_inst = abs(err_inst);
    sq_err_inst  = err_inst**2;
run;


proc means data=pred_logit_inst noprint;
    var abs_err_inst sq_err_inst;

    output out=metrics_inst
        mean(abs_err_inst)=mae
        mean(sq_err_inst)=mse;
run;

data metrics_inst;
    set metrics_inst;

    rmse = sqrt(mse);
run;

proc print data=metrics_inst;
run;


ods listing gpath="C:\Users\aori004\Desktop\Letteratura\Grafici Residui Logit";

ods graphics / reset
               imagename="QQPlot_Institutions_Residuals"
               imagefmt=png
               width=6in
               height=5in;
proc univariate data=pred_logit_inst normal;

    var resid_logit_inst;

    histogram resid_logit_inst / normal;

    qqplot resid_logit_inst /
           normal(mu=est sigma=est);

run;



ods listing gpath="C:\Users\aori004\Desktop\Letteratura\Grafici Residui Logit";

ods graphics / reset
               imagename="Institutions_ACF_PACF"
               imagefmt=png;


proc arima data=pred_logit_inst plots(unpack)=all;
    identify var=resid_logit_inst
             nlag=8;
run;



proc arima data=pred_logit_inst;
    identify var=resid_logit_inst stationarity=(adf=(0,1,2,3));
run;
quit;


ods listing gpath="C:\Users\aori004\Desktop\Letteratura\Grafici MSE";

ods graphics / reset
               imagename="Institutions_Observed_vs_Fitted"
               imagefmt=png
               width=8in
               height=5in;

proc sgplot data=pred_logit_inst;

    series x=date_sas y=lgd_institutions /
        lineattrs=(thickness=2)
        legendlabel="Observed LGD";

    series x=date_sas y=lgd_inst_hat /
        lineattrs=(pattern=dash thickness=2)
        legendlabel="Fitted LGD";

    xaxis label="Quarter";
    yaxis label="LGD";

run;







/* pmi */
proc reg data=model_data;
    model lgd_pmi_logit =
          d_euribor_l2
          d_oil_l2
          d_btp_l7
          dummy_covid
          / vif;

    output out=pred_logit_pmi
           p=logit_hat_pmi

r=resid_logit_pmi;
run;
quit;

/* pmi senza btp */
proc reg data=model_data;
    model lgd_pmi_logit =
          d_euribor_l2
          d_oil_l2
          
          dummy_covid
          / vif;

run;





data pred_logit_pmi;
    set pred_logit_pmi;

    lgd_pmi_hat =
         exp(logit_hat_pmi) /
         (1+exp(logit_hat_pmi));

    err_pmi    = lgd_pmi - lgd_pmi_hat;
    abs_err_pmi = abs(err_pmi);
    sq_err_pmi  = err_pmi**2;
run;


proc means data=pred_logit_pmi noprint;
    var abs_err_pmi sq_err_pmi;

    output out=metrics_pmi
        mean(abs_err_pmi)=mae
        mean(sq_err_pmi)=mse;
run;

data metrics_pmi;
    set metrics_pmi;

    rmse = sqrt(mse);
run;

proc print data=metrics_pmi;
run;


ods listing gpath="C:\Users\aori004\Desktop\Letteratura\Grafici Residui Logit";

ods graphics / reset
               imagename="QQPlot_SME_Residuals"
               imagefmt=png
               width=6in
               height=5in;
proc univariate data=pred_logit_pmi normal;

    var resid_logit_pmi;

    histogram resid_logit_pmi / normal;

    qqplot resid_logit_pmi /
           normal(mu=est sigma=est);

run;



ods listing gpath="C:\Users\aori004\Desktop\Letteratura\Grafici Residui Logit";

ods graphics / reset
               imagename="SME_ACF_PACF"
               imagefmt=png;


proc arima data=pred_logit_pmi plots(unpack)=all;
    identify var=resid_logit_pmi
             nlag=8;
run;



proc arima data=pred_logit_pmi;
    identify var=resid_logit_pmi stationarity=(adf=(0,1,2,3));
run;
quit;


ods listing gpath="C:\Users\aori004\Desktop\Letteratura\Grafici MSE";

ods graphics / reset
               imagename="PMI_Observed_vs_Fitted"
               imagefmt=png
               width=8in
               height=5in;

proc sgplot data=pred_logit_pmi;

    series x=date_sas y=lgd_pmi /
        lineattrs=(thickness=2)
        legendlabel="Observed LGD";

    series x=date_sas y=lgd_pmi_hat /
        lineattrs=(pattern=dash thickness=2)
        legendlabel="Fitted LGD";

    xaxis label="Quarter";
    yaxis label="LGD";

run;











/*differenze logit e beta, da runnare prima codice di beta */
data confronto_retail;

    merge pred_logit_retail(keep=date_sas lgd_retail_hat)
          pred_beta_ret(keep=date_sas lgd_hat);

    by date_sas;

    diff = lgd_retail_hat - lgd_hat;
    abs_diff = abs(diff);

run;


data confronto_pmi;

    merge pred_logit_pmi(keep=date_sas lgd_pmi_hat)
          pred_beta_pmi(keep=date_sas lgd_hat);

    by date_sas;

    diff = lgd_pmi_hat - lgd_hat;
    abs_diff = abs(diff);

run;

data confronto_corp;

    merge pred_logit_corp(keep=date_sas lgd_corp_hat)
          pred_beta_corp(keep=date_sas lgd_hat);

    by date_sas;

    diff = lgd_corp_hat - lgd_hat;
    abs_diff = abs(diff);

run;

data confronto_inst;

    merge pred_logit_inst(keep=date_sas lgd_inst_hat)
          pred_beta_inst(keep=date_sas lgd_hat);

    by date_sas;

    diff = lgd_inst_hat - lgd_hat;
    abs_diff = abs(diff);

run;



/* prova per la scelta dei regressori con net*/

/* retail */
proc glmselect data=model_data seed=12345 plots=all;

    model lgd_retail_logit =

        d_def d_def_l1-d_def_l8

        d_unemp d_unemp_l1-d_unemp_l8

        d_oil d_oil_l1-d_oil_l8

        d_euribor d_euribor_l1-d_euribor_l8

        d_btp d_btp_l1-d_btp_l8


        d_pilita dpil_ita_l1-dpil_ita_l8

        d_pilue dpil_ue_l1-dpil_ue_l8

        dummy_covid

		  / selection=elasticnet(rho=0.5 choose=cv stop=none);


run;

proc glmselect data=model_data seed=12345 plots=all;

    model lgd_retail_logit =

        d_def d_def_l1-d_def_l8
        d_unemp d_unemp_l1-d_unemp_l8
        d_oil d_oil_l1-d_oil_l8
        d_euribor d_euribor_l1-d_euribor_l8
        d_btp d_btp_l1-d_btp_l8
        d_pilita dpil_ita_l1-dpil_ita_l8
        d_pilue dpil_ue_l1-dpil_ue_l8
        dummy_covid

        / selection=lasso
          (choose=cv stop=none);

run;


/* pmi */
proc glmselect data=model_data plots=all;

    model lgd_pmi_logit =

        d_def d_def_l1-d_def_l8

        d_unemp d_unemp_l1-d_unemp_l8

        d_oil d_oil_l1-d_oil_l8

        d_euribor d_euribor_l1-d_euribor_l8

        d_btp d_btp_l1-d_btp_l8

        d_pilita dpil_ita_l1-dpil_ita_l8

        d_pilue dpil_ue_l1-dpil_ue_l8

        dummy_covid

        / selection=elasticnet
          (choose=cv stop=none);

run;

proc glmselect data=model_data seed=12345 plots=all;

    model lgd_pmi_logit =

        d_def d_def_l1-d_def_l8
        d_unemp d_unemp_l1-d_unemp_l8
        d_oil d_oil_l1-d_oil_l8
        d_euribor d_euribor_l1-d_euribor_l8
        d_btp d_btp_l1-d_btp_l8
        d_pilita dpil_ita_l1-dpil_ita_l8
        d_pilue dpil_ue_l1-dpil_ue_l8
        dummy_covid

        / selection=lasso
          (choose=cv stop=none);

run;




/* corporate */
proc glmselect data=model_data plots=all;

    model lgd_corp_logit =

        d_def d_def_l1-d_def_l8

        d_unemp d_unemp_l1-d_unemp_l8

        d_oil d_oil_l1-d_oil_l8

        d_euribor d_euribor_l1-d_euribor_l8

        d_btp d_btp_l1-d_btp_l8

        d_pilita dpil_ita_l1-dpil_ita_l8

        d_pilue dpil_ue_l1-dpil_ue_l8

        dummy_covid

        / selection=elasticnet
          (choose=cv stop=none);

run;

proc glmselect data=model_data seed=12345 plots=all;

    model lgd_corp_logit =

        d_def d_def_l1-d_def_l8
        d_unemp d_unemp_l1-d_unemp_l8
        d_oil d_oil_l1-d_oil_l8
        d_euribor d_euribor_l1-d_euribor_l8
        d_btp d_btp_l1-d_btp_l8
        d_pilita dpil_ita_l1-dpil_ita_l8
        d_pilue dpil_ue_l1-dpil_ue_l8
        dummy_covid

        / selection=lasso
          (choose=cv stop=none);

run;



/* institutions */
proc glmselect data=model_data plots=all;

    model lgd_inst_logit =

        d_def d_def_l1-d_def_l8

        d_unemp d_unemp_l1-d_unemp_l8

        d_oil d_oil_l1-d_oil_l8

        d_euribor d_euribor_l1-d_euribor_l8

        d_btp d_btp_l1-d_btp_l8

        d_pilita dpil_ita_l1-dpil_ita_l8

        d_pilue dpil_ue_l1-dpil_ue_l8

        dummy_covid

        / selection=elasticnet
          (choose=cv stop=none);

run;

proc glmselect data=model_data seed=12345 plots=all;

    model lgd_inst_logit =

        d_def d_def_l1-d_def_l8
        d_unemp d_unemp_l1-d_unemp_l8
        d_oil d_oil_l1-d_oil_l8
        d_euribor d_euribor_l1-d_euribor_l8
        d_btp d_btp_l1-d_btp_l8
        
        d_pilita dpil_ita_l1-dpil_ita_l8
        d_pilue dpil_ue_l1-dpil_ue_l8
        dummy_covid

        / selection=lasso
          (choose=cv stop=none);

run;
