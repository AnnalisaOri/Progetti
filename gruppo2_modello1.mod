%BASED ON CHRISTIANO ET AL "NOMINAL RIGIDITITES AND THE EFFECTS OF A MONETARY POLICY SHOCK" JPE (2005)
%DOES NOT CONSIDER CASH IN ADVANCE (WORKING CAPITAL)
%INTEREST RATE RULE (NO MONEY)

var labobs robs pinfobs dy dc dinve dw lambda c h w R inv pk rk k u y pi mc mrs Winf Rint a ep el eb erk er epi ew eg ei; 
varexo epsa epsp epsl epsb epsrk epsr epspi epsw epsg epsi;

// A B W h R w 

% lambda: Lagrange multiplier
% c: consumption
% h: hours worked
% w: real wage
% R: nominal interest rate
% inv: investment
% pk: Tobin's Q
% rk: real return on capital
% u: capital utilization
% k: capital stock
% y: output
% pi: price inflation
% mc: marginal costs
% mrs: marginal rate of substitution
% Winf: wage inflation
% Rint: real interest rate 
% labobs robs pinfobs dy dc dinve dw: Smets and Wouters (2007) observable variables
% a: technology shock 
% ep: preference shock
% el: labor supply shock
% eb: risk premium shock (CB interest rate)
% erk: risk premium shock (rental rate of capital)
% er: monetary shock
% epi: price markup shock
% ew: wage markup shock
% eg: government spending shock


parameters  bet sig vphi b alp delta eta kappa sig_u gamw gamp
            lambw lambp alpw phi1 phi2 phi3 
            g_y mup trend constpi constlab
            rhoa rhop rhol rhob rhork rhor rhopi rhow rhog rhoi;
            % y_h k_y k_h c_y i_y rk_bar w_bar sig_a
%------------------------------------------------------------------------------------------%
%                                 PARAMETERS                                               % 
%------------------------------------------------------------------------------------------%

%1)PREFERENCES
sig =1;                   % intertemporal elasticity
b =0.65;                  % degree of habit persistence
bet = (1.02)^(-1/4);             % subjective discount factor
vphi =1;                  % inverse of Frisch elasticity

%2)TECHNOLOGY
alp = 0.36;               % share of capital
delta =0.025;             % depreciation rate

%3)CAPITAL ADJUSTMENT COST AND UTILIZATION
kappa = 2.48;            % capital adjustment costs
sig_u = 0.27;            % sig_a=sig_u/(1-sig_u) 
%sig_a = 0.01;            % gam2/gam1 (gam1 and gam2 parameter governing capacity cost function)

%4)CALVO PARAMETERS
lambw = 0.75;              %on wages
lambp = 0.75;              %on prices

%5)INDEXATION
gamw =1;                %on wages           
gamp =1;                %on prices

%6)ELASTICITIES OF SUBSTITUTIONS
eta      = 6;           % price-elasticity of demand for a differianted good
alpw     = 6;           % wage -elasticity of demand for a differianted labor input
mup  = eta/(eta-1);     % price mark_up

%------------------------------------------------------------------------------------------%
%                          STEADY STATE                              % 
%------------------------------------------------------------------------------------------%

g_y    = 0.2;

%------------------------------------------------------------------------------------------%
%                                MONETARY RULE                                             % 
%------------------------------------------------------------------------------------------%
phi1 = 1.5;                     % monetary rule parameter (on inflation)
phi2 = 0.5;                    % monetary rule parameter (on output) 
phi3 = 0;                     % monetary rule parameter (on lagged interest rate)

%------------------------------------------------------------------------------------------%
%                                SHOCKS PERSISTENCES                                       %
%------------------------------------------------------------------------------------------%

rhoa = 0.9;
rhop = 0.5;
rhol = 0.5;
rhob = 0.5;
rhork = 0.5;
rhor = 0;
rhopi = 0.5;
rhow = 0.5;
rhog = 0.5;
rhoi = 0.5;

%------------------------------------------------------------------------------------------%
%                            MEASUREMENT EQUATIONS CONSTANTS                               %
%------------------------------------------------------------------------------------------%

trend=0;
constlab=0;
constpi=0;

model(linear);

