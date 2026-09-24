/*=========================================================
IMPORT FILE EXCEL
=========================================================*/

proc import
    datafile="C:\Users\aori004\Desktop\BFF\scenari\260422_BFF_Proiezioni_Scenari_Macro_v1.xlsx"
    out=macro_all2
    dbms=xlsx
    replace;
    sheet="Baseline";
    getnames=yes;
run;


/*=========================================================
SELEZIONE PERIODO 2018Q3 - 2026Q1
=========================================================*/

data macro_sample;
    set macro_all2;

    /* Adattare il formato della variabile Data se necessario */
    format Data yyq6.;
    if '01JUL2018'd <= Data <= '31MAR2026'd;
rename prezzo_petrolio=oil_price;
euribor_3m_num = input(euribor_3m, best32.);

drop euribor_3m;
rename euribor_3m_num = euribor_3m;

default_ratenum = input(default_rate, best32.);

drop default_rate;
rename default_ratenum = default_rate;
run;


/*=========================================================
MACRO ANALISI REGRESSORE
=========================================================*/

%macro analisi_regressore(var=);

/*-------------------------------------------------------*/
/* GRAFICO DELLA SERIE */
/*-------------------------------------------------------*/

ods listing gpath="C:\Users\aori004\Desktop\Letteratura\New";
title1 "Variabile &var";
title2 "Serie storica - &var";


ods graphics / reset imagename="&var" imagefmt=png;
proc sgplot data=macro_sample;
    series x=Data y=&var / lineattrs=(thickness=2);
    xaxis label="Date";
    yaxis label="&var";
run;




/*-------------------------------------------------------*/
/* STATISTICHE DESCRITTIVE */
/*-------------------------------------------------------*/

title2 "Statistiche descrittive";

proc means data=macro_sample
    n mean median std min q1 q3 max skew kurt;
    var &var;
run;


/*-------------------------------------------------------*/
/* NORMALITA' */
/*-------------------------------------------------------*/

title2 "Test di normalita";

proc univariate data=macro_sample normal;
    var &var;
    histogram &var / normal;
    qqplot &var / normal(mu=est sigma=est);
run;


/*-------------------------------------------------------*/
/* AUTOCORRELAZIONE e LJUNG BOX */
/*-------------------------------------------------------*/

title2 "Autocorrelazione";

proc arima data=macro_sample;
    identify var=&var
    nlag=12;
run;
quit;


/*-------------------------------------------------------*/
/* DURBIN WATSON */
/*-------------------------------------------------------*/

title2 "Durbin Watson";

proc autoreg data=macro_sample;
    model &var = ;
run;

/*-------------------------------------------------------*/
/* ADF LIVELLO */
/*-------------------------------------------------------*/

title2 "ADF serie in livello";

proc arima data=macro_sample;
    identify var=&var
    stationarity=(adf=(0,1,2,3,4));
run;
quit;


/*-------------------------------------------------------*/
/* PRIMA DIFFERENZA */
/*-------------------------------------------------------*/

data diff_&var;
    set macro_sample;

    diff_&var = dif(&var);
run;


/*-------------------------------------------------------*/
/* ADF DIFFERENZA */
/*-------------------------------------------------------*/

title2 "ADF prima differenza";

proc arima data=diff_&var;
    identify var=diff_&var
    stationarity=(adf=(0,1,2,3,4));
run;
quit;

title;

%mend;



%analisi_regressore(var=PIL_ue);

%analisi_regressore(var=PIL_ITA);


%analisi_regressore(var=unemployment_ita);


%analisi_regressore(var=oil_price);

%analisi_regressore(var=euribor_3m);


%analisi_regressore(var=btp_10y);


%analisi_regressore(var=default_rate);



/*importare le varie lgd da codicie lgd corporate, lgd institutions.. e il primo pezzo di questo codice
per creo dataset con tutte le variabili target e regressori */
proc sql;
create table model_data as
select
    a.date_sas,
    a.obs as lgd_pmi,
    r.obs as lgd_retail,
	c.obs as lgd_corporate,
	i.obs as lgd_institutions,
    b.PIL_ITA,
    b.PIL_UE,
    b.unemployment_ita,
    b.euribor_3m,
    b.btp_10y,
    b.oil_price,
    b.default_rate
from pmi as a

left join macro_sample as b
on intnx('quarter',a.date_sas,0,'b')
 = intnx('quarter',b.data,0,'b')

left join retail as r
on intnx('quarter',a.date_sas,0,'b')
 = intnx('quarter',r.date_sas,0,'b')


left join corporate as c
on intnx('quarter',a.date_sas,0,'b')
 = intnx('quarter',c.date_sas,0,'b')


left join institutions as i
on intnx('quarter',a.date_sas,0,'b')
 = intnx('quarter',i.date_sas,0,'b')
;

quit;



/*metto lgd in , corporate è già in % */

data model_data;
    set model_data;

    lgd_pmi_frac    = lgd_pmi / 100;
    lgd_retail_frac = lgd_retail / 100;
	lgd_inst_frac=lgd_institutions / 100;
	drop lgd_pmi lgd_retail lgd_institutions;

rename
lgd_pmi_frac = lgd_pmi
lgd_retail_frac = lgd_retail
lgd_inst_frac=lgd_institutions;

run;

proc datasets lib=work nolist;
    modify model_data;
    format lgd_pmi lgd_retail lgd_institutions percent8.2;
quit;





/*differenziazioni */
data model;
set model_data;
d_lgdretail=dif(lgd_retail);
d_lgdpmi=dif(lgd_pmi);
d_lgdinst=dif(lgd_institutions);
d_lgdcorp=dif(lgd_corporate);
d_pilue= dif(pil_ue);
d_pilita=dif(pil_ita);
d_unemp   = dif(unemployment_ita);
d_oil     = dif(oil_price);
d_btp     = dif(btp_10y);
d_def     = dif(default_rate);
d_euribor = dif(euribor_3m);
run;




/*verifico stazionarietà serie differenziate */

proc arima data=model;
identify var=d_lgdpmi
stationarity=(adf=(0,1,2,3,4));
run;
quit;
/* è stazionaria */

proc arima data=model;
identify var=d_pilue
stationarity=(adf=(0,1,2,3,4));
run;
quit;

proc arima data=model;
identify var=d_pilita
stationarity=(adf=(0,1,2,3,4));
run;
quit;

proc arima data=model;
identify var=d_lgdpmi
stationarity=(adf=(0,1,2,3,4));
run;
quit;

proc arima data=model;
identify var=d_euribor
stationarity=(adf=(0,1,2,3,4));
run;
quit;



/* provo a tenere pil ita e pil ue non differenziati, sono stazionari */
proc corr data=model;
var
d_lgdpmi;

with
d_def
d_unemp
d_btp
d_oil
pil_ita
pil_ue
d_euribor;
run;
/* basse correlazioni e tutte non significative */


proc corr data=model;
var
d_lgdinst;

with
d_def
d_unemp
d_btp
d_oil
pil_ita
pil_ue
d_euribor;
run;



proc corr data=model;
var
d_lgdcorp;

with
d_def
d_unemp
d_btp
d_oil
pil_ita
pil_ue
d_euribor;
run;

proc corr data=model;
var
d_lgdretail;

with
d_def
d_unemp
d_btp
d_oil
pil_ita
pil_ue
d_euribor;
run;









data model_lag;
set model;

d_def_l1 = lag1(d_def);
d_def_l2 = lag2(d_def);
d_def_l3 = lag3(d_def);
d_def_l4 = lag4(d_def);
d_def_l5 = lag5(d_def);
d_def_l6 = lag6(d_def);
d_def_l7 = lag7(d_def);
d_def_l8 = lag8(d_def);

d_unemp_l1 = lag1(d_unemp);
d_unemp_l2 = lag2(d_unemp);
d_unemp_l3 = lag3(d_unemp);
d_unemp_l4 = lag4(d_unemp);
d_unemp_l5 = lag5(d_unemp);
d_unemp_l6 = lag6(d_unemp);
d_unemp_l7 = lag7(d_unemp);
d_unemp_l8 = lag8(d_unemp);

