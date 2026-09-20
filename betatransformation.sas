

proc import
    datafile="C:\Users\aori004\Desktop\Letteratura\Output SAS\model_data.xlsx"
    out=model_data
    dbms=xlsx
    replace;
    sheet="model_data";
    getnames=yes;
run;

/* come nel paper */
proc univariate data=model_data;
   var lgd_retail;
   histogram lgd_retail / beta;
run;
proc means data=model_data noprint;
    var lgd_retail;
    output out=stats_ret
        mean=m_ret
        var=v_ret;
run;
data params_ret;
    set stats_ret;

    phi_ret   = m_ret*(1-m_ret)/v_ret - 1;

    alpha_ret = m_ret*phi_ret;
    beta_ret  = (1-m_ret)*phi_ret;
run;

data beta_tr_ret;
    if _n_=1 then set params_ret;

    set model_data;

    p = cdf('BETA', lgd_retail, alpha_ret, beta_ret);

    /* evita p=0 o p=1 */
    if p<0.000001 then p=0.000001;
    if p>0.999999 then p=0.999999;

    beta_norm = quantile('NORMAL',p);
run;


ods listing gpath="C:\Users\aori004\Desktop\Letteratura\Grafici Beta";
ods graphics on;
ods graphics / reset
imagename="Retail_Beta_QQPlot"
imagefmt=png
width=6in
height=5in;

proc univariate data=beta_tr_ret normal;

var beta_norm;

histogram beta_norm / normal;

qqplot beta_norm / normal(mu=est sigma=est);

run;


proc reg data=beta_tr_ret;

model beta_norm =
      d_euribor_l2
      d_oil_l2
      d_btp_l7
      dummy_covid;

output out=pred_beta_ret
       p=z_hat
r=resid_beta_ret;
run;
quit;

data pred_beta_ret;

    if _n_=1 then set params_ret;

    set pred_beta_ret;

    p_hat = cdf('NORMAL', z_hat);

    lgd_hat =
        quantile('BETA',
                 p_hat,
                 alpha_ret,
                 beta_ret);

run;
data pred_beta_ret;

    set pred_beta_ret;

    err_rat  = lgd_retail - lgd_hat;
    aerr_rat = abs(err_rat);
    sqerr_rat = err_rat**2;

run;

proc sql;

create table metrics_ret as

select
    mean(aerr_rat)                as MAE,
    mean(sqerr_rat)               as MSE,
    sqrt(mean(sqerr_rat))         as RMSE

from pred_beta_ret;

quit;

proc print data=metrics_ret;
run;

/* analisi residui */

ods listing gpath="C:\Users\aori004\Desktop\Letteratura\Grafici Beta";
ods graphics on;
ods graphics / reset
imagename="Retail_Beta_Residual_QQPlot"
imagefmt=png;
proc univariate data=pred_beta_ret normal;

    var resid_beta_ret;

    histogram resid_beta_ret / normal;

    qqplot resid_beta_ret /
           normal(mu=est sigma=est);

run;
ods listing gpath="C:\Users\aori004\Desktop\Letteratura\Grafici Beta";

ods graphics on;

ods graphics / reset

imagename="Retail_Beta_ACF_PACF"

imagefmt=png;
proc arima data=pred_beta_ret plots(unpack)=all;

    identify var=resid_beta_ret
             nlag=8;

run;
quit;

proc arima data=pred_beta_ret;

    identify var=resid_beta_ret
             stationarity=(adf=(0));

run;
quit;

ods listing gpath="C:\Users\aori004\Desktop\Letteratura\Grafici MSE";

ods graphics / reset
               imagename="Retail_Beta_Observed_vs_Fitted"
               imagefmt=png
               width=8in
               height=5in;

proc sgplot data=pred_beta_ret;

    series x=date_sas y=lgd_retail /
        lineattrs=(thickness=2 color=blue)
        legendlabel="Observed LGD";

    series x=date_sas y=lgd_hat /
        lineattrs=(pattern=shortdash thickness=2 color=red)
        legendlabel="Fitted LGD";

    xaxis label="Quarter";
    yaxis label="LGD";

run;




/* prova grafico */
data beta_tr_ret;

set beta_tr_ret;

Retail_Beta_Transform = beta_norm;

run;

ods listing gpath="C:\Users\aori004\Desktop\Letteratura\Grafici_beta";

ods graphics / reset
               imagename="Retail_Beta_Histogram"
               imagefmt=png
               width=6in
               height=4in;
			   title "Retail Portfolio - Distribution of Beta-Transformed LGD";

