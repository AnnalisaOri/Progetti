



/* importo LGD institutions */
proc import
    datafile="C:\Users\aori004\Desktop\Letteratura\Input SAS\institutions.xlsx"
    out=institutions
    dbms=xlsx
    replace;
	sheet="Data(SUP)";
    getnames=yes;
run;

data institutions;
    set institutions(rename=("obs.value"n = obs));
run;


data institutions;
    set institutions;

    date_sas = input(DATE,yymmdd10.);
    format date_sas date9.;
run;





/* importo LGD corporate */
proc import
    datafile="C:\Users\aori004\Desktop\Letteratura\Input SAS\corporate.xlsx"
    out=corporate
    dbms=xlsx
    replace;
	sheet="Data(SUP)";
    getnames=yes;
run;

data corporate;
    set corporate(rename=("obs.value"n = obs));
run;


data corporate;
    set corporate;

    date_sas = input(DATE,yymmdd10.);
    format date_sas date9.;
run;

data corporate;
    set corporate;

    if not missing(obs);
run;



/* importo LGD pmi */
proc import
    datafile="C:\Users\aori004\Desktop\Letteratura\Input SAS\pmi.xlsx"
    out=pmi
    dbms=xlsx
    replace;
	sheet="Data(SUP)";
    getnames=yes;
run;

data pmi;
    set pmi(rename=("obs.value"n = obs));
run;


data pmi;
    set pmi;

    date_sas = input(DATE,yymmdd10.);
    format date_sas date9.;
run;

data pmi;
    set pmi;

    if not missing(obs);
run;



/* importo LGD retail */
proc import
    datafile="C:\Users\aori004\Desktop\Letteratura\Input SAS\retail.xlsx"
    out=retail
    dbms=xlsx
    replace;
	sheet="Data(SUP)";
    getnames=yes;
run;

data retail;
    set retail(rename=("obs.value"n = obs));
run;


data retail;
    set retail;

    date_sas = input(DATE,yymmdd10.);
    format date_sas date9.;
run;

data retail;
    set retail;

    if not missing(obs);
run;







/* importo regressori */
proc import
    datafile="C:\Users\aori004\Desktop\Letteratura\Input SAS\260422_BFF_Proiezioni_Scenari_Macro_v1.xlsx"
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








/* join per creare model_data contenente sia serie LGD che regressori*/
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



/* solo corporate è già in percentuale */
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



/* calcolo le differenze */
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



/* calcolo i lag di tutte le differenze */
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







/* calcolo logit lgd */
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


data model_data;
    set model_data;

    if year(date_sas) in (2020, 2021) then dummy_covid=1;
    else dummy_covid=0;
run;


/* esporto model data */
proc export
    data=model_data
    outfile="C:\Users\aori004\Desktop\Letteratura\Output SAS\model_data"
    dbms=xlsx
    replace;
    sheet="model_data";
run;