
/*************************************************************************/
/*************************************************************************/
/*************************************************************************/
/*                                                                       */
/* SAS Macro to identify connected components of a large undirected      */
/* graph.                                                                */
/*                                                                       */
/* Auteur: Youri Baeyens                                                 */
/*                                                                       */
/*************************************************************************/
/*************************************************************************/
/*************************************************************************/

%macro to_text(variable);
 trim(left(put(&variable,best12.)))
%mend;


%macro connectedComponentsLabeling(inputDatasetEdges=,     /* Input dataset of type Edges     */
                                   edgeEndA=,              /* Variable from input dataset     */
								   edgeEndB=,              /* Variable from input dataset     */
								   outputDatasetVertices=, /* Output dataset of type Vertices */
								   outputDatasetEdges=     /* Output dataset of type Edges    */
                                  );

	  %let startTime=%sysfunc(datetime());

	  /*******************************************************************/
      /*                                                                 */
      /* Parameters validation                                           */
      /*                                                                 */
      /*******************************************************************/

      %if not %sysfunc(exist(&inputDatasetEdges))
	  %then %do;
	          put ERROR: Input file &inputDatasetEdges does not exist;
			  %goto exit;
            %end;

      proc contents data=&inputDatasetEdges out=CG_000_CONTENTS noprint;
      run;

      proc sql NOPRINT;
      select count(*), count(distinct type), count(distinct length), max(type), max(length)
      into :nb_variables_found, :nb_distinct_types, :nb_distinct_length, :type, :length
      from CG_000_CONTENTS
      where upcase(NAME) in (%upcase("&edgeEndA"),%upcase("&edgeEndB"));
      quit;

	  %if &nb_variables_found ne 2
	  %then %do;
	          %put ERROR: Either &edgeEndA or &edgeEndB not present in &inputDatasetEdges;
			  %goto exit;
            %end;

	  %if &nb_distinct_types ne 1
	  %then %do;
	          %put ERROR: &edgeEndA and &edgeEndB not of the same type in &inputDatasetEdges (one is numeric, the other is character);
			  %goto exit;
            %end;

	  %if &nb_distinct_length ne 1
	  %then %do;
	          %put ERROR: &edgeEndA and &edgeEndB not of the same length in &inputDatasetEdges;
			  %goto exit;
            %end;

	  %if &length >16
	  %then %do;
	          %put ERROR: length of &edgeEndA and &edgeEndB in &inputDatasetEdges is greater than 16 (length is &length);
			  %put ERROR: are you sure &edgeEndA and &edgeEndB are id variables?;
			  %goto exit;
            %end;

      %if "&outputDatasetVertices" eq "" and "&outputDatasetEdges" eq ""
	  %then %do;
	          %put ERROR: either outputDatasetVertices or outputDatasetEdges should be specified;
			  %goto exit;
            %end;


	  %if &type=2 %then %let myType=$&length;
	              %else %let myType=&length;

      /*******************************************************************/
      /*                                                                 */
      /* Extract list of vertices                                        */
      /*                                                                 */
      /*******************************************************************/

      proc sql;
      create table CG_001_VERTICES as
      select distinct UNIT 
      from (
            select distinct &edgeEndA as UNIT from &inputDatasetEdges
            UNION
            select distinct &edgeEndB as UNIT from &inputDatasetEdges
           );
      quit;

      /*************************************************************************/
      /*                                                                       */
      /* Rename of variables                                                   */
      /*                                                                       */
      /*************************************************************************/

      proc sql;
      create view CG_001_EDGES as
      select &edgeEndA as VerticeLabel_of_edgeOrigin,
             &edgeEndB as VerticeLabel_of_edgeDestination
      from &inputDatasetEdges;
      quit;

	  /*************************************************************************/
      /*                                                                       */
      /* Define the bijective application (R, see page 24)                     */
      /*                                                                       */
      /*************************************************************************/

      data CG_002_VERTICES;
      set CG_001_VERTICES(rename=(UNIT=VerticeLabel)) end=fin;
      verticeSerial+1;
      if fin then call symput('number_of_vertices',%to_text(_N_));
      run;

      /*************************************************************************/
      /*                                                                       */
      /* Apply bijective application using a hash table                        */
      /*                                                                       */
      /*************************************************************************/

      data CG_003_EDGES(keep=verticeLabel_of_edgeOrigin 
                             verticeLabel_of_edgeDestination 
                             verticeSerial_of_edgeOrigin 
                             verticeSerial_of_edgeDestination);

      if _N_ = 1 
      then do;
            declare hash h(dataset: "CG_002_VERTICES", hashexp: 16);
            h.defineKey('VerticeLabel');
            h.defineData('verticeSerial');
            h.defineDone();
           end;

      set CG_001_EDGES;

      VerticeLabel=verticeLabel_of_edgeOrigin; rc = h.find(); 
      if (rc = 0) then verticeSerial_of_edgeOrigin=verticeSerial;
                  else verticeSerial_of_edgeOrigin=.;

      VerticeLabel=verticeLabel_of_edgeDestination; rc=h.find(key: verticeLabel_of_edgeDestination);
      if (rc = 0) then verticeSerial_of_edgeDestination=verticeSerial;
                  else verticeSerial_of_edgeDestination=.;
      run;

      proc datasets library=work nolist;
	  delete CG_000_CONTENTS;
      delete CG_001_EDGES;
	  delete CG_001_VERTICES;
      run;
      quit;

      /*************************************************************************/
      /*                                                                       */
      /* Connexity algorithm                                                   */
      /*                                                                       */
      /*************************************************************************/


      data CG_004_FOREST( keep=node root
                          rename=(
                                  node=nodeSerial_of_tree 
                                  root=rootSerial_of_tree
                                 )
                         );

      array pointer_of_node {&number_of_vertices } 8 _TEMPORARY_;

      * INITIALISATION OF POINTERS;
      * --------------------------;

      if _N_=1 then do node=1 to &number_of_vertices;
                      pointer_of_node{node}=node;
                    end;

      * PROCESSING OF EDGES;
      * -------------------;

       set CG_003_EDGES end=fin nobs=nobs;
 
       id=verticeSerial_of_edgeOrigin;      link root; root1=root;
       id=verticeSerial_of_edgeDestination; link root; root2=root;
       if root1 ne root2
       then do;
             pointer_of_node{root2}=root1;
            end;
                             
      * EXPORT OF RESULTS;
      * -----------------;

      if fin then do;
                    link restructure_tree;
                    do node=1 to &number_of_vertices;
                      root=pointer_of_node{node};
                      output;
                    end; 
                  end;

      return;

      * ROOT FUNCTION;
      * -------------;
           
      root:
       F_root=0;
       element_current=id;
       element_next=pointer_of_node{id};
       longueur_path=1;
       do while(F_root=0);
          if element_next=element_current 
          then do;
      	        F_root=1;
       	        root=element_current;
               end;
          else do;
                element_current=element_next;
		element_next=pointer_of_node{element_current};
               end;
	  longueur_path=longueur_path+1;
       end;
       if longueur_path>2 then link restructure_path;
      return;

      * RESTRUCTURE_TREE FUNCTION;
      * -------------------------;

      restructure_tree:
       do node=1 to &number_of_vertices;
         id=node; link root; pointer_of_node{node}=root;
       end;
      return;

      * RESTRUCTURE_PATH FUNCTION;
      * -------------------------;

      restructure_path:
       F_root=0;
       element_current=id;
       element_next=pointer_of_node{id};
       longueur_path=1;
       do while(F_root=0);
          if element_next=element_current 
          then F_root=1;
          else do;
                  pointer_of_node{element_current}=root;
                  element_current=element_next;
	          element_next=pointer_of_node{element_current};
               end;
       end;
      return;

      run;

	  /*************************************************************************/
      /*                                                                       */
      /* Create output dataset                                                 */
      /*                                                                       */
      /*************************************************************************/

	  %if "&outputDatasetVertices" ne ""
	  %then %do;
	          data CG_005_FOREST(keep=nodeLabel_of_tree
                                      rootLabel_of_tree
                                 );

               array label_of {&number_of_vertices } &myType _TEMPORARY_; 

               * Initialise reverse bijective application;

               if _N_=1 then do until(fin); 
                               set Cg_002_VERTICES end=fin;
                               label_of{VerticeSerial}=VerticeLabel;
                             end;

               * Apply reverse bijective application;

               set CG_004_FOREST end=fin;
               nodeLabel_of_tree=label_of{nodeSerial_of_tree};
               rootLabel_of_tree=label_of{rootSerial_of_tree};

              run;

	          data &outputDatasetVertices(drop=rootLabel_of_tree);
			   length connectedComponentLabel $16;
	           set CG_005_FOREST;
	           rename nodeLabel_of_tree=vertex;
			   connectedComponentLabel=put(md5(rootLabel_of_tree),$hex16.);
	          run;

             %end;

	  %if "&outputDatasetEdges" ne ""
	  %then %do;
	          proc sql;
			  create table &outputDatasetEdges as
			  select A.*, B.connectedComponentLabel
			  from &inputDatasetEdges A, &outputDatasetVertices B
			  where A.&edgeEndA=B.vertex;
			  quit;
	        %end;

proc datasets library=work nolist;
delete CG_002_VERTICES;
delete CG_003_EDGES;
delete CG_004_FOREST;
delete CG_005_FOREST;
run; quit;

proc sql;
drop view CG_001_EDGES;
quit;

%exit:

	  %let stopTime=%sysfunc(datetime());

	  data _NULL_;
	  elapsedTime=&stopTime-&startTime;
	  put "NOTE: Time to process the whole graph: " elapsedTime=time.;
	  run;

%mend;