d_oil_l1=lag1(d_oil);
d_oil_l2=lag2(d_oil);
d_oil_l3=lag3(d_oil);
d_oil_l4=lag4(d_oil);
d_oil_l5=lag5(d_oil);
d_oil_l6=lag6(d_oil);
d_oil_l7=lag7(d_oil);
d_oil_l8=lag8(d_oil);


d_euribor_l1 = lag1(d_euribor);
d_euribor_l2 = lag2(d_euribor);
d_euribor_l3 = lag3(d_euribor);
d_euribor_l4 = lag4(d_euribor);
d_euribor_l5 = lag5(d_euribor);
d_euribor_l6 = lag6(d_euribor);
d_euribor_l7 = lag7(d_euribor);
d_euribor_l8 = lag8(d_euribor);

d_btp_l1 = lag1(d_btp);
d_btp_l2 = lag2(d_btp);
d_btp_l3 = lag3(d_btp);
d_btp_l4 = lag4(d_btp);
d_btp_l5 = lag5(d_btp);
d_btp_l6 = lag6(d_btp);
d_btp_l7 = lag7(d_btp);
d_btp_l8 = lag8(d_btp);



pil_ita_l1 = lag1(pil_ita);
pil_ita_l2 = lag2(pil_ita);
pil_ita_l3 = lag3(pil_ita);
pil_ita_l4 = lag4(pil_ita);
pil_ita_l5 = lag5(pil_ita);
pil_ita_l6 = lag6(pil_ita);
pil_ita_l7 = lag7(pil_ita);
pil_ita_l8 = lag8(pil_ita);


pil_ue_l1 = lag1(pil_ue);
pil_ue_l2 = lag2(pil_ue);
pil_ue_l3 = lag3(pil_ue);
pil_ue_l4 = lag4(pil_ue);
pil_ue_l5 = lag5(pil_ue);
pil_ue_l6 = lag6(pil_ue);
pil_ue_l7 = lag7(pil_ue);
pil_ue_l8 = lag8(pil_ue);


dpil_ita_l1 = lag1(d_pilita);
dpil_ita_l2 = lag2(d_pilita);
dpil_ita_l3 = lag3(d_pilita);
dpil_ita_l4 = lag4(d_pilita);
dpil_ita_l5 = lag5(d_pilita);
dpil_ita_l6 = lag6(d_pilita);
dpil_ita_l7 = lag7(d_pilita);
dpil_ita_l8 = lag8(d_pilita);


dpil_ue_l1 = lag1(d_pilue);
dpil_ue_l2 = lag2(d_pilue);
dpil_ue_l3 = lag3(d_pilue);
dpil_ue_l4 = lag4(d_pilue);
dpil_ue_l5 = lag5(d_pilue);
dpil_ue_l6 = lag6(d_pilue);
dpil_ue_l7 = lag7(d_pilue);
dpil_ue_l8 = lag8(d_pilue);

run;






data model_data;
    set model_lag;

    lgd_pmi_logit =
        log(lgd_pmi/(1-lgd_pmi));

    lgd_retail_logit =
        log(lgd_retail/(1-lgd_retail));
 lgd_inst_logit =
        log(lgd_institutions/(1-lgd_institutions));

 lgd_corp_logit =
        log(lgd_corporate/(1-lgd_corporate));


run;


proc reg data=model_data;
    model lgd_retail_logit =
         /* pil_ita
        pil_ue
        d_unemp */
        d_euribor
        d_btp
        d_oil
        d_def;
    output out=pred p=lgd_logit_retail_hat;
run;


data pred;
    set pred;

    lgd_pmi_hat =
    exp(lgd_logit_pmi_hat)
    /
    (1+exp(lgd_logit_pmi_hat));
run;



proc reg data=model_data;
    model lgd_pmi_logit =
        unemployment_l2
        euribor_l1
        oil_price_l3
        default_rate_l1;
run;










/* per trovare lag migliore */

proc reg data=model_data;
    model lgd_retail_logit = d_euribor;
run;

proc reg data=model_data;
    model lgd_retail_logit = d_euribor_l1;
run;

proc reg data=model_data;
    model lgd_retail_logit = d_euribor_l2;
run;

proc reg data=model_data;
    model lgd_retail_logit = d_euribor_l3;
run;

proc reg data=model_data;
    model lgd_retail_logit = d_euribor_l4;
run;

proc reg data=model_data;
    model lgd_retail_logit = d_euribor_l5;
run;

proc reg data=model_data;
    model lgd_retail_logit = d_euribor_l6;
run;

proc reg data=model_data;
    model lgd_retail_logit = d_euribor_l7;
run;

proc reg data=model_data;
    model lgd_retail_logit = d_euribor_l8;
run;



/* per pmi */

proc reg data=model_data;
    model lgd_pmi_logit = d_euribor;
run;

proc reg data=model_data;
    model lgd_pmi_logit = d_euribor_l1;
run;

proc reg data=model_data;
    model lgd_pmi_logit = d_euribor_l2;
run;

proc reg data=model_data;
    model lgd_pmi_logit = d_euribor_l3;
run;

proc reg data=model_data;
    model lgd_pmi_logit = d_euribor_l4;
run;

proc reg data=model_data;
    model lgd_pmi_logit = d_euribor_l5;
run;

proc reg data=model_data;
    model lgd_pmi_logit = d_euribor_l6;
run;

proc reg data=model_data;
    model lgd_pmi_logit = d_euribor_l7;
run;

proc reg data=model_data;
    model lgd_pmi_logit = d_euribor_l8;
run;


/* per corporate */
proc reg data=model_data;
    model lgd_corp_logit = d_euribor;
run;

proc reg data=model_data;
    model lgd_corp_logit = d_euribor_l1;
run;

proc reg data=model_data;
    model lgd_corp_logit = d_euribor_l2;
run;

proc reg data=model_data;
    model lgd_corp_logit = d_euribor_l3;
run;

proc reg data=model_data;
    model lgd_corp_logit = d_euribor_l4;
run;

proc reg data=model_data;
    model lgd_corp_logit = d_euribor_l5;
run;

proc reg data=model_data;
    model lgd_corp_logit = d_euribor_l6;
run;

proc reg data=model_data;
    model lgd_corp_logit = d_euribor_l7;
run;

proc reg data=model_data;
    model lgd_corp_logit = d_euribor_l8;
run;




/* per instit */
proc reg data=model_data;
    model lgd_inst_logit = d_euribor;
run;

proc reg data=model_data;
    model lgd_inst_logit = d_euribor_l1;
run;

proc reg data=model_data;
    model lgd_inst_logit = d_euribor_l2;
run;

proc reg data=model_data;
    model lgd_inst_logit = d_euribor_l3;
run;

proc reg data=model_data;
    model lgd_inst_logit = d_euribor_l4;
run;

proc reg data=model_data;
    model lgd_inst_logit = d_euribor_l5;
run;

proc reg data=model_data;
    model lgd_inst_logit = d_euribor_l6;
run;

proc reg data=model_data;
    model lgd_inst_logit = d_euribor_l7;
run;

proc reg data=model_data;
    model lgd_inst_logit = d_euribor_l8;
run;




/* per retail */

proc reg data=model_data;
    model lgd_retail_logit = d_unemp;
run;

proc reg data=model_data;
    model lgd_retail_logit = d_unemp_l1;
run;

proc reg data=model_data;
    model lgd_retail_logit = d_unemp_l2;
run;

proc reg data=model_data;
    model lgd_retail_logit = d_unemp_l3;
run;

proc reg data=model_data;
    model lgd_retail_logit = d_unemp_l4;
run;

proc reg data=model_data;
    model lgd_retail_logit = d_unemp_l5;
run;

proc reg data=model_data;
    model lgd_retail_logit = d_unemp_l6;
run;

proc reg data=model_data;
    model lgd_retail_logit = d_unemp_l7;
run;

proc reg data=model_data;
    model lgd_retail_logit = d_unemp_l8;
run;


/* per pmi */

proc reg data=model_data;
    model lgd_pmi_logit = d_unemp;
run;