proc univariate data=beta_tr_ret normal;
    var Retail_Beta_Transform;

    histogram Retail_Beta_Transform / normal;
run;




/* pmi */

proc univariate data=model_data;
   var lgd_pmi;
   histogram lgd_pmi / beta;
run;
proc means data=model_data noprint;
    var lgd_pmi;
    output out=stats_pmi
        mean=m_pmi
        var=v_pmi;
run;
data params_pmi;
    set stats_pmi;

    phi_pmi   = m_pmi*(1-m_pmi)/v_pmi - 1;

    alpha_pmi = m_pmi*phi_pmi;
    beta_pmi  = (1-m_pmi)*phi_pmi;
run;

data beta_tr_pmi;
    if _n_=1 then set params_pmi;

    set model_data;

    p = cdf('BETA', lgd_pmi, alpha_pmi, beta_pmi);

    /* evita p=0 o p=1 */
    if p<0.000001 then p=0.000001;
    if p>0.999999 then p=0.999999;

    beta_norm = quantile('NORMAL',p);
run;

ods listing gpath="C:\Users\aori004\Desktop\Letteratura\Grafici Beta";
ods graphics on;
ods graphics / reset
imagename="SME_Beta_QQPlot"
imagefmt=png
width=6in
height=5in;

proc univariate data=beta_tr_pmi normal;

var beta_norm;

histogram beta_norm / normal;

qqplot beta_norm / normal(mu=est sigma=est);

run;
proc reg data=beta_tr_pmi;

model beta_norm =
      d_euribor_l2
      d_oil_l2
      d_btp_l7
      dummy_covid;

output out=pred_beta_pmi
       p=z_hat
r=resid_beta_pmi;
run;
quit;
/* Normalità dei residui Beta-OLS PMI */

proc univariate data=pred_beta_pmi normal;

    var resid_beta_pmi;

    histogram resid_beta_pmi / normal;

    qqplot resid_beta_pmi /
           normal(mu=est sigma=est);

run;
data pred_beta_pmi;

    if _n_=1 then set params_pmi;

    set pred_beta_pmi;

    p_hat = cdf('NORMAL', z_hat);

    lgd_hat =
        quantile('BETA',
                 p_hat,
                 alpha_pmi,
                 beta_pmi);

run;
data pred_beta_pmi;

    set pred_beta_pmi;

    err_pmi  = lgd_pmi - lgd_hat;
    aerr_pmi = abs(err_pmi);
    sqerr_pmi = err_pmi**2;

run;

proc sql;

create table metrics_pmi as

select
    mean(aerr_pmi)                as MAE,
    mean(sqerr_pmi)               as MSE,
    sqrt(mean(sqerr_pmi))         as RMSE

from pred_beta_pmi;

quit;

proc print data=metrics_pmi;
run;

proc arima data=pred_beta_pmi;

    identify var=resid_beta_pmi
             stationarity=(adf=(0));

run;
quit;

ods listing gpath="C:\Users\aori004\Desktop\Letteratura\Grafici MSE";

ods graphics / reset
               imagename="PMI_Beta_Observed_vs_Fitted"
               imagefmt=png
               width=8in
               height=5in;

proc sgplot data=pred_beta_pmi;

    series x=date_sas y=lgd_pmi /
        lineattrs=(thickness=2 color=blue)
        legendlabel="Observed LGD";

    series x=date_sas y=lgd_hat /
        lineattrs=(pattern=shortdash thickness=2 color=red)
        legendlabel="Fitted LGD";

    xaxis label="Quarter";
    yaxis label="LGD";

run;



ods listing gpath="C:\Users\aori004\Desktop\Letteratura\Grafici Beta";

ods graphics on;

ods graphics / reset

imagename="PMI_Beta_ACF_PACF"

imagefmt=png;
proc arima data=pred_beta_pmi plots(unpack)=all;

    identify var=resid_beta_pmi
             nlag=8;

run;
quit;

/* grafico */
data beta_tr_pmi;
    set beta_tr_pmi;

    SME_Beta_Transform = beta_norm;
run;

ods listing gpath="C:\Users\aori004\Desktop\Letteratura\Grafici_Beta";

ods graphics / reset
               imagename="SME_Beta_Distribution"
               imagefmt=png
               width=6in
               height=4in;

title "SME Portfolio - Distribution of Beta-Transformed LGD";

