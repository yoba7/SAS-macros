# sas2sqlite

SAS Macro to export SAS datasets to a SQLite database.

## How to use the macro

Syntax of the macro call:
```sas
%sas2sqlite(dataset=<Name of dataset to export>,
            sqliteTable=<Name of corresponding SQLite table>,
            dateVariables=<List of date variables>,
            timeVariables=<List of time variables>,
            dateTimeVariables=<List of dateTime variables>,
            outputDirectory=</path/to/your/sqlite/files>)
```

The following arguments are optional and will default to NONE:
 * dateVariables=NONE
 * timeVariables=NONE
 * dateTimeVariables=NONE

## Example of use

### Export from SAS:

Here is an an example of export:

```sas
* Create a SAS dataset to export to SQLite;
data work.T01_aRandomWalk;
do DT_DAY='01JAN2019'D to '31DEC2019'D; format DT_DAY date9.;
  MS_MEASURE=sum(0,MS_MEASURE,rannor(1332));
  output;
end;
run;

* Export SAS datasset to SQLite;
%sas2sqlite(dataset=work.T01_aRandomWalk,
            sqliteTable=T01_aRandomWalk,
            dateVariables=DT_DAY,
            outputDirectory=</path/to/your/sqlite/files>)

```

Two file have been created on the disk, in the output directory:
- T01_randomWalk.asc: a *pipe separated value* file without [BOM](https://en.wikipedia.org/wiki/Byte_order_mark) containing the *data portion*
- T01_randomWalk.sql: a *SQLite script* containing notably some [dot-commands](https://sqlite.org/cli.html#special_commands_to_sqlite3_dot_commands_); you can execute this script to create and load the table.


### Import from SQLite:

In a terminal session:

```bash
sqlite3 nameOfYourDatabase.sqlite < T01_randomWalk.sql
```

You can also execute this script from within SQLite:

```sqlite
sqlite> .read T01_randomWalk.sql
```

Now, you can have a look at the data:

```bash
sqlite> .headers on
sqlite> select * from T01_randomWalk limit 5;
DT_DAY|MS_MEASURE
2019-01-01|0.7690885485
2019-01-02|-0.29028309
2019-01-03|0.6402183711
2019-01-04|1.0209814817
2019-01-05|0.2718350673
sqlite> .exit
```