proc reg data=model_data;
    model lgd_pmi_logit = d_unemp_l1;
run;

proc reg data=model_data;
    model lgd_pmi_logit = d_unemp_l2;
run;

proc reg data=model_data;
    model lgd_pmi_logit = d_unemp_l3;
run;

proc reg data=model_data;
    model lgd_pmi_logit = d_unemp_l4;
run;

proc reg data=model_data;
    model lgd_pmi_logit = d_unemp_l5;
run;

proc reg data=model_data;
    model lgd_pmi_logit = d_unemp_l6;
run;

proc reg data=model_data;
    model lgd_pmi_logit = d_unemp_l7;
run;

proc reg data=model_data;
    model lgd_pmi_logit = d_unemp_l8;
run;


/* per corporate */

proc reg data=model_data;
    model lgd_corp_logit = d_unemp;
run;

proc reg data=model_data;
    model lgd_corp_logit = d_unemp_l1;
run;

proc reg data=model_data;
    model lgd_corp_logit = d_unemp_l2;
run;

proc reg data=model_data;
    model lgd_corp_logit = d_unemp_l3;
run;

proc reg data=model_data;
    model lgd_corp_logit = d_unemp_l4;
run;

proc reg data=model_data;
    model lgd_corp_logit = d_unemp_l5;
run;

proc reg data=model_data;
    model lgd_corp_logit = d_unemp_l6;
run;

proc reg data=model_data;
    model lgd_corp_logit = d_unemp_l7;
run;

proc reg data=model_data;
    model lgd_corp_logit = d_unemp_l8;
run;


/* per institutions */

proc reg data=model_data;
    model lgd_inst_logit = d_unemp;
run;

proc reg data=model_data;
    model lgd_inst_logit = d_unemp_l1;
run;

proc reg data=model_data;
    model lgd_inst_logit = d_unemp_l2;
run;

proc reg data=model_data;
    model lgd_inst_logit = d_unemp_l3;
run;

proc reg data=model_data;
    model lgd_inst_logit = d_unemp_l4;
run;

proc reg data=model_data;
    model lgd_inst_logit = d_unemp_l5;
run;

proc reg data=model_data;
    model lgd_inst_logit = d_unemp_l6;
run;

proc reg data=model_data;
    model lgd_inst_logit = d_unemp_l7;
run;

proc reg data=model_data;
    model lgd_inst_logit = d_unemp_l8;
run;


/* per retail */

proc reg data=model_data;
    model lgd_retail_logit = d_oil;
run;

proc reg data=model_data;
    model lgd_retail_logit = d_oil_l1;
run;

proc reg data=model_data;
    model lgd_retail_logit = d_oil_l2;
run;

proc reg data=model_data;
    model lgd_retail_logit = d_oil_l3;
run;

proc reg data=model_data;
    model lgd_retail_logit = d_oil_l4;
run;

proc reg data=model_data;
    model lgd_retail_logit = d_oil_l5;
run;

proc reg data=model_data;
    model lgd_retail_logit = d_oil_l6;
run;

proc reg data=model_data;
    model lgd_retail_logit = d_oil_l7;
run;

proc reg data=model_data;
    model lgd_retail_logit = d_oil_l8;
run;


/* per pmi */

proc reg data=model_data;
    model lgd_pmi_logit = d_oil;
run;

proc reg data=model_data;
    model lgd_pmi_logit = d_oil_l1;
run;

proc reg data=model_data;
    model lgd_pmi_logit = d_oil_l2;
run;

proc reg data=model_data;
    model lgd_pmi_logit = d_oil_l3;
run;

proc reg data=model_data;
    model lgd_pmi_logit = d_oil_l4;
run;

proc reg data=model_data;
    model lgd_pmi_logit = d_oil_l5;
run;

proc reg data=model_data;
    model lgd_pmi_logit = d_oil_l6;
run;

proc reg data=model_data;
    model lgd_pmi_logit = d_oil_l7;
run;

proc reg data=model_data;
    model lgd_pmi_logit = d_oil_l8;
run;


/* per corporate */

proc reg data=model_data;
    model lgd_corp_logit = d_oil;
run;

proc reg data=model_data;
    model lgd_corp_logit = d_oil_l1;
run;

proc reg data=model_data;
    model lgd_corp_logit = d_oil_l2;
run;

proc reg data=model_data;
    model lgd_corp_logit = d_oil_l3;
run;

proc reg data=model_data;
    model lgd_corp_logit = d_oil_l4;
run;

proc reg data=model_data;
    model lgd_corp_logit = d_oil_l5;
run;

proc reg data=model_data;
    model lgd_corp_logit = d_oil_l6;
run;

proc reg data=model_data;
    model lgd_corp_logit = d_oil_l7;
run;

proc reg data=model_data;
    model lgd_corp_logit = d_oil_l8;
run;


/* per institutions */

proc reg data=model_data;
    model lgd_inst_logit = d_oil;
run;

proc reg data=model_data;
    model lgd_inst_logit = d_oil_l1;
run;

proc reg data=model_data;
    model lgd_inst_logit = d_oil_l2;
run;

proc reg data=model_data;
    model lgd_inst_logit = d_oil_l3;
run;

proc reg data=model_data;
    model lgd_inst_logit = d_oil_l4;
run;

proc reg data=model_data;
    model lgd_inst_logit = d_oil_l5;
run;

proc reg data=model_data;
    model lgd_inst_logit = d_oil_l6;
run;

proc reg data=model_data;
    model lgd_inst_logit = d_oil_l7;
run;

proc reg data=model_data;
    model lgd_inst_logit = d_oil_l8;
run;



/* ===================================== */
/* RETAIL */
/* ===================================== */

proc reg data=model_data;
    model lgd_retail_logit = d_pilita;
run;

proc reg data=model_data;
    model lgd_retail_logit = dpil_ita_l1;
run;

proc reg data=model_data;
    model lgd_retail_logit = dpil_ita_l2;
run;

proc reg data=model_data;
    model lgd_retail_logit = dpil_ita_l3;
run;

proc reg data=model_data;
    model lgd_retail_logit = dpil_ita_l4;
run;

proc reg data=model_data;
    model lgd_retail_logit = dpil_ita_l5;
run;

proc reg data=model_data;
    model lgd_retail_logit = dpil_ita_l6;
run;

proc reg data=model_data;
    model lgd_retail_logit = dpil_ita_l7;
run;

proc reg data=model_data;
    model lgd_retail_logit = dpil_ita_l8;
run;


/* ===================================== */
/* PMI */
/* ===================================== */
proc reg data=model_data;
    model lgd_pmi_logit = d_pilita;
run;

proc reg data=model_data;
    model lgd_pmi_logit = dpil_ita_l1;
run;

proc reg data=model_data;
    model lgd_pmi_logit = dpil_ita_l2;
run;

proc reg data=model_data;
    model lgd_pmi_logit = dpil_ita_l3;
run;

proc reg data=model_data;
    model lgd_pmi_logit = dpil_ita_l4;
run;

proc reg data=model_data;
    model lgd_pmi_logit = dpil_ita_l5;
run;

proc reg data=model_data;
    model lgd_pmi_logit = dpil_ita_l6;
run;

proc reg data=model_data;
    model lgd_pmi_logit = dpil_ita_l7;
run;

proc reg data=model_data;
    model lgd_pmi_logit = dpil_ita_l8;
run;

/* ===================================== */
/* CORPORATE */
/* ===================================== */

proc reg data=model_data;
    model lgd_corp_logit = d_pilita;
run;

proc reg data=model_data;
    model lgd_corp_logit = dpil_ita_l1;
run;

proc reg data=model_data;
    model lgd_corp_logit = dpil_ita_l2;
run;

proc reg data=model_data;
    model lgd_corp_logit = dpil_ita_l3;
run;

proc reg data=model_data;
    model lgd_corp_logit = dpil_ita_l4;
run;

proc reg data=model_data;
    model lgd_corp_logit = dpil_ita_l5;
run;

proc reg data=model_data;
    model lgd_corp_logit = dpil_ita_l6;
run;

