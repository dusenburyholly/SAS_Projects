/* Set Library */
LIBNAME datalib "/courses/d77fe415ba27fe300" access=readonly;

/* Load CRSP data */
data crsp;
set datalib.crsp;
crspyear=year(date);
run;

/*STEP 1*/
/*Want 2015 data only*/
data work.crspselected;
set work.crsp;
where crspyear=2015;
run;


/*STEP 2*/
/*FAANG stock data*/
/*PERMNOS 13407, 14593, 84788, 89393, 90319 */
data work.faang;
set work.crspselected;
where (permno = 13407)  or (permno = 14593) or (permno = 84788) or (permno = 89393) or (permno = 90319);
run;

/*STEP 3*/
/* Delete observations where PRC value is missing or negative*/\
/* This is the same as PRC >=0 */
data work.faang2;
set work.faang;
where PRC >= 0;
run;

/*STEP 4*/
/*calculate market cap., create new column w/ it*/
data work.faang2;
set work.faang2;
market_cap = prc * shrout;
run;

/*calculate sum (daily) of FAANG market_cap, create new column*/
/*faang_cap (the portfolio capitalization) is 
the sum of each stocks' market capitalization*/
proc sql;
create table faang_table as
select
*,
sum(market_cap) as faang_cap
from faang2
group by date
order by date;
run;

/*calculate weight, make new column*/
/* weight = market cap divided by 
the portfolio cap (aka faang_cap) */
data faang_table;
set faang_table;
weight = market_cap/faang_cap;
run;


/*calculate the product of weight and return for each stock
and make a new column*/
/* we will use this for the portfolio return 
in the next command*/
data faang_table;
set faang_table;
product = weight * ret;
run;

/* STEP 5*/
/*calculate FAANG return stats for 2015 -- 
FAANG return is the sum of the products in the previous command*/
/* build the structure of this table for stats first*/
proc sort data=faang_table out=port;
   by Date;
run;

data port_ret_stats;
  set port;
  by Date;
  if First.Date then port_ret=0;
  port_ret + product;
  if Last.Date then output;
run;

proc means data=port_ret_stats;
var port_ret;
output out=port_stats (drop=_freq_ _type_) mean= std= n= /autoname;
run;

/* STEP 6*/
/* FAANG Portfolio risk return tradeoff*/

/*Import FAMA French data first */
/* Generated Code (IMPORT) */
/* Source File: F-F_Research_Data_Factors_daily_2020_0430.csv */
/* Source Path: /home/u47565185/my_courses/xz400 */
/* Code generated on: 6/24/20, 8:25 PM */

%web_drop_table(WORK.IMPORT);

FILENAME REFFILE '/home/u47565185/my_courses/xz400/F-F_Research_Data_Factors_daily_2020_0430.csv';

PROC IMPORT DATAFILE=REFFILE
	DBMS=CSV
	OUT=WORK.IMPORT;
	GETNAMES=YES;
RUN;

PROC CONTENTS DATA=WORK.IMPORT; RUN;


/* Clean the Fama french data - 
currently in % but want decimals for clarity */
/*change 'Mkt-RF' to n=mkt_rf;*/
/* change VAR1 to dates and put in date format*/
	/* once in date format, make column for year (easier)*/
data famafrench;
 set import;
 rename VAR1=Date;
 DATE2 = INPUT(PUT(var1,8.),YYMMDD8.); /* date 2 bc had problems later on */
 FORMAT DATE YYMMDD10.;
 year=year(date);
run;

/*Convert return to decimals (divide % by 100)*/
/* converting order: left to right when looking at table*/
data famafrench;
 set famafrench;
 mkt_rf_decimal = mkt_rf/100;
 smb_decimal = smb/100;
 hml_decimal = hml/100;
 rf_decimal = rf/100;
RUN;

/* let's drop the %s now that we have decimals */
/* just kidding this created problems later :)
data famafrench;
set famafrench;
Drop mkt_rf smb hml rf;
run; */

/* mean daily risk free rate*/
proc means data= famafrench;
var rf_decimal;
output out=work.famafrenchtradeoff (drop=_type_ _freq_) mean= std= n= /autoname;
run;


/* Remaining stats for table (still Step 6):
coefficient of variation, 
safety first ratio, 
Sharpe Ratio, 
Shortfall risk (prob of retn less than acc rate)*/
/* calculated in order of table (vertically) */

/*let's combine the tables*/

data famafrenchstats;
merge work.import work.famafrenchtradeoff;
run;

data work.famafrenchtradeoff1;
set work.famafrenchstats;
coeff_var = port_ret_StdDev/port_ret_Mean; /* from port_ret*/
acc_rate = 0.02/365; /* chose 0.2; divide 365 for daily */
safety_first = (port_ret_Mean - acc_rate)/port_ret_StdDev;
sharpey_sharpe = (port_ret_Mean - rf_decimal_mean)/port_ret_StdDev;
shortfall_risk_prob = probnorm(-safety_first);
run;

proc print data=work.famafrenchtradeoff;
run;

/*have an errored "port_ret_stdev" 
which is an extra and misspelling. Tried to delete and re-run,
but it is still there so I am 
just ignoring it. */

/*Step 7*/
/* Test the Fama French 3-factor model */
/*build skeleton first */

proc sql;
create table fama3f as
select *
from port_ret_stats g, work.famafrench f
where g.date = f.DATE2;
quit;

/* empty */
proc contents data=fama3f;
run;

/*stock risk premium*/
data famaf2;
set fama3f;
risk_prem = port_ret-rf_decimal; 
run;

/*model */
proc reg data=famaf2;
CAPM: model risk_prem = mkt_rf_decimal;
fama_3_fac: model risk_prem = mkt_rf_decimal smb_decimal hml_decimal;
run;

proc print data=work.fama3f;
run;
