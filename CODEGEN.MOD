IMPLEMENTATION MODULE Codegen;

(* MSL code generation module.

   Author : Simon Prickett
   Module : CS310, Programming Language Implementation
   FAO    : Dr Elsworth
   Date   : 05/01/96
*)

(* -------------------------------------------------------------------------- *)

(* Get the program store and max allowed size for program store. *)

FROM TM IMPORT
	TMopcode, PS, PSsize;

(* Might need to halt the system if a bad call to any of these procs
   happens, so... *)

FROM SYSTEM IMPORT
	CCALL;

FROM InOut IMPORT
	WriteString, WriteLn;

(* -------------------------------------------------------------------------- *)

PROCEDURE FatalError;

(* Simple procedure to stop the compiler with an internal error if one of
   the cg procedures is passed something it can't handle. *)

BEGIN
	WriteString ("     Internal error : bad TM opcode passed to cg1/2/3.");
	WriteLn;
	WriteString ("     MSL compiler terminated abnormally.");
	WriteLn;
	WriteLn;
	(* Halt *)
	CCALL ("exit", 1)
END FatalError;

(* -------------------------------------------------------------------------- *)

PROCEDURE PSFullError;

(* Simple procedure to stop the compiler with an internal error if one of
   the cg procedures overflows the program store. *)

BEGIN
	WriteString ("     Internal error : Program store is full.");
	WriteLn;
	WriteString ("     MSL compiler terminated abnormally.");
	WriteLn;
	WriteLn;
	(* Halt *)
	CCALL ("exit", 1)
END PSFullError;

(* -------------------------------------------------------------------------- *)

PROCEDURE AddToProgStore (ThingToAdd : CARDINAL);

(* Adds ThingToAdd to the program store and stops execution if this 
   causes program store overflow. *)

BEGIN
	IF PSPointer <= PSsize THEN
		PS[PSPointer] := ThingToAdd;
		INC (PSPointer)
	ELSE
		PSFullError
	END
END AddToProgStore;

(* -------------------------------------------------------------------------- *)

PROCEDURE cg1 (Code : TMopcode); 
 
(* Use cg1 to generate TM code for a '1 item instruction' eg RTN.
   Full list of all such things : LI, SI, WNUM, RNUM, WTXT, RTXT,
				  WNL, HDR, RTN, STOP, ADDop, 
				  SUBop, MULTop, DVDop, LTop,
				  LEop, GTop, GEop, NEop, EQop,
				  ORop, ANDop *) 

VAR IntCode : CARDINAL;

BEGIN
	(* What opcode are we processing? *)
	IntCode := ORD (Code);

	(* Check for bad value passed to this procedure. *)
	IF (IntCode < 9) OR (IntCode > 30) THEN
		FatalError
	END; 

	(* Now put this code into the program store at the current location. *)
	AddToProgStore (IntCode)
END cg1;
 
(* -------------------------------------------------------------------------- *)

PROCEDURE cg2 (Code : TMopcode; Card : CARDINAL);   
 
(* Use cg2 to generate TM code for a '2 item instruction' eg LC N.
   Full list of all such things : LG, SG, LL, SL, LC, J, JF, JT *)

VAR IntCode : CARDINAL [0..30];

BEGIN
	(* What opcode are we processing? *)
	IntCode := ORD (Code);

	(* Check for bad value passed to this procedure. *)
	IF (IntCode > 7) THEN
		FatalError
	END;
 
	(* Now put this code into the program store at the current location. *)
	AddToProgStore (IntCode);
	AddToProgStore (Card)
END cg2;

(* -------------------------------------------------------------------------- *)

PROCEDURE cg3 (Code : TMopcode; EntryAddr, NParams : CARDINAL);   
 
(* Use cg3 to generate TM code for a '3 item instruction' eg JSR EA NumParams
   JSR being the only thing that this is used for. *)

BEGIN
	IF Code <> JSR THEN
		FatalError
	END;

	(* Process JSR. *)
	AddToProgStore (8);
	AddToProgStore (EntryAddr);
	AddToProgStore (NParams)
END cg3;

(* -------------------------------------------------------------------------- *)

PROCEDURE GetPSPointerVal () : CARDINAL;

(* Returns the value of PSPointer - use only for forward jump fixing. *)

BEGIN
	RETURN PSPointer
END GetPSPointerVal;

(* -------------------------------------------------------------------------- *)

PROCEDURE FixJump (Locn : CARDINAL);

(* Inserts the value of PSPointer into the program store at Locn.  Used for
   fixing up forward jumps. *)

BEGIN
	PS[Locn + 1] := PSPointer
END FixJump;

(* -------------------------------------------------------------------------- *)

BEGIN
	(* Initialise pointer into the program store. *)
	PSPointer := 1
END Codegen.