proc reg data=model_data;
    model lgd_corp_logit = dpil_ita_l7;
run;

proc reg data=model_data;
    model lgd_corp_logit = dpil_ita_l8;
run;


/* ===================================== */
/* INSTITUTIONS */
/* ===================================== */
proc reg data=model_data;
    model lgd_inst_logit = d_pilita;
run;

proc reg data=model_data;
    model lgd_inst_logit = dpil_ita_l1;
run;

proc reg data=model_data;
    model lgd_inst_logit = dpil_ita_l2;
run;

proc reg data=model_data;
    model lgd_inst_logit = dpil_ita_l3;
run;

proc reg data=model_data;
    model lgd_inst_logit = dpil_ita_l4;
run;

proc reg data=model_data;
    model lgd_inst_logit = dpil_ita_l5;
run;

proc reg data=model_data;
    model lgd_inst_logit = dpil_ita_l6;
run;

proc reg data=model_data;
    model lgd_inst_logit = dpil_ita_l7;
run;

proc reg data=model_data;
    model lgd_inst_logit = dpil_ita_l8;
run;


/* ===================================== */
/* RETAIL */
/* ===================================== */

proc reg data=model_data;
    model lgd_retail_logit = d_pilue;
run;

proc reg data=model_data;
    model lgd_retail_logit = dpil_ue_l1;
run;

proc reg data=model_data;
    model lgd_retail_logit = dpil_ue_l2;
run;

proc reg data=model_data;
    model lgd_retail_logit = dpil_ue_l3;
run;

proc reg data=model_data;
    model lgd_retail_logit = dpil_ue_l4;
run;

proc reg data=model_data;
    model lgd_retail_logit = dpil_ue_l5;
run;

proc reg data=model_data;
    model lgd_retail_logit = dpil_ue_l6;
run;

proc reg data=model_data;
    model lgd_retail_logit = dpil_ue_l7;
run;

proc reg data=model_data;
    model lgd_retail_logit = dpil_ue_l8;
run;


/* ===================================== */
/* PMI */
/* ===================================== */

proc reg data=model_data;
    model lgd_pmi_logit = d_pilue;
run;

proc reg data=model_data;
    model lgd_pmi_logit = dpil_ue_l1;
run;

proc reg data=model_data;
    model lgd_pmi_logit = dpil_ue_l2;
run;

proc reg data=model_data;
    model lgd_pmi_logit = dpil_ue_l3;
run;

proc reg data=model_data;
    model lgd_pmi_logit = dpil_ue_l4;
run;

proc reg data=model_data;
    model lgd_pmi_logit = dpil_ue_l5;
run;

proc reg data=model_data;
    model lgd_pmi_logit = dpil_ue_l6;
run;

proc reg data=model_data;
    model lgd_pmi_logit = dpil_ue_l7;
run;

proc reg data=model_data;
    model lgd_pmi_logit = dpil_ue_l8;
run;


/* ===================================== */
/* CORPORATE */
/* ===================================== */

proc reg data=model_data;
    model lgd_corp_logit = d_pilue;
run;

proc reg data=model_data;
    model lgd_corp_logit = dpil_ue_l1;
run;

proc reg data=model_data;
    model lgd_corp_logit = dpil_ue_l2;
run;

proc reg data=model_data;
    model lgd_corp_logit = dpil_ue_l3;
run;

proc reg data=model_data;
    model lgd_corp_logit = dpil_ue_l4;
run;

proc reg data=model_data;
    model lgd_corp_logit = dpil_ue_l5;
run;

proc reg data=model_data;
    model lgd_corp_logit = dpil_ue_l6;
run;

proc reg data=model_data;
    model lgd_corp_logit = dpil_ue_l7;
run;

proc reg data=model_data;
    model lgd_corp_logit = dpil_ue_l8;
run;


/* ===================================== */
/* INSTITUTIONS */
/* ===================================== */

proc reg data=model_data;
    model lgd_inst_logit = d_pilue;
run;

proc reg data=model_data;
    model lgd_inst_logit = dpil_ue_l1;
run;

proc reg data=model_data;
    model lgd_inst_logit = dpil_ue_l2;
run;

proc reg data=model_data;
    model lgd_inst_logit = dpil_ue_l3;
run;

proc reg data=model_data;
    model lgd_inst_logit = dpil_ue_l4;
run;

proc reg data=model_data;
    model lgd_inst_logit = dpil_ue_l5;
run;

proc reg data=model_data;
    model lgd_inst_logit = dpil_ue_l6;
run;

proc reg data=model_data;
    model lgd_inst_logit = dpil_ue_l7;
run;

proc reg data=model_data;
    model lgd_inst_logit = dpil_ue_l8;
run;



/* ===================================== */
/* RETAIL */
/* ===================================== */

proc reg data=model_data;
    model lgd_retail_logit = pil_ue;
run;

proc reg data=model_data;
    model lgd_retail_logit = pil_ue_l1;
run;

proc reg data=model_data;
    model lgd_retail_logit = pil_ue_l2;
run;

proc reg data=model_data;
    model lgd_retail_logit = pil_ue_l3;
run;

proc reg data=model_data;
    model lgd_retail_logit = pil_ue_l4;
run;

proc reg data=model_data;
    model lgd_retail_logit = pil_ue_l5;
run;

proc reg data=model_data;
    model lgd_retail_logit = pil_ue_l6;
run;

proc reg data=model_data;
    model lgd_retail_logit = pil_ue_l7;
run;

proc reg data=model_data;
    model lgd_retail_logit = pil_ue_l8;
run;


/* ===================================== */
/* PMI */
/* ===================================== */

proc reg data=model_data;
    model lgd_pmi_logit = pil_ue;
run;

proc reg data=model_data;
    model lgd_pmi_logit = pil_ue_l1;
run;

proc reg data=model_data;
    model lgd_pmi_logit = pil_ue_l2;
run;

proc reg data=model_data;
    model lgd_pmi_logit = pil_ue_l3;
run;

proc reg data=model_data;
    model lgd_pmi_logit = pil_ue_l4;
run;

proc reg data=model_data;
    model lgd_pmi_logit = pil_ue_l5;
run;

proc reg data=model_data;
    model lgd_pmi_logit = pil_ue_l6;
run;

proc reg data=model_data;
    model lgd_pmi_logit = pil_ue_l7;
run;

proc reg data=model_data;
    model lgd_pmi_logit = pil_ue_l8;
run;


/* ===================================== */
/* CORPORATE */
/* ===================================== */

proc reg data=model_data;
    model lgd_corp_logit = pil_ue;
run;

proc reg data=model_data;
    model lgd_corp_logit = pil_ue_l1;
run;

proc reg data=model_data;
    model lgd_corp_logit = pil_ue_l2;
run;

proc reg data=model_data;
    model lgd_corp_logit = pil_ue_l3;
run;

proc reg data=model_data;
    model lgd_corp_logit = pil_ue_l4;
run;

proc reg data=model_data;
    model lgd_corp_logit = pil_ue_l5;
run;

proc reg data=model_data;
    model lgd_corp_logit = pil_ue_l6;
run;

proc reg data=model_data;
    model lgd_corp_logit = pil_ue_l7;
run;

proc reg data=model_data;
    model lgd_corp_logit = pil_ue_l8;
run;


/* ===================================== */
/* INSTITUTIONS */
/* ===================================== */

proc reg data=model_data;
    model lgd_inst_logit = pil_ue;
run;

proc reg data=model_data;
    model lgd_inst_logit = pil_ue_l1;
run;

proc reg data=model_data;
    model lgd_inst_logit = pil_ue_l2;
run;

proc reg data=model_data;
    model lgd_inst_logit = pil_ue_l3;
run;

proc reg data=model_data;
    model lgd_inst_logit = pil_ue_l4;
run;

proc reg data=model_data;
    model lgd_inst_logit = pil_ue_l5;
run;

proc reg data=model_data;
    model lgd_inst_logit = pil_ue_l6;
run;

proc reg data=model_data;
    model lgd_inst_logit = pil_ue_l7;
run;

proc reg data=model_data;
    model lgd_inst_logit = pil_ue_l8;
