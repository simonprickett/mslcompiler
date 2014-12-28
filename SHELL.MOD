MODULE Shell;

(* Main program to start the MSL analyser.

   Author : Simon Prickett
   Module : CS310, Programming Language Implementation
   FAO    : Dr Elsworth
   Date   : 08/01/96 
*)

(* -------------------------------------------------------------------------- *)

FROM InOut IMPORT
	WriteLn, WriteCard, WriteString, OpenInput, OpenOutput, CloseInput,
	CloseOutput;

FROM Analyser IMPORT
	Program, TotalErrors, NumStmts, NumProcs;

FROM Utils IMPORT
	Header, Footer, Statistics;

FROM Symtable IMPORT
	TableDump;

FROM Datastore IMPORT
	DSDump;

FROM Codegen IMPORT
	PSPointer;

FROM TM IMPORT
	ListTMcode, TMinterpret;

(* -------------------------------------------------------------------------- *)

BEGIN
	(* Initialise *)
	TotalErrors := 0;
	NumProcs := 0;
	NumStmts := 0;

	WriteString ("MSL Compiler");
	WriteLn;
	WriteString ("============");
	WriteLn;
	WriteLn;

	(* Open data files for input and output *)
	OpenInput  ('msl');
	OpenOutput ('res');

	(* Print the banner to the output file *)
	Header; 

	(* Start RDSA and code generation. *)
	Program;

	(* DSDump was used during development to check the data store contents
	   but its output is not required for the final submission. *)
	(* DSDump; *)

	(* Run the program if no errors. *)
	IF TotalErrors = 0 THEN
		(* Print the symbol table. *)
		TableDump;
		(* List the code - use PSPointer -1 as PSPointer points to the
		   next free location not the last used one. *)
		ListTMcode (PSPointer -1);

		(* Run it! *)
		TMinterpret
	END;

	(* Output program statistics and footer. *)

	Statistics (NumProcs, NumStmts, TotalErrors);
	Footer;

	(* Remember to close the input file *)
	CloseInput;

	(* Remember to close the output file *)
	CloseOutput
END Shell.
