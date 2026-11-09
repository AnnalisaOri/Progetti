/*==============================================================================
  03_models_logit_beta_ols.sas
  Final satellite models for the four segments (Retail, SME, Corporate,
  Financial Institutions):
    - Logit-OLS : OLS on logit(LGD)
    - Beta-OLS  : LGD -> Beta CDF -> normal quantile, then OLS
                  (Beta parameters by method of moments)
    - OLS       : untransformed benchmark
  Outputs: coefficients, residual diagnostics, in-sample accuracy
  (MAE, MSE, RMSE, RMSE as % of mean LGD), Logit vs Beta comparison.

  Input : &root/output/model_data.xlsx  (created by 01_data_preparation.sas)
==============================================================================*/

options validvarname=any;
%let root = C:/path/to/project;   /* <-- set your project folder */

proc import datafile="&root/output/model_data.xlsx" out=model_data dbms=xlsx replace;
    sheet="model_data";
    getnames=yes;
run;

/* Final specification: change in Euribor (t-2), change in oil price (t-2),
   change in BTP yield (t-7), Covid dummy (2020Q1-2021Q4) */
%let regs = d_euribor_l2 d_oil_l2 d_btp_l7 dummy_covid;

/*------------------------------------------------------------------
  In-sample accuracy metrics (needs err, abs_err, sq_err in the dataset)
------------------------------------------------------------------*/
%macro accuracy(ds=, seg=, model=, y=);
    proc sql;
        create table metrics_&model._&seg as
        select "&seg"   as segment length=12,
               "&model" as model   length=12,
               mean(abs_err)         as MAE,
               mean(sq_err)          as MSE,
               sqrt(calculated MSE)  as RMSE,
               mean(&y)              as mean_lgd,
               calculated RMSE / calculated mean_lgd as RMSE_pct_mean
        from &ds;
    quit;
%mend accuracy;

/*------------------------------------------------------------------
  Logit-OLS
------------------------------------------------------------------*/
%macro logit_ols(seg=, y_logit=, y_lgd=);
    title "Logit-OLS: &seg";

    /* final model, with VIF */
    proc reg data=model_data plots=none;
        model &y_logit = &regs / vif;
        output out=pred_logit_&seg p=logit_hat r=resid_logit;
    run; quit;

    /* Effect of the BTP regressor on the adjusted R-squared.
       (a) without BTP on the longer sample: NOT comparable with the full
           model, because lagging the BTP by 7 quarters drops 5 observations.
       (b) without BTP on the same sample as the full model: comparable. */
    proc reg data=model_data plots=none;
        model &y_logit = d_euribor_l2 d_oil_l2 dummy_covid;
    run; quit;
    proc reg data=model_data(where=(not missing(d_btp_l7))) plots=none;
        model &y_logit = d_euribor_l2 d_oil_l2 dummy_covid;
    run; quit;

    /* back-transform to LGD and compute errors */
    data pred_logit_&seg;
        set pred_logit_&seg;
        lgd_hat = exp(logit_hat) / (1 + exp(logit_hat));
        err     = &y_lgd - lgd_hat;
        abs_err = abs(err);
        sq_err  = err**2;
    run;
    %accuracy(ds=pred_logit_&seg, seg=&seg, model=logit, y=&y_lgd);

    /* residual diagnostics: normality, ACF/PACF + Ljung-Box, ADF */
    proc univariate data=pred_logit_&seg normal;
        var resid_logit;
    run;
    proc arima data=pred_logit_&seg;
        identify var=resid_logit nlag=8 stationarity=(adf=(0,1,2,3));
    run; quit;

    /* observed vs fitted */
    proc sgplot data=pred_logit_&seg;
        series x=date_sas y=&y_lgd  / lineattrs=(thickness=2) legendlabel="Observed LGD";
        series x=date_sas y=lgd_hat / lineattrs=(pattern=dash thickness=2) legendlabel="Fitted LGD";
        xaxis label="Quarter";
        yaxis label="LGD (&seg)";
    run;
    title;
%mend logit_ols;