run;




/* ===================================== */
/* RETAIL */
/* ===================================== */

proc reg data=model_data;
    model lgd_retail_logit = d_def;
run;

proc reg data=model_data;
    model lgd_retail_logit = d_def_l1;
run;

proc reg data=model_data;
    model lgd_retail_logit = d_def_l2;
run;

proc reg data=model_data;
    model lgd_retail_logit = d_def_l3;
run;

proc reg data=model_data;
    model lgd_retail_logit = d_def_l4;
run;

proc reg data=model_data;
    model lgd_retail_logit = d_def_l5;
run;

proc reg data=model_data;
    model lgd_retail_logit = d_def_l6;
run;

proc reg data=model_data;
    model lgd_retail_logit = d_def_l7;
run;

proc reg data=model_data;
    model lgd_retail_logit = d_def_l8;
run;


/* ===================================== */
/* PMI */
/* ===================================== */

proc reg data=model_data;
    model lgd_pmi_logit = d_def;
run;

proc reg data=model_data;
    model lgd_pmi_logit = d_def_l1;
run;

proc reg data=model_data;
    model lgd_pmi_logit = d_def_l2;
run;

proc reg data=model_data;
    model lgd_pmi_logit = d_def_l3;
run;

proc reg data=model_data;
    model lgd_pmi_logit = d_def_l4;
run;

proc reg data=model_data;
    model lgd_pmi_logit = d_def_l5;
run;

proc reg data=model_data;
    model lgd_pmi_logit = d_def_l6;
run;

proc reg data=model_data;
    model lgd_pmi_logit = d_def_l7;
run;

proc reg data=model_data;
    model lgd_pmi_logit = d_def_l8;
run;


/* ===================================== */
/* CORPORATE */
/* ===================================== */

proc reg data=model_data;
    model lgd_corp_logit = d_def;
run;

proc reg data=model_data;
    model lgd_corp_logit = d_def_l1;
run;

proc reg data=model_data;
    model lgd_corp_logit = d_def_l2;
run;

proc reg data=model_data;
    model lgd_corp_logit = d_def_l3;
run;

proc reg data=model_data;
    model lgd_corp_logit = d_def_l4;
run;

proc reg data=model_data;
    model lgd_corp_logit = d_def_l5;
run;

proc reg data=model_data;
    model lgd_corp_logit = d_def_l6;
run;

proc reg data=model_data;
    model lgd_corp_logit = d_def_l7;
run;

proc reg data=model_data;
    model lgd_corp_logit = d_def_l8;
run;


/* ===================================== */
/* INSTITUTIONS */
/* ===================================== */

proc reg data=model_data;
    model lgd_inst_logit = d_def;
run;

proc reg data=model_data;
    model lgd_inst_logit = d_def_l1;
run;

proc reg data=model_data;
    model lgd_inst_logit = d_def_l2;
run;

proc reg data=model_data;
    model lgd_inst_logit = d_def_l3;
run;

proc reg data=model_data;
    model lgd_inst_logit = d_def_l4;
run;

proc reg data=model_data;
    model lgd_inst_logit = d_def_l5;
run;

proc reg data=model_data;
    model lgd_inst_logit = d_def_l6;
run;

proc reg data=model_data;
    model lgd_inst_logit = d_def_l7;
run;

proc reg data=model_data;
    model lgd_inst_logit = d_def_l8;
run;


/* la significatività fa schifo per tutti */






proc reg data=model_data;
    model lgd_retail_logit =
          d_euribor_l2 ;
run; 
/* 0.1810, */



/*retail con euribor e def */

proc reg data=model_data;
    model lgd_retail_logit =
          d_euribor_l2
          d_def_l3 /vif;
run;
/*0.1853, VIF ok */


proc reg data=model_data;
    model lgd_retail_logit =
          d_euribor_l2
          d_def_l7 /vif;
run;
/* 0.1901, VIF ok*/




/* retail, con euribor e oil */


proc reg data=model_data;
    model lgd_retail_logit =
          d_euribor_l2
          d_oil_l1 /vif;
run;
/* 0.2009, VIF ok */


proc reg data=model_data;
    model lgd_retail_logit =
          d_euribor_l2
          d_oil_l2 /vif;
run;
/* 0.2221, VIF ok */


proc reg data=model_data;
    model lgd_retail_logit =
          d_euribor_l2
          d_oil_l3 /vif;
run;
/* 0.1917, VIF ok */


proc reg data=model_data;
    model lgd_retail_logit =
          d_euribor_l2
          d_oil_l4 /vif;
run;
/* 0.2011, VIF ok */


proc reg data=model_data;
    model lgd_retail_logit =
          d_euribor_l2
          d_oil_l5 /vif;
run;
/* 0.1830, VIF ok */


proc reg data=model_data;
    model lgd_retail_logit =
          d_euribor_l2
          d_oil_l7 /vif;
run;
/* 0.2109, VIF ok */


proc reg data=model_data;
    model lgd_retail_logit =
          d_euribor_l2
          d_oil_l8 /vif;
run;
/* 0.2411, VIF ok */





/* retail con euribor e pil ita*/

proc reg data=model_data;
    model lgd_retail_logit =
          d_euribor_l2;
run;
/* 0.1810 */



proc reg data=model_data;
    model lgd_retail_logit =
          d_euribor_l2
          dpil_ita_l7 / vif;
run;
/* 0.1893, VIF ok */


proc reg data=model_data;
    model lgd_retail_logit =
          d_euribor_l2
          dpil_ita_l8 / vif;
run;
/* 0.1819, VIF ok */


/*retail con euribor e pilue*/

proc reg data=model_data;
    model lgd_retail_logit =
          d_euribor_l2
          dpil_ue_l7/ vif;
run;
/* 0.1837, vif ok */


proc reg data=model_data;
    model lgd_retail_logit =
          d_euribor_l2
          dpil_ue_l8/ vif;
run;
/* 0.1834, vif ok */





/* retail con euribor e unemplyment */

proc reg data=model_data;
    model lgd_retail_logit =
          d_euribor_l2
          d_unemp_l5 / vif;
run;
/* 0.1827, vif ok */


proc reg data=model_data;
    model lgd_retail_logit =
          d_euribor_l2
          d_unemp_l6 / vif;
run;
/* 0.2008, vif ok */


proc reg data=model_data;
    model lgd_retail_logit =
          d_euribor_l2
          d_unemp_l7 / vif;
run;
/* 0.2079, vif ok */




/* retail con euribor e btp */

proc reg data=model_data;
    model lgd_retail_logit =
          d_euribor_l2
          d_btp_l5 / vif;
run;
/* 0.2598, vif ok */


proc reg data=model_data;
    model lgd_retail_logit =
          d_euribor_l2
          d_btp_l6 / vif;
run;
/* 0.3530, vif ok */


proc reg data=model_data;
    model lgd_retail_logit =
          d_euribor_l2
          d_btp_l7 / vif;
run;
/* 0.3257, vif ok */


proc reg data=model_data;
    model lgd_retail_logit =
          d_euribor_l2
          d_btp_l8 / vif;
run;

/* 0.2158, vif ok */









proc reg data=model_data;
    model lgd_corp_logit =
          d_euribor_l2 ;
run; 
/* 0.2695, */



/*corporate con euribor e def */

proc reg data=model_data;
    model lgd_corp_logit =
          d_euribor_l2
          d_def_l4 /vif;
run;
/*0.2718, VIF ok */


proc reg data=model_data;
    model lgd_corp_logit =
          d_euribor_l2
          d_def_l5 /vif;
run;
/*0.3057, VIF ok */


proc reg data=model_data;
    model lgd_corp_logit =
          d_euribor_l2
          d_def_l6 /vif;
run;
/*0.3305, VIF ok */


proc reg data=model_data;
    model lgd_corp_logit =
          d_euribor_l2
          d_def_l7 /vif;
run;
/*0.3808, VIF ok */


proc reg data=model_data;
    model lgd_corp_logit =
          d_euribor_l2
          d_def_l8 /vif;
run;
/*0.3996, VIF ok */




