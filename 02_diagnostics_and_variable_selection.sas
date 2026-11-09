/*==============================================================================
  02_diagnostics_and_variable_selection.sas
  (a) Time-series diagnostics of the LGD and macro series
  (b) Lag screening of each candidate regressor (one regression per lag)
  (c) VIF check of the final specification
  (d) LASSO robustness check on the full set of candidates and lags

  Input : &root/output/model_data.xlsx  (created by 01_data_preparation.sas)
==============================================================================*/

options validvarname=any;
%let root = C:/path/to/project;   /* <-- set your project folder */

proc import datafile="&root/output/model_data.xlsx" out=model_data dbms=xlsx replace;
    sheet="model_data";
    getnames=yes;
run;

/*------------------------------------------------------------------
  (a) Diagnostics: descriptive statistics, normality, autocorrelation
      (Ljung-Box in the PROC ARIMA output), ADF test in levels and in
      first differences
------------------------------------------------------------------*/
%macro series_diag(var=);
    title "Diagnostics: &var";
    proc means data=model_data n mean median std min q1 q3 max skew kurt;
        var &var;
    run;
    proc univariate data=model_data normal;     /* Shapiro-Wilk, KS, ... */
        var &var;
    run;
    proc arima data=model_data;                 /* ACF + ADF on the level */
        identify var=&var nlag=8 stationarity=(adf=(0,1,2,3,4));
    run; quit;
    data _diff;
        set model_data;
        d_x = dif(&var);
    run;
    proc arima data=_diff;                      /* ADF on the first difference */
        identify var=d_x stationarity=(adf=(0,1,2,3,4));
    run; quit;
    title;
%mend series_diag;

%macro run_series_diag;
    %let vars = lgd_retail lgd_pmi lgd_corporate lgd_institutions euribor_3m btp_10y oil_price unemployment_ita pil_ita pil_ue default_rate;
    %do i = 1 %to %sysfunc(countw(&vars));
        %series_diag(var=%scan(&vars, &i));
    %end;
%mend run_series_diag;

%run_series_diag;

/*------------------------------------------------------------------
  (b) Lag screening: regress each logit-LGD on one regressor at a time
      (lag 0 to 8) and collect the adjusted R-squared.
      Note: observations are lost with each lag, so the sample changes
      across lags; the ranking is only indicative. Significance of the
      chosen lags is checked in the full regressions (script 03).
------------------------------------------------------------------*/
proc datasets lib=work nolist;
    delete lag_screen_results;
quit;

%macro lag_screen(y=, x0=, p=);
    %do l = 0 %to 8;
        %if &l = 0 %then %let v = &x0;
        %else %let v = &p._l&l;

        proc reg data=model_data outest=_est edf noprint;
            model &y = &v;
        run; quit;

        data _est;
            length yvar xvar $32;
            set _est(keep=_P_ _EDF_ _RSQ_);
            adj_r2 = 1 - (1 - _RSQ_) * (_EDF_ + _P_ - 1) / _EDF_;
            yvar = "&y";
            xvar = "&v";
            keep yvar xvar adj_r2;
        run;

        proc append base=lag_screen_results data=_est force;
        run;
    %end;
%mend lag_screen;

%macro screen_all;
    %let ys = lgd_retail_logit lgd_pmi_logit lgd_corp_logit lgd_inst_logit;
    %do i = 1 %to 4;
        %let y = %scan(&ys, &i);
        %lag_screen(y=&y, x0=d_euribor, p=d_euribor);
        %lag_screen(y=&y, x0=d_oil,     p=d_oil);
        %lag_screen(y=&y, x0=d_btp,     p=d_btp);
        %lag_screen(y=&y, x0=d_unemp,   p=d_unemp);
        %lag_screen(y=&y, x0=d_def,     p=d_def);
        %lag_screen(y=&y, x0=d_pilita,  p=dpil_ita);
        %lag_screen(y=&y, x0=d_pilue,   p=dpil_ue);
    %end;
%mend screen_all;

%screen_all;

proc sort data=lag_screen_results;
    by yvar descending adj_r2;
run;
proc print data=lag_screen_results noobs;
    by yvar;
run;

/*------------------------------------------------------------------
  (c) Multicollinearity check on the final specification (VIF)
------------------------------------------------------------------*/
proc reg data=model_data plots=none;
    model lgd_retail_logit = d_euribor_l2 d_oil_l2 d_btp_l7 dummy_covid / vif;
run; quit;

/*------------------------------------------------------------------
  (d) LASSO on all candidate variables and lags 0-8 (robustness check).
      The penalty parameter is chosen by cross-validation (default folds);
      the seed is fixed for reproducibility.
------------------------------------------------------------------*/
%macro lasso(y=);
    title "LASSO: &y";
    proc glmselect data=model_data seed=12345 plots=none;
        model &y =
            d_def     d_def_l1-d_def_l8
            d_unemp   d_unemp_l1-d_unemp_l8
            d_oil     d_oil_l1-d_oil_l8
            d_euribor d_euribor_l1-d_euribor_l8
            d_btp     d_btp_l1-d_btp_l8
            d_pilita  dpil_ita_l1-dpil_ita_l8
            d_pilue   dpil_ue_l1-dpil_ue_l8
            dummy_covid
            / selection=lasso(choose=cv stop=none);
    run;
    title;
%mend lasso;

%lasso(y=lgd_retail_logit);
%lasso(y=lgd_pmi_logit);
%lasso(y=lgd_corp_logit);
%lasso(y=lgd_inst_logit);