#k_h    =((1-bet*(1-delta))/(bet*alp)*mup)^(1/(alp-1));      
#y_h    =(k_h)^alp;                                         
#k_y    =k_h*(y_h)^(-1);                                    
#i_y    =delta*k_y;                                        
#c_y    =1-i_y-g_y;                                   
#rk_bar =(1/bet-1+delta);                                   
#w_bar  =(1-alp)/alp*(k_h)*rk_bar; 
#sig_a = sig_u/(1-sig_u); 
#pi_bar = 1+constpi/100;
#R_bar = pi_bar/bet;
#constr = (R_bar-1)*100;             
            
// EQ. 1 Marginal utility of consumption
lambda= sig/((1-bet*b)*(1-b))*(b*c(-1)+bet*b*c(+1)-(1+bet*b^2)*c)+ (1/(1-bet*b))*(ep-bet*b*ep(+1));

// EQ. 2 Euler equation
lambda= eb+lambda(+1)+(R-pi(+1));

// EQ. 3 Investment FOC
inv = 1/(kappa*(1+bet))*(ei+pk) + 1/(1+bet)*inv(-1) + bet/(1+bet)*inv(+1);

// EQ. 4 Capital FOC
pk = -(R - pi(+1)+eb) + bet*(1-delta)*pk(+1) + bet*rk_bar*rk(+1)-bet*rk_bar*erk;

// EQ. 5 Utilization FOC
u =(1/sig_a)*rk-erk(-1);

// EQ. 6 Capital accumulation equation
k = (1-delta)*k(-1) + delta*(inv + ei);

// EQ. 7 Resource constraint
y = c_y*c+i_y*inv+k_y*rk_bar*u+g_y*eg;

// EQ. 8 Price NKPC
(1+bet*gamp)*pi=((1-bet*lambp)*(1-lambp)/lambp)*mc+bet*pi(+1)+gamp*pi(-1)+epi;

// EQ. 9 Marginal cost
mc = (1-alp)*w+alp*rk-a;

// EQ. 10 Wage NKPC
w=((1-bet*lambw)*(1-lambw))/((1+bet)*lambw)*(mrs-w)+(bet/(1+bet))*(pi(+1)+w(+1))+(gamw/(1+bet))*pi(-1)+(1/(1+bet))*w(-1)-((bet*gamw+1)/(1+bet))*pi+ew;

// EQ. 11 Capital to hours ratio
w + h = rk + u + k(-1);

// EQ. 12 Production function
y = alp*(u + k(-1))+(1-alp)*h +a;

// EQ. 13 Taylor rule
R = phi3*R(-1)+(1-phi3)*(phi1*pi+phi2*y)+er;

// EQ. 14 Real interest rate
Rint = R - pi(+1); 

// EQ. 15 Wage inflation
Winf = w-w(-1)+ pi; 

// EQ. 16 Marginal rate of substitution
mrs=ep+el+vphi*h-lambda;

// EQ. 17 TFP shock
a = rhoa * a(-1) + epsa; 

// EQ. 18 Preference shock
ep = rhop * ep(-1) + epsp; 

// EQ. 19 Labor supply shock
el = rhol * el(-1) + epsl; 

// EQ. 20 Risk premium shock I
eb = rhob * eb(-1) + epsb; 

// EQ. 21 Risk premium shock II
erk = rhork * erk(-1) + epsrk; 

// EQ. 22 Monetary policy shock
er = rhor * er(-1) + epsr; 

// EQ. 23 Price markup shock
epi = rhopi * epi(-1) + epspi; 

// EQ. 24 Wage markup shock
ew = rhow * ew(-1) + epsw; 

// EQ. 25 Government spending shock
eg = rhog * eg(-1) + epsg; 

// EQ. 26 Investment shock
ei = rhoi * ei(-1) + epsi;

// measurement equations

dy=y-y(-1)+trend;
dc=c-c(-1)+trend;
dinve=inv-inv(-1)+trend;
dw=w-w(-1)+trend;
pinfobs = pi + constpi;
robs =    R + constr;
labobs = h + constlab;

end;

steady;
check;