/*corporate con euribor e oil, vs 0.2695 */

proc reg data=model_data;
    model lgd_corp_logit =
          d_euribor_l2
          d_oil_l1 /vif;
run;
/*0.3394, VIF ok, quasi sign */

proc reg data=model_data;
    model lgd_corp_logit =
          d_euribor_l2
          d_oil_l2 /vif;
run;
/*0.3963, VIF ok, sign */


proc reg data=model_data;
    model lgd_corp_logit =
          d_euribor_l2
          d_oil_l3 /vif;
run;
/* 0.2979, non sign , vif ok */


proc reg data=model_data;
    model lgd_corp_logit =
          d_euribor_l2
          d_oil_l4 /vif;
run;
/* 0.2722, non sign , vif ok */


proc reg data=model_data;
    model lgd_corp_logit =
          d_euribor_l2
          d_oil_l5 /vif;
run;
/* 0.3056, non sign , vif ok */


proc reg data=model_data;
    model lgd_corp_logit =
          d_euribor_l2
          d_oil_l6 /vif;
run;
/* 0.3352, non sign , vif ok */


proc reg data=model_data;
    model lgd_corp_logit =
          d_euribor_l2
          d_oil_l7 /vif;
run;
/* 0.4028, non sign , vif ok */


proc reg data=model_data;
    model lgd_corp_logit =
          d_euribor_l2
          d_oil_l8 /vif;
run;
/* 0.3986, non sign , vif ok */



/* corporate con euribor e pilita, vs 0.2695 */

proc reg data=model_data;
    model lgd_corp_logit =
          d_euribor_l2
          dpil_ita_l4 /vif;
run;
/* 0.2717, non sign , vif ok */

proc reg data=model_data;
    model lgd_corp_logit =
          d_euribor_l2
          dpil_ita_l5 /vif;
run;
/* 0.3076, non sign , vif ok */



proc reg data=model_data;
    model lgd_corp_logit =
          d_euribor_l2
          dpil_ita_l6 /vif;
run;
/* 0.3293, non sign , vif ok */

proc reg data=model_data;
    model lgd_corp_logit =
          d_euribor_l2
          dpil_ita_l7 /vif;
run;
/* 0.3803, non sign , vif ok */

proc reg data=model_data;
    model lgd_corp_logit =
          d_euribor_l2
          dpil_ita_l8 /vif;
run;
/* 0.4021, non sign , vif ok */





/* da qua in poi R^2 non  correttissimi */
/* corporate con euribor e pilue, vs 0.2695 */

proc reg data=model_data;
    model lgd_corp_logit =
          d_euribor_l2
          dpil_ue_l4 /vif;
run;
/* 0.2721, non sign , vif ok */

proc reg data=model_data;
    model lgd_corp_logit =
          d_euribor_l2
          dpil_ue_l5 /vif;
run;
/* 0.3065, non sign , vif ok */


proc reg data=model_data;
    model lgd_corp_logit =
          d_euribor_l2
          dpil_ue_l6 /vif;
run;
/* 0.3288, non sign , vif ok */


proc reg data=model_data;
    model lgd_corp_logit =
          d_euribor_l2
          dpil_ue_l7 /vif;
run;
/* 0.3795, non sign , vif ok */


proc reg data=model_data;
    model lgd_corp_logit =
          d_euribor_l2
          dpil_ue_l8 /vif;
run;
/* 0.4014, non sign , vif ok */



/* corporate con euribor e unempl, vs 0.2695 */

proc reg data=model_data;
    model lgd_corp_logit =
          d_euribor_l2
          d_unemp_l4 /vif;
run;
/* 0.2718, non sign , vif ok */



proc reg data=model_data;
    model lgd_corp_logit =
          d_euribor_l2
          d_unemp_l5 /vif;
run;
/* 0.3309, non sign , vif ok */



proc reg data=model_data;
    model lgd_corp_logit =
          d_euribor_l2
          d_unemp_l6 /vif;
run;
/* 0.3293, non sign , vif ok */

proc reg data=model_data;
    model lgd_corp_logit =
          d_euribor_l2
          d_unemp_l7 /vif;
run;
/* 0.3881, non sign , vif ok */

proc reg data=model_data;
    model lgd_corp_logit =
          d_euribor_l2
          d_unemp_l8 /vif;
run;
/* 0.4009, non sign , vif ok */




/* corporate con euribor e btp, vs 0.2695 */

proc reg data=model_data;
    model lgd_corp_logit =
          d_euribor_l2
          d_btp /vif;
run;
/* 0.3956, sign , vif ok */


proc reg data=model_data;
    model lgd_corp_logit =
          d_euribor_l2
          d_btp_l1 /vif;
run;
/* 0.3448, quasi sign , vif ok */

proc reg data=model_data;
    model lgd_corp_logit =
          d_euribor_l2
          d_btp_l2 /vif;
run;
/* 0.2876, non sign , vif ok */


proc reg data=model_data;
    model lgd_corp_logit =
          d_euribor_l2
          d_btp_l3 /vif;
run;
/* 0.2872, non sign , vif ok */


proc reg data=model_data;
    model lgd_corp_logit =
          d_euribor_l2
          d_btp_l4 /vif;
run;
/* 0.2806, non sign , vif ok */

proc reg data=model_data;
    model lgd_corp_logit =
          d_euribor_l2
          d_btp_l5 /vif;
run;
/* 0.3151, non sign , vif ok */


proc reg data=model_data;
    model lgd_corp_logit =
          d_euribor_l2
          d_btp_l6 /vif;
run;
/* 0.3845, non sign , vif ok */

proc reg data=model_data;
    model lgd_corp_logit =
          d_euribor_l2
          d_btp_l7 /vif;
run;
/* 0.4873, quasi sign , vif ok */

proc reg data=model_data;
    model lgd_corp_logit =
          d_euribor_l2
          d_btp_l8 /vif;
run;
/* 0.4421, non sign , vif ok */





/* pmi con euribor --> 0.3490*/

proc reg data=model_data;
    model lgd_pmi_logit =
          d_euribor_l2;
run;

/* pmi con euribor e def */
proc reg data=model_data;
    model lgd_pmi_logit =
          d_euribor_l2
          d_def_l4/vif;
run;
/* 0.3577, non sign , vif ok */

proc reg data=model_data;
    model lgd_pmi_logit =
          d_euribor_l2
          d_def_l5/vif;
run;
/* 0.3881, non sign , vif ok */


proc reg data=model_data;
    model lgd_pmi_logit =
          d_euribor_l2
          d_def_l6/vif;
run;
/* 0.4110, non sign , vif ok */

proc reg data=model_data;
    model lgd_pmi_logit =
          d_euribor_l2
          d_def_l7/vif;
run;
/* 0.4312, non sign , vif ok */

proc reg data=model_data;
    model lgd_pmi_logit =
          d_euribor_l2
          d_def_l8/vif;
run;
/* 0.4705, non sign , vif ok */




/* pmi con euribor --> 0.3490*/
/* pmi con euribor e oil */
proc reg data=model_data;
    model lgd_pmi_logit =
          d_euribor_l2
          d_oil_l1/vif;
run;
/* 0.4216, sign , vif ok */


proc reg data=model_data;
    model lgd_pmi_logit =
          d_euribor_l2
          d_oil_l2/vif;
run;
/* 0.4330, sign , vif ok */

proc reg data=model_data;
    model lgd_pmi_logit =
          d_euribor_l2
          d_oil_l3/vif;
run;
/* 0.3885, non sign , vif ok */

proc reg data=model_data;
    model lgd_pmi_logit =
          d_euribor_l2
          d_oil_l4/vif;
run;
/* 0.3754, non sign , vif ok */


proc reg data=model_data;
    model lgd_pmi_logit =
          d_euribor_l2
          d_oil_l5/vif;
run;
/* 0.385, non sign , vif ok */


proc reg data=model_data;
    model lgd_pmi_logit =
          d_euribor_l2
          d_oil_l6/vif;
run;
/* 0.4345, non sign , vif ok */


proc reg data=model_data;
    model lgd_pmi_logit =
          d_euribor_l2
          d_oil_l7/vif;
