/*==============================================================================
  04_scenario_projection.sas
  Forward-looking LGD projections under three macroeconomic scenarios
  (Baseline, Adverse, Positive) with the final Logit-OLS models, and
  probability-weighted LGD.

  Inputs
    &root/output/model_data.xlsx   (created by 01_data_preparation.sas)
    &root/input/macro_scenarios.xlsx, sheets "Baseline", "Adverse",
      "Positive new": quarterly paths of Euribor 3M, oil price and BTP 10Y
      from 2026Q2 (columns: data, euribor_3m, prezzo_petrolio, btp_10y).
      Baseline: Bank of Italy projections; Adverse: baseline plus EBA/ESRB
      stress-test shocks; Positive: symmetric transformation of the adverse
      scenario (see thesis, Section "Application of Macroeconomic Scenarios").

  Notes
    - The Covid dummy is set to 0 in the projection period.
    - Scenario weights: 58% Baseline, 21% Adverse, 21% Positive.
==============================================================================*/

options validvarname=any;
%let root = C:/path/to/project;   /* <-- set your project folder */

%let w_base = 0.58;
%let w_adv  = 0.21;
%let w_pos  = 0.21;

proc import datafile="&root/output/model_data.xlsx" out=model_data dbms=xlsx replace;
    sheet="model_data";
    getnames=yes;
run;

/*------------------------------------------------------------------
  1. Estimate the final Logit-OLS model for each segment
     (coefficients stored in coef_<segment>)
------------------------------------------------------------------*/
%macro est_coef(seg=, y=);
    proc reg data=model_data outest=coef_&seg noprint;
        model &y = d_euribor_l2 d_oil_l2 d_btp_l7 dummy_covid;
    run; quit;
%mend est_coef;

%est_coef(seg=retail, y=lgd_retail_logit);
%est_coef(seg=sme,    y=lgd_pmi_logit);
%est_coef(seg=corp,   y=lgd_corp_logit);
%est_coef(seg=inst,   y=lgd_inst_logit);

/*------------------------------------------------------------------
  2. Historical macro series (same names as in the scenario workbook)
------------------------------------------------------------------*/
data storico_macro;
    set model_data(keep=date_sas euribor_3m btp_10y oil_price
                   rename=(date_sas=data oil_price=prezzo_petrolio));
run;

/*------------------------------------------------------------------
  3. Build the regressors for one scenario: history + projected path,
     first differences and the lags used in the final specification
------------------------------------------------------------------*/
%macro prep_scenario(sheet=, name=);
    proc import datafile="&root/input/macro_scenarios.xlsx" out=scn_&name dbms=xlsx replace;
        sheet="&sheet";
        getnames=yes;
    run;

    data scn_&name;
        set scn_&name;
        euribor_3m_num      = input(euribor_3m, best32.);
        prezzo_petrolio_num = input(prezzo_petrolio, best32.);
        btp_num             = input(btp_10y, best32.);
        drop euribor_3m prezzo_petrolio btp_10y;
        rename euribor_3m_num      = euribor_3m
               prezzo_petrolio_num = prezzo_petrolio
               btp_num             = btp_10y;
    run;

    data &name._full;
        set storico_macro
            scn_&name(keep=data euribor_3m prezzo_petrolio btp_10y);
    run;
    proc sort data=&name._full;
        by data;
    run;

    data &name._model;
        set &name._full;
        d_euribor    = dif(euribor_3m);
        d_oil        = dif(prezzo_petrolio);
        d_btp        = dif(btp_10y);
        d_euribor_l2 = lag2(d_euribor);
        d_oil_l2     = lag2(d_oil);
        d_btp_l7     = lag7(d_btp);
        dummy_covid  = 0;
    run;
%mend prep_scenario;

%prep_scenario(sheet=Baseline,     name=baseline);
%prep_scenario(sheet=Adverse,      name=adverse);
%prep_scenario(sheet=Positive new, name=positive);

