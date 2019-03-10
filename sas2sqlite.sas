/*************************************************************************/
/*************************************************************************/
/*************************************************************************/
/*                                                                       */
/* SAS Macro to export a dataset to a SQLite database.                   */
/*                                                                       */
/*                                                                       */
/* Author: Youri Baeyens                                                 */
/*                                                                       */
/*************************************************************************/
/*************************************************************************/
/*************************************************************************/


%macro sas2sqlite(dataset=,
                  sqliteTable=,
                  dateVariables=NONE,
                  timeVariables=NONE,
                  dateTimeVariables=NONE,
                  outputDirectory=);

options nobomfile;

proc contents data=&dataset out=T02_meta noprint;
run;

proc sort data=T02_meta;
by varnum;
run;

data _NULL_;
set T02_meta end=fin;
file "&outputDirectory\&sqliteTable..sql" lrecl=60000;
if _N_=1 then put "create table &sqliteTable (";
if type=2 then sqliteType='TEXT';
          else sqliteType='REAL';
if fin then endOfLine=');';
       else endOfLine=',';
if not missing(label) then comment=cats('/*',label,'*/');
put @4 name @38 sqliteType comment +(-1) endOfLine;
if fin 
then do;
      put '.separator "|"';
      put ".import &sqliteTable..asc &sqliteTable";
     end;
run;

data _NULL_;
set T02_meta end=fin;
file "&outputDirectory\&sqliteTable..sql" lrecl=60000 MOD;
if type=2 then put "update &sqliteTable set " name "=NULL where " name "=' ';";
          else put "update &sqliteTable set " name "=NULL where " name "='.';";
run;


proc sql NOPRINT;
select distinct name 
into :listOfVariables separated by ' '
from T02_meta
order by varnum;
quit;

data _NULL_;
file "&outputDirectory\&sqliteTable..asc" delimiter='|' encoding="utf-8" lrecl=60000;
set &dataset;
%if "&dateTimeVariables" ne "NONE" %then format &dateTimeVariables E8601DT23.3;;
%if "&timeVariables"     ne "NONE" %then format &timeVariables     E8601TM12.3;;
%if "&dateVariables"     ne "NONE" %then format &dateVariables     E8601DA10. ;;
put &listOfVariables;
run;

%mend;