proc univariate data=beta_tr_pmi normal;
    var SME_Beta_Transform;

    histogram SME_Beta_Transform / normal;
run;

title;










/* corporate */

proc univariate data=model_data;
   var lgd_corporate;
   histogram lgd_corporate / beta;
run;
proc means data=model_data noprint;
    var lgd_corporate;
    output out=stats_corp
        mean=m_corp
        var=v_corp;
run;
data params_corp;
    set stats_corp;

    phi_corp   = m_corp*(1-m_corp)/v_corp - 1;

    alpha_corp = m_corp*phi_corp;
    beta_corp  = (1-m_corp)*phi_corp;
run;

data beta_tr_corp;
    if _n_=1 then set params_corp;

    set model_data;

    p = cdf('BETA', lgd_corporate, alpha_corp, beta_corp);

    /* evita p=0 o p=1 */
    if p<0.000001 then p=0.000001;
    if p>0.999999 then p=0.999999;

    beta_norm = quantile('NORMAL',p);
run;


ods listing gpath="C:\Users\aori004\Desktop\Letteratura\Grafici Beta";
ods graphics on;
ods graphics / reset
imagename="Corporate_Beta_QQPlot"
imagefmt=png
width=6in
height=5in;


proc univariate data=beta_tr_corp normal;

var beta_norm;

histogram beta_norm / normal;

qqplot beta_norm / normal(mu=est sigma=est);

run;
proc reg data=beta_tr_corp;

model beta_norm =
      d_euribor_l2
      d_oil_l2
      d_btp_l7
      dummy_covid;
output out=pred_beta_corp
       p=z_hat
r=resid_beta_corp;
run;
quit;
/* Normalità dei residui Beta-OLS Corporate */

proc univariate data=pred_beta_corp normal;

    var resid_beta_corp;

    histogram resid_beta_corp / normal;

    qqplot resid_beta_corp /
           normal(mu=est sigma=est);

run;



ods listing gpath="C:\Users\aori004\Desktop\Letteratura\Grafici Beta";

ods graphics on;

ods graphics / reset

imagename="Corporate_Beta_ACF_PACF"

imagefmt=png;
proc arima data=pred_beta_corp plots(unpack)=all;

    identify var=resid_beta_corp
             nlag=8;

run;
quit;


data pred_beta_corp;

    if _n_=1 then set params_corp;

    set pred_beta_corp;

    p_hat = cdf('NORMAL', z_hat);

    lgd_hat =
        quantile('BETA',
                 p_hat,
                 alpha_corp,
                 beta_corp);

run;
data pred_beta_corp;

    set pred_beta_corp;

    err_corp  = lgd_corporate - lgd_hat;
    aerr_corp = abs(err_corp);
    sqerr_corp = err_corp**2;

run;

proc sql;

create table metrics_corp as

select
    mean(aerr_corp)                as MAE,
    mean(sqerr_corp)               as MSE,
    sqrt(mean(sqerr_corp))         as RMSE

from pred_beta_corp;

quit;

proc print data=metrics_corp;
run;

proc arima data=pred_beta_corp;

    identify var=resid_beta_corp
             stationarity=(adf=(0));

run;
quit;







/* da qua*/

ods listing gpath="C:\Users\aori004\Desktop\Letteratura\Grafici MSE";

ods graphics / reset
               imagename="Corporate_Beta_Observed_vs_Fitted"
               imagefmt=png
               width=8in
               height=5in;

proc sgplot data=pred_beta_corp;

    series x=date_sas y=lgd_corporate /
        lineattrs=(thickness=2 color=blue)
        legendlabel="Observed LGD";

    series x=date_sas y=lgd_hat /
        lineattrs=(pattern=shortdash thickness=2 color=red)
        legendlabel="Fitted LGD";

    xaxis label="Quarter";
    yaxis label="LGD";

run;


/* qq plot */
proc univariate data=model_data;
   var lgd_corporate;

   qqplot lgd_corporate /
      normal(mu=est sigma=est);
run;
proc univariate data=beta_tr_corp;
   var beta_norm;

   qqplot beta_norm /
      normal(mu=est sigma=est);
run;




/* grafico */
data beta_tr_corp;
    set beta_tr_corp;

    Corporate_Beta_Transform = beta_norm;
run;

ods listing gpath="C:\Users\aori004\Desktop\Letteratura\Grafici_Beta";

ods graphics / reset
               imagename="Corporate_Beta_Distribution"
               imagefmt=png
               width=6in
               height=4in;