/*------------------------------------------------------------------
  Beta-OLS (method of moments for the Beta parameters)
------------------------------------------------------------------*/
%macro beta_ols(seg=, y_lgd=);
    title "Beta-OLS: &seg";

    /* Beta parameters from sample mean m and variance v */
    proc means data=model_data noprint;
        var &y_lgd;
        output out=_stats mean=m var=v;
    run;
    data _beta_par;
        set _stats;
        phi   = m * (1 - m) / v - 1;
        alpha = m * phi;
        beta  = (1 - m) * phi;
        keep alpha beta;
    run;

    /* probability integral transform: Beta CDF, then standard normal quantile */
    data beta_tr_&seg;
        if _n_ = 1 then set _beta_par;
        set model_data;
        p = cdf('BETA', &y_lgd, alpha, beta);
        if p < 0.000001 then p = 0.000001;      /* avoid p = 0 or 1 */
        if p > 0.999999 then p = 0.999999;
        z = quantile('NORMAL', p);
    run;

    proc univariate data=beta_tr_&seg normal;   /* normality of transformed LGD */
        var z;
    run;

    proc reg data=beta_tr_&seg plots=none;
        model z = &regs;
        output out=pred_beta_&seg p=z_hat r=resid_beta;
    run; quit;

    /* back-transform: normal CDF, then inverse Beta CDF */
    data pred_beta_&seg;
        if _n_ = 1 then set _beta_par;
        set pred_beta_&seg;
        lgd_hat = quantile('BETA', cdf('NORMAL', z_hat), alpha, beta);
        err     = &y_lgd - lgd_hat;
        abs_err = abs(err);
        sq_err  = err**2;
    run;
    %accuracy(ds=pred_beta_&seg, seg=&seg, model=beta, y=&y_lgd);

    proc univariate data=pred_beta_&seg normal;
        var resid_beta;
    run;
    proc arima data=pred_beta_&seg;
        identify var=resid_beta nlag=8 stationarity=(adf=(0));
    run; quit;
    title;
%mend beta_ols;

/*------------------------------------------------------------------
  OLS benchmark on untransformed LGD
------------------------------------------------------------------*/
%macro ols_benchmark(seg=, y_lgd=);
    proc reg data=model_data plots=none;
        model &y_lgd = &regs;
        output out=pred_ols_&seg p=lgd_hat;
    run; quit;
    data pred_ols_&seg;
        set pred_ols_&seg;
        err     = &y_lgd - lgd_hat;
        abs_err = abs(err);
        sq_err  = err**2;
    run;
    %accuracy(ds=pred_ols_&seg, seg=&seg, model=ols, y=&y_lgd);
%mend ols_benchmark;

/*------------------------------------------------------------------
  Logit vs Beta: absolute difference between fitted LGD
------------------------------------------------------------------*/
%macro compare_fits(seg=);
    proc sort data=pred_logit_&seg out=_l(keep=date_sas lgd_hat rename=(lgd_hat=lgd_logit));
        by date_sas;
    run;
    proc sort data=pred_beta_&seg out=_b(keep=date_sas lgd_hat rename=(lgd_hat=lgd_beta));
        by date_sas;
    run;
    data compare_&seg;
        merge _l _b;
        by date_sas;
        abs_diff = abs(lgd_logit - lgd_beta);
    run;
    title "Logit vs Beta fitted LGD: &seg";
    proc means data=compare_&seg n mean max;
        var abs_diff;
    run;
    title;
%mend compare_fits;

/*------------------------------------------------------------------
  Run for the four segments
------------------------------------------------------------------*/
%logit_ols(seg=retail, y_logit=lgd_retail_logit, y_lgd=lgd_retail);
%logit_ols(seg=sme,    y_logit=lgd_pmi_logit,    y_lgd=lgd_pmi);
%logit_ols(seg=corp,   y_logit=lgd_corp_logit,   y_lgd=lgd_corporate);
%logit_ols(seg=inst,   y_logit=lgd_inst_logit,   y_lgd=lgd_institutions);

%beta_ols(seg=retail, y_lgd=lgd_retail);
%beta_ols(seg=sme,    y_lgd=lgd_pmi);
%beta_ols(seg=corp,   y_lgd=lgd_corporate);
%beta_ols(seg=inst,   y_lgd=lgd_institutions);

%ols_benchmark(seg=retail, y_lgd=lgd_retail);
%ols_benchmark(seg=sme,    y_lgd=lgd_pmi);
%ols_benchmark(seg=corp,   y_lgd=lgd_corporate);
%ols_benchmark(seg=inst,   y_lgd=lgd_institutions);

%compare_fits(seg=retail);
%compare_fits(seg=sme);
%compare_fits(seg=corp);
%compare_fits(seg=inst);

/* accuracy summary: all models and segments */
data accuracy_summary;
    set metrics_logit_: metrics_beta_: metrics_ols_:;
run;
proc print data=accuracy_summary noobs;
    format MAE MSE RMSE 10.6 mean_lgd 8.4 RMSE_pct_mean percent8.2;
run;