run;
/* 0.4861, non sign , vif ok */


proc reg data=model_data;
    model lgd_pmi_logit =
          d_euribor_l2
          d_oil_l8/vif;
run;
/* 0.4832, non sign , vif ok */




/* pmi con euribor --> 0.3490*/
/* pmi con euribor e pilita */
proc reg data=model_data;
    model lgd_pmi_logit =
          d_euribor_l2
          dpil_ita_l4/vif;
run;
/* 0.3576, non sign , vif ok */


proc reg data=model_data;
    model lgd_pmi_logit =
          d_euribor_l2
          dpil_ita_l5/vif;
run;
/* 0.3840, non sign , vif ok */


proc reg data=model_data;
    model lgd_pmi_logit =
          d_euribor_l2
          dpil_ita_l6/vif;
run;
/* 0.4028, non sign , vif ok */


proc reg data=model_data;
    model lgd_pmi_logit =
          d_euribor_l2
          dpil_ita_l7/vif;
run;
/* 0.4325, non sign , vif ok */


proc reg data=model_data;
    model lgd_pmi_logit =
          d_euribor_l2
          dpil_ita_l8/vif;
run;
/* 0.4695, non sign , vif ok */



/* pmi con euribor --> 0.3490*/
/* pmi con euribor e pilue */


proc reg data=model_data;
    model lgd_pmi_logit =
          d_euribor_l2
          dpil_ue_l4/vif;
run;
/* 0.3575, non sign , vif ok */


proc reg data=model_data;
    model lgd_pmi_logit =
          d_euribor_l2
          dpil_ue_l5/vif;
run;
/* 0.4028, non sign , vif ok */


proc reg data=model_data;
    model lgd_pmi_logit =
          d_euribor_l2
          dpil_ue_l6/vif;
run;
/* 0.4024, non sign , vif ok */

proc reg data=model_data;
    model lgd_pmi_logit =
          d_euribor_l2
          dpil_ue_l7/vif;
run;
/* 0.4323, non sign , vif ok */


proc reg data=model_data;
    model lgd_pmi_logit =
          d_euribor_l2
          dpil_ue_l8/vif;
run;
/* 0.4694, non sign , vif ok */





/* pmi con euribor --> 0.3490*/
/* pmi con euribor e unemp */

proc reg data=model_data;
    model lgd_pmi_logit =
          d_euribor_l2
          d_unemp_l2 /vif;
run;
/* 0.3532, non sign , vif ok */


proc reg data=model_data;
    model lgd_pmi_logit =
          d_euribor_l2
          d_unemp_l4 /vif;
run;
/* 0.3576, non sign , vif ok */



proc reg data=model_data;
    model lgd_pmi_logit =
          d_euribor_l2
          d_unemp_l5 /vif;
run;
/* 0.3858, non sign , vif ok */

proc reg data=model_data;
    model lgd_pmi_logit =
          d_euribor_l2
          d_unemp_l6 /vif;
run;
/* 0.4070, non sign , vif ok */

proc reg data=model_data;
    model lgd_pmi_logit =
          d_euribor_l2
          d_unemp_l7 /vif;
run;
/* 0.4636, non sign , vif ok */

proc reg data=model_data;
    model lgd_pmi_logit =
          d_euribor_l2
          d_unemp_l8 /vif;
run;
/* 0.4836, non sign , vif ok */



/* pmi con euribor --> 0.3490*/
/* pmi con euribor e btp */

proc reg data=model_data;
    model lgd_pmi_logit =
          d_euribor_l2
          d_btp /vif;
run;
/* 0.5606, sign , vif ok */


proc reg data=model_data;
    model lgd_pmi_logit =
          d_euribor_l2
          d_btp_l1 /vif;
run;
/* 0.5155, sign , vif ok */

proc reg data=model_data;
    model lgd_pmi_logit =
          d_euribor_l2
          d_btp_l2 /vif;
run;
/* 0.4102, quasi sign , vif ok */

proc reg data=model_data;
    model lgd_pmi_logit =
          d_euribor_l2
          d_btp_l4 /vif;
run;
/* 0.3730, non sign , vif ok */


proc reg data=model_data;
    model lgd_pmi_logit =
          d_euribor_l2
          d_btp_l5 /vif;
run;
/* 0.4010, non sign , vif ok */

proc reg data=model_data;
    model lgd_pmi_logit =
          d_euribor_l2
          d_btp_l6 /vif;
run;
/* 0.4577, non sign , vif ok */

proc reg data=model_data;
    model lgd_pmi_logit =
          d_euribor_l2
          d_btp_l7 /vif;
run;
/* 0.4548, non sign , vif ok */

proc reg data=model_data;
    model lgd_pmi_logit =
          d_euribor_l2
          d_btp_l8 /vif;
run;
/* 0.4676, non sign , vif ok */
























/* instit con euribor --> 0.1158*/

proc reg data=model_data;
    model lgd_inst_logit =
          d_euribor_l2;
run;



/* inst con euribor e def */
proc reg data=model_data;
    model lgd_inst_logit =
          d_euribor_l2
          d_def_l4/vif;
run;
/* 0.1204, non sign , vif ok */


proc reg data=model_data;
    model lgd_inst_logit =
          d_euribor_l2
          d_def_l5/vif;
run;
/* 0.1645, non sign , vif ok */


/* inst con euribor e def */
proc reg data=model_data;
    model lgd_inst_logit =
          d_euribor_l2
          d_def_l6/vif;
run;
/* 0.2410, non sign , vif ok */


proc reg data=model_data;
    model lgd_inst_logit =
          d_euribor_l2
          d_def_l7/vif;
run;
/* 0.2794, non sign , vif ok */

proc reg data=model_data;
    model lgd_inst_logit =
          d_euribor_l2
          d_def_l8/vif;
run;
/* 0.31, non sign , vif ok */





/* instit con euribor --> 0.1158*/
/* pmi con euribor e oil */

proc reg data=model_data;
    model lgd_inst_logit =
          d_euribor_l2
          d_oil_l4/vif;
run;
/* 0.1373, non sign , vif ok */


proc reg data=model_data;
    model lgd_inst_logit =
          d_euribor_l2
          d_oil_l5/vif;
run;
/* 0.187, non sign , vif ok */


proc reg data=model_data;
    model lgd_inst_logit =
          d_euribor_l2
          d_oil_l6/vif;
run;
/* 0.3182, non sign , vif ok */


proc reg data=model_data;
    model lgd_inst_logit =
          d_euribor_l2
          d_oil_l7/vif;
run;
/* 0.3448, non sign , vif ok */


proc reg data=model_data;
    model lgd_inst_logit =
          d_euribor_l2
          d_oil_l8/vif;
run;
/* 0.3696, non sign , vif ok */







/* instit con euribor --> 0.1158*/

proc reg data=model_data;
    model lgd_inst_logit =
          d_euribor_l2
          dpil_ita_l4/vif;
run;
/* 0.1196, non sign , vif ok */


proc reg data=model_data;
    model lgd_inst_logit =
          d_euribor_l2
          dpil_ita_l5/vif;
run;
/* 0.1582, non sign , vif ok */


proc reg data=model_data;
    model lgd_inst_logit =
          d_euribor_l2
          dpil_ita_l6/vif;
run;
/* 0.2403, non sign , vif ok */


proc reg data=model_data;
    model lgd_inst_logit =
          d_euribor_l2
          dpil_ita_l7/vif;
run;
/* 0.2769, non sign , vif ok */


proc reg data=model_data;
    model lgd_inst_logit =
          d_euribor_l2
          dpil_ita_l8/vif;
run;
/* 0.3128, non sign , vif ok */




/* instit con euribor --> 0.1158*/


proc reg data=model_data;
    model lgd_inst_logit =
          d_euribor_l2
          dpil_ue_l4/vif;
run;
/* 0.1199, non sign , vif ok */


proc reg data=model_data;
    model lgd_inst_logit =
          d_euribor_l2
          dpil_ue_l5/vif;
run;
/* 0.1579, non sign , vif ok */