title "Corporate Portfolio - Distribution of Beta-Transformed LGD";

proc univariate data=beta_tr_corp normal;
    var Corporate_Beta_Transform;

    histogram Corporate_Beta_Transform / normal;
run;

title;











/* institutions */

proc univariate data=model_data;
   var lgd_institutions;
   histogram lgd_institutions / beta;
run;
proc means data=model_data noprint;
    var lgd_institutions;
    output out=stats
        mean=m
        var=v;
run;
data params;
    set stats;

    phi_inst  = m*(1-m)/v - 1;

    alpha_inst = m*phi_inst;
    beta_inst  = (1-m)*phi_inst;
run;

data beta_tr_inst;
    if _n_=1 then set params;

    set model_data;

    p = cdf('BETA', lgd_institutions, alpha_inst, beta_inst);

    /* evita p=0 o p=1 */
    if p<0.000001 then p=0.000001;
    if p>0.999999 then p=0.999999;

    beta_norm = quantile('NORMAL',p);
run;


ods listing gpath="C:\Users\aori004\Desktop\Letteratura\Grafici Beta";
ods graphics on;
ods graphics / reset
imagename="Institutions_Beta_QQPlot"
imagefmt=png
width=6in
height=5in;

proc univariate data=beta_tr_inst normal;

var beta_norm;

histogram beta_norm / normal;

qqplot beta_norm / normal(mu=est sigma=est);

run;
proc reg data=beta_tr_inst;

model beta_norm =
      d_euribor_l2
      d_oil_l2
      d_btp_l7
      dummy_covid;

output out=pred_beta_inst
       p=z_hat
r=resid_beta_inst;
run;
quit;
/* Normalità dei residui Beta-OLS Institutions */

proc univariate data=pred_beta_inst normal;

    var resid_beta_inst;

    histogram resid_beta_inst / normal;

    qqplot resid_beta_inst /
           normal(mu=est sigma=est);

run;



ods listing gpath="C:\Users\aori004\Desktop\Letteratura\Grafici Beta";

ods graphics on;

ods graphics / reset

imagename="Inst_Beta_ACF_PACF"

imagefmt=png;
proc arima data=pred_beta_inst plots(unpack)=all;

    identify var=resid_beta_inst
             nlag=8;

run;
quit;



data pred_beta_inst;

    if _n_=1 then set params;

    set pred_beta_inst;

    p_hat = cdf('NORMAL', z_hat);

    lgd_hat =
        quantile('BETA',
                 p_hat,
                 alpha_inst,
                 beta_inst);

run;
data pred_beta_inst;

    set pred_beta_inst;

    err_inst  = lgd_institutions - lgd_hat;
    aerr_inst = abs(err_inst);
    sqerr_inst = err_inst**2;

run;

proc sql;

create table metrics_inst as

select
    mean(aerr_inst)                as MAE,
    mean(sqerr_inst)               as MSE,
    sqrt(mean(sqerr_inst))         as RMSE

from pred_beta_inst;

quit;

proc print data=metrics_inst;
run;


proc arima data=pred_beta_inst;

    identify var=resid_beta_inst
             stationarity=(adf=(0));

run;
quit;




ods listing gpath="C:\Users\aori004\Desktop\Letteratura\Grafici MSE";

ods graphics / reset
               imagename="Institutions_Beta_Observed_vs_Fitted"
               imagefmt=png
               width=8in
               height=5in;

proc sgplot data=pred_beta_inst;

    series x=date_sas y=lgd_institutions /
        lineattrs=(thickness=2 color=blue)
        legendlabel="Observed LGD";

    series x=date_sas y=lgd_hat /
        lineattrs=(pattern=shortdash thickness=2 color=red)
        legendlabel="Fitted LGD";

    xaxis label="Quarter";
    yaxis label="LGD";

run;



/*  grafico */
data beta_tr_inst;
    set beta_tr_inst;

    Institutions_Beta_Transform = beta_norm;
run;

ods listing gpath="C:\Users\aori004\Desktop\Letteratura\Grafici MSE";

ods graphics / reset
               imagename="Institutions_Beta_Distribution"
               imagefmt=png
               width=6in
               height=4in;

title "Financial Institutions Portfolio - Distribution of Beta-Transformed LGD";

proc univariate data=beta_tr_inst normal;
    var Institutions_Beta_Transform;

    histogram Institutions_Beta_Transform / normal;
run;

title;