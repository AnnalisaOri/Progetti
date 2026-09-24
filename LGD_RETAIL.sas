proc import
    datafile="C:\Users\aori004\Desktop\Letteratura\retail.xlsx"
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



/* statistiche descrittive */
proc means data=retail n mean median std min p25 p75 max;
    var obs;
run;



/*esporto grafico */
proc sgplot data=retail;
    series x=date_sas y=obs;

    xaxis label="Date";
    yaxis label="Retail LGD (IRB, SI)";
run;

ods graphics / reset
    imagename="LGD_Retail_Series"
    imagefmt=png
    width=12in
    height=7in;

ods listing gpath="C:\Users\aori004\Desktop\Letteratura\";

title "Loss Given Default (LGD) for Retail Exposures";
footnote "Significant Institutions - IRB Approach";

proc sgplot data=retail;
    series x=date_sas y=obs /
           lineattrs=(color=navy thickness=2);

    xaxis label="Date";
    yaxis label="LGD (%)"
          values=(23 to 35 by 0.01)
          grid;
run;

title;
footnote;
ods listing close;





proc univariate data=retail normal;
    var obs;
    histogram obs / normal;
    qqplot obs;
run;


proc arima data=retail;
    identify var=obs stationarity=(adf=4);
run;
quit;

proc autoreg data=retail;
   model obs= / stationarity=(kpss);
run;





proc arima data=retail;
   identify var=obs(1) nlag=6;
   identify var=obs(1,1) stationarity=(adf=4);
run;
quit;