proc reg data=model_data;
    model lgd_inst_logit =
          d_euribor_l2
          dpil_ue_l6/vif;
run;
/* 0.2401, non sign , vif ok */

proc reg data=model_data;
    model lgd_inst_logit =
          d_euribor_l2
          dpil_ue_l7/vif;
run;
/* 0.2766, non sign , vif ok */

proc reg data=model_data;
    model lgd_inst_logit =
          d_euribor_l2
          dpil_ue_l8/vif;
run;
/* 0.3123, non sign , vif ok */



/* instit con euribor --> 0.1158*/


proc reg data=model_data;
    model lgd_inst_logit =
          d_euribor_l2
          d_unemp_l4/vif;
run;
/* 0.1305, non sign , vif ok */

proc reg data=model_data;
    model lgd_inst_logit =
          d_euribor_l2
          d_unemp_l5/vif;
run;
/* 0.2176, non sign , vif ok */

proc reg data=model_data;
    model lgd_inst_logit =
          d_euribor_l2
          d_unemp_l6/vif;
run;
/* 0.2428, non sign , vif ok */

proc reg data=model_data;
    model lgd_inst_logit =
          d_euribor_l2
          d_unemp_l7/vif;
run;
/* 0.2849, non sign , vif ok */

proc reg data=model_data;
    model lgd_inst_logit =
          d_euribor_l2
          d_unemp_l8/vif;
run;
/* 0.3093, non sign , vif ok */



/* inst con euribor --> 0.1158*/
/* pmi con euribor e btp */

proc reg data=model_data;
    model lgd_inst_logit =
          d_euribor_l2
          d_btp /vif;
run;
/* 0.1355, non sign , vif ok */


proc reg data=model_data;
    model lgd_inst_logit =
          d_euribor_l2
          d_btp_l1 /vif;
run;
/* 0.2395, sign , vif ok */

proc reg data=model_data;
    model lgd_inst_logit =
          d_euribor_l2
          d_btp_l2 /vif;
run;
/* 0.3730, sign , vif ok */

proc reg data=model_data;
    model lgd_inst_logit =
          d_euribor_l2
          d_btp_l3 /vif;
run;
/* 0.3319, sign , vif ok */


proc reg data=model_data;
    model lgd_inst_logit =
          d_euribor_l2
          d_btp_l4 /vif;
run;
/* 0.3264, sign , vif ok */

proc reg data=model_data;
    model lgd_inst_logit =
          d_euribor_l2
          d_btp_l5 /vif;
run;
/* 0.2377, non sign , vif ok */

proc reg data=model_data;
    model lgd_inst_logit =
          d_euribor_l2
          d_btp_l6 /vif;
run;
/* 0.2471, non sign , vif ok */


proc reg data=model_data;
    model lgd_inst_logit =
          d_euribor_l2
          d_btp_l7 /vif;
run;
/* 0.2760, non sign , vif ok */

proc reg data=model_data;
    model lgd_inst_logit =
          d_euribor_l2
          d_btp_l8 /vif;
run;
/* 0.3252, non sign , vif ok */








data model_data;
    set model_data;

    if year(date_sas) in (2020, 2021) then dummy_covid=1;
    else dummy_covid=0;
run;

proc reg data=model_data;
    model lgd_retail_logit =
          d_euribor_l2
          d_oil_l2
          d_btp_l1
          dummy_covid
          / vif;
run;
quit;
/* R^2 adj = 37,09, oil e btp non sign */

proc reg data=model_data;
    model lgd_pmi_logit =
          d_euribor_l2
          d_oil_l2
          d_btp_l1
          dummy_covid
          / vif;
run;
quit;

/* R^2 adj = 56,19, oil e dummy non sign */


proc reg data=model_data;
    model lgd_inst_logit =
          d_euribor_l2
          d_oil_l2
          d_btp_l1
          dummy_covid
          / vif;
run;
quit;

/* R^2 adj = 28,11, oil btp dummy non sign */

proc reg data=model_data;
    model lgd_corp_logit =
          d_euribor_l2
          d_oil_l2
          d_btp_l1
          dummy_covid
          / vif;
run;
quit;
/* R^2 adj = 44,27 , spòp euribor sign */



/*provo senza dummy */

proc reg data=model_data;
    model lgd_retail_logit =
          d_euribor_l2
          d_oil_l2
          d_btp_l1
          
          / vif;
run;
quit;
/* R^2 adj = 19, oil e btp non sign */

proc reg data=model_data;
    model lgd_pmi_logit =
          d_euribor_l2
          d_oil_l2
          d_btp_l1
          
          / vif;
run;
quit;

/* R^2 adj = 52,09 */


proc reg data=model_data;
    model lgd_inst_logit =
          d_euribor_l2
          d_oil_l2
          d_btp_l1
          
          / vif;
run;
quit;

/* R^2 adj = 17.96, oil btp dummy sign */

proc reg data=model_data;
    model lgd_corp_logit =
          d_euribor_l2
          d_oil_l2
          d_btp_l1
          
          / vif;
run;
quit;
/* R^2 adj = 43.29 , solo euribor sign */


/* peggiorano tutti */


proc reg data=model_data;
    model lgd_retail_logit =
          d_euribor_l2
          d_oil_l2
          d_btp_l1
          dummy_covid
		  d_def_l7
          / vif;
run;
quit;
/* R^2 adj = 50.16 */

proc reg data=model_data;
    model lgd_pmi_logit =
          d_euribor_l2
          d_oil_l2
          d_btp_l1
          dummy_covid
		  d_def_l7
          / vif;
run;
quit;

/* R^2 adj = 61,76 */


proc reg data=model_data;
    model lgd_inst_logit =
          d_euribor_l2
          d_oil_l2
          d_btp_l1
          dummy_covid
		  d_def_l7
          / vif;
run;
quit;

/* R^2 adj = 48.65 */

proc reg data=model_data;
    model lgd_corp_logit =
          d_euribor_l2
          d_oil_l2
          d_btp_l1
          dummy_covid
		  d_def_l7
          / vif;
run;
quit;
/* R^2 adj = 61.45 , spòp euribor sign */






proc reg data=model_data;
    model lgd_retail_logit =
          d_euribor_l2
          d_oil_l2
          d_btp_l7
          dummy_covid
		  
          / vif;
run;
quit;
/* R^2 adj = 51.70, 3 sign*/

proc reg data=model_data;
    model lgd_pmi_logit =
          d_euribor_l2
          d_oil_l2
          d_btp_l7
          dummy_covid
		  
          / vif;
run;
quit;

/* R^2 adj = 62,08, 3 sign */


proc reg data=model_data;
    model lgd_inst_logit =
          d_euribor_l2
          d_oil_l2
          d_btp_l7
          dummy_covid
		 
          / vif;
run;
quit;

/* R^2 adj = 55.18, 2 sign */

proc reg data=model_data;
    model lgd_corp_logit =
          d_euribor_l2
          d_oil_l2
          d_btp_l7
          dummy_covid
		  
          / vif;
run;
quit;
/* R^2 adj = 63.57, 2 sign */









proc reg data=model_data;
    model lgd_retail_logit =
          d_euribor_l2
          d_oil_l7
          d_btp_l1
          dummy_covid
		  dpil_ita_l8
		  
          / vif;
run;
quit;
/* R^2 adj = 61.67, tutti sign*/

proc reg data=model_data;
    model lgd_pmi_logit =
          d_euribor_l2
          d_oil_l2
          d_btp_l7
          dummy_covid
		  dpil_ita_l8
          / vif;
run;
quit;

/* R^2 adj = 55.84, 2 sign */


proc reg data=model_data;
    model lgd_inst_logit =
          d_euribor_l2
          d_oil_l2
          d_btp_l7
          dummy_covid
		 dpil_ita_l8
          / vif;
run;
quit;

/* R^2 adj = 52.02, 2 sign */

proc reg data=model_data;
    model lgd_corp_logit =
          d_euribor_l2
          d_oil_l2
          d_btp_l7
          dummy_covid
		  dpil_ita_l8
          / vif;
run;
quit;
/* R^2 adj = 60.08, 2 sign */




