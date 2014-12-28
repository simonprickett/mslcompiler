IMPLEMENTATION MODULE Datastore;

(* Deals with managing allocation of the TM data store.

   Author : Simon Prickett
   Module : CS310, Programming Language Implementation
   FAO    : Dr Elsworth
   Date   : 05/01/96
*)

(* -------------------------------------------------------------------------- *)

FROM TM IMPORT
	DS, DSsize;

FROM InOut IMPORT
	Write, WriteCard, WriteLn, WriteString;

FROM SYSTEM IMPORT
	CCALL;

FROM Source IMPORT
	LineChars;

(* Pointer into the dataflow area - +1 used to allow checking to see if we
   have run off the end of the DS. *)

VAR DSPointer : CARDINAL [1..DSsize + 1];

(* -------------------------------------------------------------------------- *)

PROCEDURE DSOverFlowError;

(* Simple procedure to notify the user when the data store is full. *)

BEGIN
	WriteString ("    Internal Error : Data store full.");
	WriteLn;
	WriteString ("    MSL compiler terminated abnormally.");
	WriteLn;
	WriteLn;
	(* Halt the compiler. *)
	CCALL ("exit", 1)
END DSOverFlowError; 

(* -------------------------------------------------------------------------- *)

PROCEDURE ReserveSpace (SpaceToReserve : CARDINAL) : CARDINAL;

(* Bumps up the DSPointer by SpaceToReserve units - returns the value of
   DSPointer. *)

BEGIN
	IF (DSPointer + SpaceToReserve) > DSsize THEN
		DSOverFlowError;
		(* The following line is never called, but keeps the compiler
		   happy. *)
		RETURN 0
	ELSE
		DSPointer := DSPointer + SpaceToReserve;
		(* Now return what DSPointer was when we started as
		   calling code will need this. *)
		RETURN DSPointer - SpaceToReserve
	END 
END ReserveSpace;

(* -------------------------------------------------------------------------- *)

PROCEDURE StoreText (TextValue : LineChars; Len, DSLoc : CARDINAL);

(* Stores the value for a text and its length bit in the data store at
   data store location starting at DSLoc.  No need to check if this will
   go off the end of the data store as space for this will already have 
   been requested using ReserveSpace. *)

VAR Counter : CARDINAL;

BEGIN
	(* Store the length indicator in the data store first. *)
	DS[DSLoc] := Len;

	(* Need to remove the quotes when putting this into the data store. *)
	FOR Counter := 2 TO Len + 1 DO
		INC (DSLoc);
		DS[DSLoc] := VAL (INTEGER, TextValue[Counter])
	END;
END StoreText;

(* -------------------------------------------------------------------------- *)

PROCEDURE DSDump;

(* Used for diagnostic purposes to dump the data store to screen/file. 
   Will only dump the used portion of the store. *)

VAR Counter : CARDINAL;

BEGIN
	WriteLn;
	WriteString ("Data Store Contents");
	WriteLn;
	WriteString ("===================");
	WriteLn;
	WriteLn;
	FOR Counter := 1 TO DSPointer - 1 DO
		(* Basic columns. *)
		IF Counter MOD 10 = 0 THEN
			WriteLn
		END;
		WriteCard (Counter, 3);
		Write (":");
		WriteCard (DS[Counter], 3)
	END;
	WriteLn;
	WriteLn
END DSDump;

(* -------------------------------------------------------------------------- *)

BEGIN
	(* Initialise the pointer into the data store. *)
	DSPointer := 1
END Datastore.
