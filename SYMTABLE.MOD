IMPLEMENTATION MODULE Symtable;

(* MSL Symbol table module.

   Author : Simon Prickett
   Module : CS310, Programming Language Implementation
   FAO    : Dr Elsworth
   Date   : 29/12/95
*)

(* -------------------------------------------------------------------------- *)

FROM InOut IMPORT
	Write, WriteCard, WriteLn, WriteString;


(* May need to halt the compiler if the table overflows. *)

FROM SYSTEM IMPORT
	CCALL;

(* Needed for finding things in the symbol table. *)

FROM Lex IMPORT 
	Token, CurrentToken, GetCurrentSymRep;

FROM Source IMPORT
	LineChars;

FROM Datastore IMPORT
	ReserveSpace;

(* The following is needed for fixing up procedure entry addresses. *)

FROM Codegen IMPORT
	PSPointer;

(* -------------------------------------------------------------------------- *)

(* Here's the definition of the symbol table entry record.  I've changed the
   types of some of the fields from INTEGER to CARDINAL to save storage
   space as these values could never be 0. *)

TYPE STentry = RECORD
		  Name : IdrChars;

		  CASE usage : IdrClass OF
			    GlobVar     : RTSL : CARDINAL;
			  | ProcName    : EntryAddress,
					  NumFPs : CARDINAL;
			  | FormalParam : ProcRef,
					  Position : CARDINAL
		  END
	       END;

(* TableSize is the maximum number of symbols that a program is allowed to 
   have before symbol table overflow occurs. *)

CONST TableSize = 200; 

(* TablePointer indicates the next free location in the symbol table. *)

VAR TablePointer : CARDINAL [0..TableSize];

(* SymbolTable is the symbol table itself. *)

TYPE TableType = ARRAY [1..TableSize] OF STentry;

VAR SymbolTable : TableType;

(* -------------------------------------------------------------------------- *)

PROCEDURE GetIdrName (VAR IdrName : IdrChars);

(* Gets the name of an identifier and cuts it to MaxIdrChars in length if
   required. *)

VAR Len,
    Counter  : CARDINAL;
    Repr     : LineChars;

