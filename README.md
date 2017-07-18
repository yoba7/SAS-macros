# sas-connected-components

SAS Macro to identify connected components of a (very) large undirected graph.

# Example of use

* Generate a random graph with 100.000 edges and around 100.000 nodes

```sas

%let edges=100000;
%let nodes=100000;

data T001_graph;
do i=1 to &edges; drop i;
 from=int(ranuni(0)*&nodes);
 to=int(ranuni(0)*&nodes);
 output;
end;
run;

```

* Find connected components

```sas

%connectedComponentsLabeling(inputDatasetEdges=T001_graph,     
                             edgeEndA=from,              
		             edgeEndB=to,              
		             outputDatasetVertices=T002_vertices, 
		             outputDatasetEdges=T002_edges
                            );

```