/*------------------------------------------------------------------
  4. Projected LGD: apply the estimated coefficients and back-transform
     with the logistic function. Only quarters from 2026Q2 are kept.
------------------------------------------------------------------*/
%macro forecast(coef=, inds=, out=);
    data &out;
        if _n_ = 1 then set &coef(keep=Intercept d_euribor_l2 d_oil_l2 d_btp_l7 dummy_covid
                                  rename=(Intercept=alpha d_euribor_l2=b_eur d_oil_l2=b_oil
                                          d_btp_l7=b_btp dummy_covid=b_cov));
        set &inds;
        lgd_logit_pred = alpha + b_eur*d_euribor_l2 + b_oil*d_oil_l2
                       + b_btp*d_btp_l7 + b_cov*dummy_covid;
        lgd_pred = exp(lgd_logit_pred) / (1 + exp(lgd_logit_pred));
        if year(data) > 2026 or (year(data) = 2026 and qtr(data) >= 2);
        keep data lgd_logit_pred lgd_pred;
    run;
%mend forecast;

/* projections for the three scenarios + probability-weighted LGD */
%macro project(seg=);
    %forecast(coef=coef_&seg, inds=baseline_model, out=&seg._baseline);
    %forecast(coef=coef_&seg, inds=adverse_model,  out=&seg._adverse);
    %forecast(coef=coef_&seg, inds=positive_model, out=&seg._positive);

    data &seg._compare;
        merge &seg._baseline(rename=(lgd_pred=baseline))
              &seg._adverse(rename=(lgd_pred=adverse))
              &seg._positive(rename=(lgd_pred=positive));
        by data;
        drop lgd_logit_pred;
        lgd_weighted = &w_base*baseline + &w_adv*adverse + &w_pos*positive;
    run;

    title "Projected LGD by scenario: &seg";
    proc print data=&seg._compare noobs;
        format baseline adverse positive lgd_weighted percent8.2;
    run;
    title;
%mend project;

%project(seg=retail);
%project(seg=sme);
%project(seg=corp);
%project(seg=inst);

/*------------------------------------------------------------------
  5. Charts: observed LGD and the three scenario paths, starting from
     the last observation (2026Q1)
------------------------------------------------------------------*/
%macro plot_scenarios(seg=, y_lgd=, label=);
    data _hist;
        set model_data(keep=date_sas &y_lgd rename=(date_sas=data &y_lgd=LGD));
        length scenario $10;
        scenario = "Observed";
    run;
    data _last;
        set _hist;
        if data = '31MAR2026'd;
    run;
    data _base;
        set _last &seg._baseline(keep=data lgd_pred rename=(lgd_pred=LGD));
        length scenario $10;
        scenario = "Baseline";
    run;
    data _adv;
        set _last &seg._adverse(keep=data lgd_pred rename=(lgd_pred=LGD));
        length scenario $10;
        scenario = "Adverse";
    run;
    data _pos;
        set _last &seg._positive(keep=data lgd_pred rename=(lgd_pred=LGD));
        length scenario $10;
        scenario = "Positive";
    run;
    data _graph;
        set _hist _base _adv _pos;
    run;

    proc sgplot data=_graph;
        styleattrs datacontrastcolors=(black blue red green);
        series x=data y=LGD / group=scenario markers markerattrs=(size=8) lineattrs=(thickness=2);
        refline '01APR2026'd / axis=x label="Forecast start" lineattrs=(pattern=shortdash thickness=2);
        xaxis label="Quarter";
        yaxis label="&label LGD (%)" valuesformat=percent8.0;
        keylegend / position=topright;
    run;
%mend plot_scenarios;

%plot_scenarios(seg=retail, y_lgd=lgd_retail,       label=Retail);
%plot_scenarios(seg=sme,    y_lgd=lgd_pmi,          label=SME);
%plot_scenarios(seg=corp,   y_lgd=lgd_corporate,    label=Corporate);
%plot_scenarios(seg=inst,   y_lgd=lgd_institutions, label=Financial Institutions);