BEGIN
	(* No point doing any of this if it's not an identifier! *)

	IF CurrentToken() = Idr THEN
		(* Get the name out. *)
		GetCurrentSymRep (Repr, Len);
	
		(* Copy it across. *)
		IF Len >= MaxIdrChars THEN
			FOR Counter := 1 TO MaxIdrChars DO
				IdrName[Counter] := Repr[Counter]
			END
		ELSE
			FOR Counter :=1 TO Len DO
				IdrName[Counter] := Repr[Counter]
			END
		END
	END;

	(* Now add padding to make everything MaxIdrChars long. *)
	PadIdrName (IdrName, Len)
END GetIdrName;

(* -------------------------------------------------------------------------- *)

PROCEDURE PadIdrName (VAR IdrToPad : IdrChars; Len : CARDINAL);

(* Pads out the identifier name to MaxIdrChars long and converts to capitals. 
   Done this way due to problems getting the Modula-2 String library to work! *)
    
VAR Counter  : CARDINAL;
    Repr     : LineChars;

BEGIN
	(* Check if any padding is required. *)
	IF Len < MaxIdrChars THEN 
		(* Add the padding *)
		FOR Counter := 1 TO MaxIdrChars - Len DO
			(* herein lies your problem sonny *)
			(* IdrToPad [MaxIdrChars - Counter + Len] := ' ' *)
			IdrToPad [Counter + Len] := ' '
		END
	END;

	(* Capitalise. *)
	FOR Counter := 1 TO MaxIdrChars DO      
		IdrToPad[Counter] := CAP (IdrToPad[Counter])
	END;
END PadIdrName; 

(* -------------------------------------------------------------------------- *)

PROCEDURE CompareIdrs (Idr1, Idr2 : IdrChars) : BOOLEAN;

(* Compares two identifiers, returns TRUE if they are the same or false
   otherwise. *)

VAR Counter : CARDINAL;

BEGIN
	FOR Counter := 1 TO MaxIdrChars DO
		IF Idr1[Counter] <> Idr2[Counter] THEN 
			RETURN FALSE
		END
	END;
	RETURN TRUE
END CompareIdrs;

(* -------------------------------------------------------------------------- *)

PROCEDURE StoreNumParams (ProcLoc, NumParams : CARDINAL);

(* Stores the number of formal parameters for a procedure call in the symbol
   table at the location pointed to by ProcLoc *)

BEGIN
	IF ProcLoc <= TableSize THEN
		SymbolTable[ProcLoc].NumFPs := NumParams
	ELSE
		OutOfTableError (ProcLoc)
	END
END StoreNumParams;

(* -------------------------------------------------------------------------- *)

PROCEDURE StoreEntryAddr (Locn : CARDINAL);

(* Stores the entry address of a procedure.  Should only be called when
   Locn points to a procedure. *)

BEGIN
	SymbolTable[Locn].EntryAddress := PSPointer
END StoreEntryAddr;

(* -------------------------------------------------------------------------- *)

PROCEDURE HowManyParams (TablePtr : CARDINAL) : CARDINAL;

(* Returns the number of parameters that are expected by the procedure whose
   symbol table entry is pointed to by TablePtr. This presumes that it is
   only called when TablePtr points to a procedure! *)

BEGIN
	IF TablePtr <= TableSize THEN
		RETURN SymbolTable[TablePtr].NumFPs
	ELSE
		OutOfTableError (TablePtr);
		RETURN 0
	END
END HowManyParams;

(* -------------------------------------------------------------------------- *)

PROCEDURE GetProcRef (LocnToCheck : CARDINAL) : CARDINAL;

(* Looks up the ProcRef field of a formal parameter and returns it - used for
   checking scope. Should only be called when the LocnToCheck parameter 
   points to a formal parameter. *)

BEGIN
	IF LocnToCheck <= TableSize THEN
		RETURN SymbolTable[LocnToCheck].ProcRef
	ELSE
		OutOfTableError (LocnToCheck);
		(* The following line is never executed but keeps the
		   compiler happy. *)
		RETURN 0
	END
END GetProcRef;

(* -------------------------------------------------------------------------- *)

PROCEDURE GetEntryAddress (Locn : CARDINAL) : CARDINAL;

(* Looks up and returns the entry address for a procedure stored in the
   symbol table.  Should only be called when Locn points to a procedure. *)

BEGIN
	IF Locn <= TableSize THEN
		RETURN SymbolTable[Locn].EntryAddress
	ELSE
		OutOfTableError (Locn);
		(* The following line is never executed but keeps the 
		   compiler happy. *)
		RETURN 0
	END
END GetEntryAddress;

(* -------------------------------------------------------------------------- *)

PROCEDURE GetRTSL (Locn : CARDINAL) : CARDINAL;

(* Looks up an returns the RTSL of a global variable stored in the symbol
   table.  Should only be called when Locn points to a global variable. *)

BEGIN
	IF Locn <= TableSize THEN
		RETURN SymbolTable[Locn].RTSL
	ELSE
		OutOfTableError (Locn);
		(* The following line is never executed but keeps the 
		   compiler happy. *)
		RETURN 0
	END
END GetRTSL;

(* -------------------------------------------------------------------------- *)

PROCEDURE GetPosition (Locn : CARDINAL) : CARDINAL;

(* Looks up and returns the position of a formal parameter pointed to by 
   Locn.  Should only be called when Locn points to a formal parameter. *)

BEGIN
	IF Locn <= TableSize THEN
		RETURN SymbolTable[Locn].Position
	ELSE
		OutOfTableError (Locn);
		(* The following line is never executed but keeps the
		   compiler happy. *)
		RETURN 0
	END
END GetPosition;
   
(* -------------------------------------------------------------------------- *)

PROCEDURE OutOfTableError (Location : CARDINAL);

(* Simple error procedure to notify the user when an attempt has been made
   to reference a symbol that doesn't exist. *)

BEGIN
	WriteString ("    Internal Error : Attempt to access element ");
	WriteCard (Location, 0);
	WriteString (" of the symbol table.  Valid values are 1-");
	WriteCard (TablePointer, 0);
	WriteString (".");
	WriteLn;
	WriteString ("    MSL compiler terminated abnormally.");
	WriteLn;
	WriteLn;
	CCALL ("exit", 1)
END OutOfTableError;

(* -------------------------------------------------------------------------- *)

PROCEDURE TableFullError (ErrorIdr : IdrChars);

(* Simple error procedure to notify the user when an attempt has been made
   to assign another symbol to a full symbol table. *)

BEGIN
	WriteString ("    Internal Error : Symbol table full (");
	WriteCard (TablePointer, 0);
	WriteString (" symbols).  ");
	WriteString (" Ignoring : ");
	WriteString (ErrorIdr);
	WriteLn;
	WriteString ("    MSL compiler terminated abnormally.");
	WriteLn;
	WriteLn;
	CCALL ("exit", 1)
END TableFullError;

(* -------------------------------------------------------------------------- *)

PROCEDURE InTable (IdrToFind : IdrChars) : CARDINAL;

(* Procedure that returns 0 if IdrToFind is NOT in the symbol table,
   or the location if it is. Presumes that IdrToFind is uppercase. *)

VAR Counter : CARDINAL;

BEGIN
	(* Really no point looking further down the table than the location
	   that the TablePointer points to as there's nothing there. *)

	FOR Counter := 1 TO TablePointer DO
		IF CompareIdrs (SymbolTable[Counter].Name, IdrToFind) THEN
			(* Gotcha *)
			RETURN Counter
		END
	END;
	(* Not found *)
	RETURN 0
END InTable;

(* -------------------------------------------------------------------------- *)

PROCEDURE AddToSymTable (IdrToAdd : IdrChars; IdrType : IdrClass; 
			 PRef, Posn : CARDINAL) : CARDINAL; 

(* Procedure to add a symbol to the symbol table.  IdrToAdd is the 
   identifier to add to the symbol table, IdrType is the type of identifier
   being added. The name of IdrToAdd is converted to all uppercase before
   it is added to the table.  Returns the location of the new entry or 0 if
   it fails. 

   Some parameters to this are not always used, eg :

   PRef, Posn are only used when IdrType = FormalParam *)
  
BEGIN
	(* Check that the symbol table is not full. *)
	IF TablePointer = TableSize THEN 
		TableFullError (IdrToAdd);
		(* The following line never gets executed, but this
		   keeps the compiler happy. *)
		RETURN 0
	ELSE
		(* Check if this identifier is already in the symbol table. *)
		IF (InTable (IdrToAdd) > 0) THEN
			(* Error! *)
			RETURN 0
		ELSE
			(* Symbol does not exist already, so add it to the
			   table at the next free location. *)

			(* Add one to the pointer. *)
			INC (TablePointer);

			WITH SymbolTable[TablePointer] DO
				Name := IdrToAdd;
				usage := IdrType;
				CASE usage OF
					  GlobVar     : RTSL := ReserveSpace (1);
					| ProcName    : EntryAddress := 0; 
							(* Fixed up later. *)
					| FormalParam : ProcRef := PRef;
							Position := Posn
				END
			END;

			(* Must return the actual address in the table, hence... *)
			RETURN (TablePointer)
		END
	END
END AddToSymTable;

(* -------------------------------------------------------------------------- *)

PROCEDURE LookUpInSymTable (IdrToFind : IdrChars; ExpectedType : IdrClass) : CARDINAL;

(* Looks for an identifier IdrToFind in the symbol table and checks that it
   is used in the right context.  If there is a defining occurrence of a
   global variable, calls AddToSymTable. If successful, the location of the
   identifier in the symbol table is returned, otherwise 0 is returned. In
   the case of a global variable definition, the location is returned. *) 

VAR Location, 
    NewVarLoc      : CARDINAL;

BEGIN
	(* Check if this identifier is already in the symbol table. *)
	Location := InTable (IdrToFind);
	
	(* Now check that it is being used in the expected context. *)
	IF (Location > 0) AND (ExpectedType = SymbolTable[Location].usage)  THEN
		(* OK, it is. *)
		RETURN Location
	ELSE
		(* Might be a variable declaration, or could be an error. *)
		IF ExpectedType = GlobVar THEN
			(* OK - Add to the symbol table and return location. *)
			RETURN (AddToSymTable (IdrToFind, ExpectedType, 0, 0))
		ELSE
			(* Error case. *)
			RETURN 0
		END
	END
END LookUpInSymTable;

(* -------------------------------------------------------------------------- *)

PROCEDURE TableDump;

(* Prints out the contents of the symbol table. *)

VAR Counter : CARDINAL;

BEGIN
	WriteLn;
	WriteLn;
	WriteString ("Symbol Table Dump");
	WriteLn;
	WriteString ("=================");
	WriteLn;
	WriteLn;
	WriteString ("Loc Symbol        Type     Entry Addr Num FPs    RTSL  Proc Ref    Position");
	WriteLn;
	WriteString ("--- ------        ----     ---------- -------    ----  --------    --------");
	WriteLn;
	WriteLn;
	(* Only print out the bit with entries in. *)
	FOR Counter := 1 TO TablePointer DO
		WriteCard (Counter, 3);
		Write (" ");
		WITH SymbolTable[Counter] DO
			WriteString (Name);
			CASE usage OF
				  GlobVar     : WriteString ("  GlobVar         N/A     N/A");
						WriteCard (RTSL, 8);
						WriteString ("       N/A         N/A");
				| ProcName    : WriteString ("  ProcName   ");
						WriteCard (EntryAddress, 8);
						WriteCard (NumFPs, 8);
						WriteString ("     N/A       N/A         N/A");
				| FormalParam : WriteString ("  Formal P        N/A     N/A     N/A  ");
						WriteCard (ProcRef, 8);
						WriteString ("    ");
						WriteCard (Position, 8)
			END
		END;
		WriteLn
	END;
	WriteLn;
	WriteLn
END TableDump;

(* -------------------------------------------------------------------------- *)

BEGIN
	(* Initialise the pointer into the symbol table. *)
	TablePointer := 0
END Symtable.
