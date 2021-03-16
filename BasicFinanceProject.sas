LIBNAME datalib '/courses/d77fe415ba27fe300' access=readonly;

/* Location, grab date 2016 */
data work.crspraw;
set datalib.crsp; 
crspyear=year(date);
Drop cusip permco tsymbol vwretd;/*optional*/
run;

/* Year 2016 */
data work.crspselected;
set work.crspraw;
where crspyear=2016;
Run;

proc contents data=work.crspselected;
run;

/* SICCD starts with 35*/
data work.crspraw;
set work.crspraw;
where (siccd >3499 and siccd <3600);
run;

/* Delete observations where PRC value is missing or negative*/\
/* This is the same as PRC >=0 */
data work.crspraw;
set work.crspraw;
where PRC >= 0;
run;


/* Calculate daily market capitalization (market value, or mv) */
data work.crspraw;
set work.crspraw;
mv=prc*shrout;
run;

/* Group by company name, calculate the average mv 
Mid-cap is greater than $2B and less than $10B (remember in thousands already) 
*/
data work.crspraw_midcap;
set work.crspraw;
where (mv > 2000000 and mv < 10000000);
run;

/*get average stock return*/
proc sort data=work.crspraw;
by permno date;
run;

/*get the statistics of average daily ret and mv*/
proc means data=work.crspraw noprint;
var ret mv;
by permno;/*by each and every company*/
output out=work.averet(drop=_type_ _freq_) mean= median= std= / autoname;
run;

data work.averet;
set work.averet;
where (mv_Mean > 2000000 and mv_Mean < 10000000);
run;

proc contents data=work.averet;
run;

data work.averet_midcap;
set work.averet;
coeff_of_variation=ret_stddev/ret_mean;
where (mv_mean < 10000000 and mv_mean > 2000000);
run;

/* When sorted by mv_Mean, the top 3 in order (by PNMO) are:
86979; 82598; 89004.
Need the rest of the info, such as ticker (see below)
*/

proc sql;
select * from work.crspraw where (PERMNO=86979 or PERMNO=82598 or PERMNO=89004);
sort by PERMNO;
run; 


data work.averet;
set work.averet;
coeff_of_variation=ret_stddev/ret_mean;
where (mv > 2000000 and mv < 10000000);
run;






/* T-bill (Use in Step 7) */
FILENAME REFFILE '/home/u47565185/my_courses/xz400/treasury yield 2016.xlsx';

PROC IMPORT DATAFILE=REFFILE
	DBMS=XLSX
	OUT=WORK.IMPORT;
	GETNAMES=YES;
RUN;

PROC CONTENTS DATA=WORK.IMPORT; RUN;


%web_open_table(WORK.IMPORT);
