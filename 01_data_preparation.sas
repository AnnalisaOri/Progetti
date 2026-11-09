/*==============================================================================
  01_data_preparation.sas
  Builds the modelling dataset (model_data) used by all the other scripts.

  Inputs  (&root/input)
    retail.xlsx, pmi.xlsx, corporate.xlsx, institutions.xlsx
        ECB IRB LGD series, Significant Institutions (sheet "Data(SUP)")
    macro_series.xlsx (sheet "Baseline")
        Quarterly macro-financial series: Euribor 3M, BTP 10Y, oil price,
        GDP (Italy, EU), unemployment, default rate (public sources, see thesis)
  Output  (&root/output)
    model_data.xlsx (sheet "model_data")

  Steps: import -> merge by quarter -> first differences -> lags 1-8 ->
         logit transform of LGD -> Covid dummy -> export
==============================================================================*/

options validvarname=any;
%let root = C:/path/to/project;   /* <-- set your project folder */

/*------------------------------------------------------------------
  1. Import the four LGD series (one macro call per portfolio segment)
------------------------------------------------------------------*/
%macro import_lgd(name=);
    proc import datafile="&root/input/&name..xlsx" out=&name dbms=xlsx replace;
        sheet="Data(SUP)";
        getnames=yes;
    run;

    data &name;
        set &name(rename=("obs.value"n=obs));
        date_sas = input(DATE, yymmdd10.);
        format date_sas date9.;
        if not missing(obs);
    run;
%mend import_lgd;

%import_lgd(name=retail);
%import_lgd(name=pmi);          /* SME */
%import_lgd(name=corporate);
%import_lgd(name=institutions); /* Financial Institutions */

/*------------------------------------------------------------------
  2. Import macro series and keep the estimation window 2018Q3-2026Q1
------------------------------------------------------------------*/
proc import datafile="&root/input/macro_series.xlsx" out=macro_all dbms=xlsx replace;
    sheet="Baseline";
    getnames=yes;
run;

data macro_sample;
    set macro_all;
    format Data yyq6.;
    if '01JUL2018'd <= Data <= '31MAR2026'd;
    rename prezzo_petrolio = oil_price;
    euribor_3m_num  = input(euribor_3m, best32.);
    default_ratenum = input(default_rate, best32.);
    drop euribor_3m default_rate;
    rename euribor_3m_num = euribor_3m  default_ratenum = default_rate;
run;

/*------------------------------------------------------------------
  3. Merge LGD series and macro series on the calendar quarter
------------------------------------------------------------------*/
proc sql;
    create table model_data as
    select a.date_sas,
           a.obs as lgd_pmi,
           r.obs as lgd_retail,
           c.obs as lgd_corporate,
           i.obs as lgd_institutions,
           b.PIL_ITA, b.PIL_UE, b.unemployment_ita,
           b.euribor_3m, b.btp_10y, b.oil_price, b.default_rate
    from pmi as a
    left join macro_sample as b
        on intnx('quarter', a.date_sas, 0, 'b') = intnx('quarter', b.data, 0, 'b')
    left join retail as r
        on intnx('quarter', a.date_sas, 0, 'b') = intnx('quarter', r.date_sas, 0, 'b')
    left join corporate as c
        on intnx('quarter', a.date_sas, 0, 'b') = intnx('quarter', c.date_sas, 0, 'b')
    left join institutions as i
        on intnx('quarter', a.date_sas, 0, 'b') = intnx('quarter', i.date_sas, 0, 'b');
quit;

/* LGD in fractions (the corporate series is already expressed as a fraction) */
data model_data;
    set model_data;
    lgd_pmi          = lgd_pmi / 100;
    lgd_retail       = lgd_retail / 100;
    lgd_institutions = lgd_institutions / 100;
run;

/*------------------------------------------------------------------
  4. First differences of the regressors (d_ = quarterly change)
------------------------------------------------------------------*/
data model;
    set model_data;
    d_pilue   = dif(pil_ue);
    d_pilita  = dif(pil_ita);
    d_unemp   = dif(unemployment_ita);
    d_oil     = dif(oil_price);
    d_btp     = dif(btp_10y);
    d_def     = dif(default_rate);
    d_euribor = dif(euribor_3m);
run;

/*------------------------------------------------------------------
  5. Lags 1-8 of every candidate regressor (_lN = N quarters earlier)
------------------------------------------------------------------*/
%macro mklags(var=, prefix=);
    %do i = 1 %to 8;
        &prefix._l&i = lag&i(&var);
    %end;
%mend mklags;

data model_lag;
    set model;
    %mklags(var=d_def,     prefix=d_def);
    %mklags(var=d_unemp,   prefix=d_unemp);
    %mklags(var=d_oil,     prefix=d_oil);
    %mklags(var=d_euribor, prefix=d_euribor);
    %mklags(var=d_btp,     prefix=d_btp);
    %mklags(var=pil_ita,   prefix=pil_ita);
    %mklags(var=pil_ue,    prefix=pil_ue);
    %mklags(var=d_pilita,  prefix=dpil_ita);
    %mklags(var=d_pilue,   prefix=dpil_ue);
run;

/*------------------------------------------------------------------
  6. Logit transform of LGD and Covid dummy (2020Q1-2021Q4)
------------------------------------------------------------------*/
data model_data;
    set model_lag;
    lgd_pmi_logit    = log(lgd_pmi / (1 - lgd_pmi));
    lgd_retail_logit = log(lgd_retail / (1 - lgd_retail));
    lgd_inst_logit   = log(lgd_institutions / (1 - lgd_institutions));
    lgd_corp_logit   = log(lgd_corporate / (1 - lgd_corporate));
    if year(date_sas) in (2020, 2021) then dummy_covid = 1;
    else dummy_covid = 0;
run;

/*------------------------------------------------------------------
  7. Export
------------------------------------------------------------------*/
proc export data=model_data outfile="&root/output/model_data.xlsx" dbms=xlsx replace;
    sheet="model_data";
run;