shocks;
var epsa;
stderr 0.45;
var epsp;
stderr 0.1;
var epsl;
stderr 0.1;
var epsb;
stderr 0.24;
var epsrk;
stderr 0.1;
var epsr;
stderr 0.24;
var epspi;
stderr 0.14;
var epsw;
stderr 0.24;
var epsg;
stderr 0.52;
var epsi;
stderr 0.45;
end;

estimated_params;
// PARAM NAME, INITVAL, LB, UB, PRIOR_SHAPE, PRIOR_P1, PRIOR_P2, PRIOR_P3, PRIOR_P4, JSCALE
// PRIOR_SHAPE: BETA_PDF, GAMMA_PDF, NORMAL_PDF, INV_GAMMA_PDF
stderr epsa, 0.45,,,INV_GAMMA_PDF, 0.1,2;
stderr epsp, 0.1,,,INV_GAMMA_PDF, 0.1,2;
stderr epsl, 0.1,,,INV_GAMMA_PDF, 0.1,2;
stderr epsb, 0.24,,,INV_GAMMA_PDF, 0.1,2;
stderr epsrk, 0.1,,,INV_GAMMA_PDF, 0.1,2;
stderr epsr, 0.24,,,INV_GAMMA_PDF, 0.1,2; 
stderr epspi, 0.14,,,INV_GAMMA_PDF, 0.1,2;
stderr epsw, 0.24,,,INV_GAMMA_PDF, 0.1,2;
stderr epsg, 0.52,,,INV_GAMMA_PDF, 0.1,2;
stderr epsi, 0.45,,,INV_GAMMA_PDF, 0.1,2; 
rhoa,.9 ,.01,.9999,BETA_PDF,0.5,0.20;   
rhop,.5,.01,.9999,BETA_PDF,0.5,0.20;
rhol,.5,.01,.9999,BETA_PDF,0.5,0.20;
rhob,.5,.01,.9999,BETA_PDF,0.5,0.20;
rhork,.5,.01,.9999,BETA_PDF,0.5,0.20;
rhopi,.5,.001,.9999,BETA_PDF,0.5,0.20;
rhow,.5,.001,.9999,BETA_PDF,0.5,0.20;
rhog,.5,.001,.9999,BETA_PDF,0.5,0.20;
rhoi,.5,.001,.9999,BETA_PDF,0.5,0.20;
sig, 1, , , NORMAL_PDF,1.5, 0.375; //sigma_c
b, 0.65, , , BETA_PDF, 0.7, 0.10; //h - fine pagina 596, nella descrizione della tabella 4
vphi, 1, , , NORMAL_PDF, 2.0, 0.75; // sigma_l 
kappa, 3.5, , , NORMAL_PDF, 4.00, 1.50; //phi (quello diverso)
sig_u, 0.27, , , BETA_PDF, 0.50, 0.15; //psi
gamp, 0.4, , , BETA_PDF, 0.50, 0.15; //i_p
lambp, 0.75, , , BETA_PDF, 0.50, 0.10; //epsilon_p
gamw, 0.4, , , BETA_PDF, 0.50, 0.15; //i_p
lambw, 0.75, , , BETA_PDF, 0.50, 0.10;  //epsilon_w
phi3, 0.5, , , BETA_PDF, 0.75, 0.1; //rho - vedi eq 14 - capire se è giusta la tabella o il testo
phi1, 1.5, , , NORMAL_PDF, 1.5, 0.25; //r_pi
phi2, 0.1, , , NORMAL_PDF, 0.125, 0.05; //r_y 
trend, 0.4, , ,NORMAL_PDF,0.4,0.10; // gammabarrato
constpi, 0.6, , ,GAMMA_PDF,0.62,0.1; //pibarrato
constlab, 0, , ,NORMAL_PDF,0,2.00; //lbarrato
end;

varobs robs pinfobs dy dc dinve dw labobs;

estimation(optim=('MaxIter',200),
    datafile=usmodel_data_update_varobs,
    mode_compute=6,
    presample=4,
    lik_init=2,
    prefilter=0,
    mh_replic=250000,
    mh_nblocks=2,
    mh_jscale=0.20,
    mh_drop=0.2,
    bayesian_irf) robs pinfobs dy dc dinve dw labobs;

shock_decomposition dinve;