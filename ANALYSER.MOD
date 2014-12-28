IMPLEMENTATION MODULE Analyser;

(* MSL RDSA code with context free syntax analysis.
   Updated to include context sensitive analysis and code generation.

   Author : Simon Prickett
   Module : CS310, Programming Language Implementation
   FAO    : Dr Elsworth
   Date   : 26/11/95 - modified for final part of coursework, 2/01/96.

   Algorithm for CF analysis :

   To cope with errors, this module sets Recovering to TRUE whenever an
   error is encountered.  Symbol skipping then occurs until an important
   symbol (one which cannot be skipped) is found.  From here, MustBe must
   find the token that it was expecting TWICE before error reporting is
   turned back on. 

   Additions for CS analysis :

   This module now makes extensive use of the symbol table module to perform
   context sensitive analysis and reports CS errors through the ContextError
   procedure.  If Recovering is TRUE, these error messages are suppressed.
   Finding a CS error does not set Recovering to TRUE.

   Additions for code generation :

   This module now generates code as it goes - the resulting TM program should
   only be interpreted if TotalErrors = 0 at the end, otherwise the assembler
   generated will not work.

*)

(* -------------------------------------------------------------------------- *)

FROM InOut IMPORT
	Write, WriteString, WriteLn;

FROM Lex IMPORT
	CurrentIntVal, CurrentToken, FindNextSym, Token, GetCurrentSymRep,
	CurrentOperator, Operator;

(* Using my own WriteToken as this allows for better error messages than the
   one that was provided. *)

FROM Utils IMPORT
	WriteToken;

FROM Source IMPORT
	LineChars, PosInSourceLine;

(* The following are all for access to the Symbol Table. *)

FROM Symtable IMPORT
	HowManyParams, StoreNumParams, GetIdrName, IdrChars, IdrClass, 
	GetRTSL, GetEntryAddress, GetProcRef, AddToSymTable, LookUpInSymTable,
	GetPosition, StoreEntryAddr;

(* Data store access function. *)

FROM Datastore IMPORT
	StoreText, ReserveSpace;

(* Code generation stuff. *)

FROM Codegen IMPORT
	cg1, cg2, cg3, GetPSPointerVal, FixJump;

FROM TM IMPORT
	TMopcode;

(* -------------------------------------------------------------------------- *)

TYPE TokSet = SET OF Token;


(* ErrorCause is used for telling the Error procedure what sort of CF error
   was found. *)

TYPE ErrorCause = (SymMissing, BadStmtStarter, BadOperand, UnexpectedStop,
		   RparMissing, AssignSymMissing, BadReserve);

(* CFErrorCause is used for telling ContextError what sort of CS error was
   found. *)

TYPE CFErrorCause = (ProcDefined, FPUsed, Call2UdProc, WrongParamCount,
		     OutOfScope, BadUseOfProc);

(* ImportantSyms contains the symbols that are considered important enough
   to stop symbol skipping. *)

CONST ImportantSyms = TokSet { WhileSym, IfSym, CallSym, ReadSym, WriteSym,
			       Stop, ReserveSym, ProcSym, Idr };

(* A flag that determines if error recovery is taking place, used to suppress
   error messages until the system can get back into a known state. *)

VAR Recovering : BOOLEAN;

(* Used to make sure that MustBe finds 2 valid symbols before kicking the
   error printing back in. *)

CONST SymsToFind = 1;

VAR ValidSymsFound : CARDINAL [0..SymsToFind];

(* AddrModes is an enumerated type of the addressing modes for a variable. *)

TYPE AddrModes = (Global, Local, Stack);

(* NowProcessing is used to keep track of what's currently being processed.
   If it's the main program, it is set to 0, if it's a procedure, it's set to
   the Symbol table location of that procedure.  This is used to check that 
   formal parameters are used in scope. *)

VAR NowProcessing : CARDINAL;

(* -------------------------------------------------------------------------- *)

PROCEDURE MustBe (ExpectedToken : Token);

(* Used to check whether the current token is the one that was expected,
   calls Error and starts symbol skipping if this is not the case.  Recovering
   is set to FALSE if the token expected is found, and this re-enables error
   message printing. *)

BEGIN
	IF (CurrentToken () = ExpectedToken) THEN
		FindNextSym;
		IF ValidSymsFound < SymsToFind THEN
			INC (ValidSymsFound)
		ELSE
			Recovering := FALSE
		END
	ELSE
		CASE ExpectedToken OF
			  Rpar       : Error (RparMissing, ExpectedToken)
			| AssignSym  : Error (AssignSymMissing, AssignSym);
			| ReserveSym : Error (BadReserve, ReserveSym);
		ELSE
			  (* General case for anything else *)
			  Error (SymMissing, ExpectedToken)
		END
	END
END MustBe;

(* -------------------------------------------------------------------------- *)

PROCEDURE TokenIs (PossibleToken : Token) : BOOLEAN;

(* Used to check if the current token is equal to PossibleToken. Does not
   call Error. *)

BEGIN
	IF (CurrentToken () = PossibleToken) THEN
		FindNextSym;
		RETURN TRUE
	ELSE
		RETURN FALSE
	END
END TokenIs;

(* -------------------------------------------------------------------------- *)

PROCEDURE JunkEater;

(* JunkEater performs the symbol skipping - when called, it eats up and 
   ignores all symbols until one is found that is a member of ImportantSyms
   set.  Stop is treated differently, as the parsing must always stop at the
   first Stop symbol found. *)

BEGIN
	IF CurrentToken () <> Stop THEN
		REPEAT
			FindNextSym
		UNTIL (CurrentToken () IN ImportantSyms)
	END
END JunkEater;

(* -------------------------------------------------------------------------- *)

PROCEDURE Error (Fault : ErrorCause; Tok : Token);

(* Error prints error messages if the Recovering flag is set to FALSE, and
   then sets this flag to TRUE to show that new calls to Error should not
   print messages. Also sets ValidSymsFound to 0 to make sure that MustBe
   finds two symbols before starting error notification again. *)

VAR Pos : CARDINAL;

BEGIN
	(* Do not produce an error if error messages are suppressed *)
	IF NOT Recovering THEN
		INC (TotalErrors);
		Recovering := TRUE;
		(* Reset the counter of valid symbols *)
		ValidSymsFound := 0;
		(* This is a pretty print type thing *)
		FOR Pos := 1 TO PosInSourceLine () + 2 DO
			Write (' ')
		END;
		Write ('^');
		WriteString ("    Syntax Error : ");
		(* Produce the error message *)
		CASE Fault OF
			  SymMissing     : WriteToken (CurrentToken ());
					   WriteString (" found where ");
					   WriteToken (Tok);
					   WriteString (" expected.");
			| BadStmtStarter : WriteToken (Tok);
					   WriteString (" cannot start a statement.");
			| BadReserve     : WriteToken (ReserveSym);
					   WriteString (" may only be used in the first line of a program.");
			| BadOperand     : WriteToken (Tok);
					   WriteString (" cannot start an operand.");
			| RparMissing    : WriteToken (Rpar);
					   WriteString (" is missing.");
			| AssignSymMissing : WriteToken (AssignSym);
					     WriteString (" is missing.");
			| UnexpectedStop : WriteToken (Tok);
					   WriteString (" the program terminator was unexpected here.");
		END;
		WriteLn
	END
END Error;

(* -------------------------------------------------------------------------- *)

PROCEDURE ContextError (Fault : CFErrorCause; ErrorIdr : IdrChars);

(* Deals with context sensitive errors, as opposed to Error above, which 
   handles CF errors. *)

BEGIN
	(* Only report this if not recovering from a previous error - note
	   that I don't see the need for this procedure to ever set the 
	   recovering flag. *)
	IF NOT Recovering THEN
		(* Found another error, so bunk up the count. *)
		INC (TotalErrors);
		WriteString ("    Syntax Error : ");
		(* Now output the appropriate message. *)
		CASE Fault OF 
			  ProcDefined     : WriteString ("Identifier already used - invalid PROC name : "); 
			| FPUsed          : WriteString ("Identifier already used - invalid FORMAL PARAMETER name : ");
			| Call2UdProc     : WriteString ("PROC undefined : ");
			| WrongParamCount : WriteString ("Incorrect number of actual parameters for call to ");
			| OutOfScope      : WriteString ("Identifier not available in the current scope : ");
			| BadUseOfProc    : WriteString ("PROC name used incorrectly : ");
		END;
		WriteString (ErrorIdr);
		WriteLn
	END
END ContextError;

(* -------------------------------------------------------------------------- *)

PROCEDURE Program;

(* RDSA procedure for an MSL program.  Starts by setting Recovering to FALSE
   as this is the entry point to the network of RDSA procedures, so is always
   the one that is called first. ValidSymsFound is set to 2 as I presume no
   errors to start with. *)

VAR FixUp,               (* Used for storage of forward jump location to fix. *)
    DontCare : CARDINAL; (* Used to catch output of ReserveSpace that we're
			    not interested in at present. *)

BEGIN
	ValidSymsFound := SymsToFind;
	Recovering := FALSE;
	
	(* Initialise the scope variable for the main program. *)
	NowProcessing := 0;

	FindNextSym;
	IF TokenIs (ReserveSym) THEN
		(* Allocate space for this reserve request - must be done before
		   the MustBe as that eats the token up and the value can't be
		   got at otherwise. *)
		IF CurrentToken () = Int THEN
			DontCare := ReserveSpace (CurrentIntVal ())
		END;
		MustBe (Int)
	END;
	(* If there are procedures, need to create a jump to after them.
	   Don't know the destination yet, so need to store PS location for
	   this instruction. *)
	FixUp := GetPSPointerVal();
	cg2 (J, 0);
	WHILE TokenIs (ProcSym) DO
		ProcDec;
		(* The code below checks for junk between PROC declarations *)
		IF (CurrentToken () <> ProcSym) AND (NOT (CurrentToken () IN ImportantSyms)) THEN
			Error (BadStmtStarter, CurrentToken ());
			(* Call JunkEater to get back to a valid statement
			   starter *)
			JunkEater
		END 
	END;

	(* Put the scope variable back to main program setting. *)
	NowProcessing := 0;

	(* Remember to fill in the open jump to the main code block from
	   earlier. *)

	FixJump (FixUp);

	Series (TokSet {Stop});
	IF CurrentToken () = Stop THEN
		(* Stop the code generation. *)
		cg1 (STOP)
	ELSE
		Error (SymMissing, Stop)
	END
END Program;

(* -------------------------------------------------------------------------- *)

PROCEDURE ProcDec;

(* RDSA procedure for an MSL procedure declaration. *)

VAR PotentialIdr : IdrChars;
    ProcLoc,
    ParamLoc,
    ParamCount   : CARDINAL;

BEGIN
	(* Store the possible identifier for use later. *)
	GetIdrName (PotentialIdr);
	MustBe (Idr);
	(* Now add to the symbol table. *)
	ProcLoc := AddToSymTable (PotentialIdr, ProcName, 0, 0);
	IF ProcLoc = 0 THEN
		ContextError (ProcDefined, PotentialIdr)
	ELSE
		(* Store the current procedure location for scope checks. *)
		NowProcessing := ProcLoc;

		(* Store the entry address for this procedure. *)
		StoreEntryAddr (ProcLoc)
	END;
	IF TokenIs (Lpar) THEN
		(* Start counting formal parameters. *)
		ParamCount := 1;
		GetIdrName (PotentialIdr);
		MustBe (Idr);
		ParamLoc := AddToSymTable (PotentialIdr, FormalParam, ProcLoc, ParamCount);
		IF ParamLoc = 0 THEN
			ContextError (FPUsed, PotentialIdr)
		END;
		WHILE TokenIs (Comma) DO
			GetIdrName (PotentialIdr);
			MustBe (Idr);
			INC (ParamCount);
			ParamLoc := AddToSymTable (PotentialIdr, FormalParam, ProcLoc, ParamCount);
			IF ParamLoc = 0 THEN
				ContextError (FPUsed, PotentialIdr)
			END
		END;
		(* Now store the total number of formal paramters for this procedure. 
		   Only do this if the procedure was valid! *)
		IF ProcLoc > 0 THEN
			StoreNumParams (ProcLoc, ParamCount)
		END;
		MustBe (Rpar)
	END;
	Series (TokSet {EndSym});
	MustBe (EndSym);

	(* Generate the return call. *)
	cg1 (RTN);

	(* Count this as a procedure. *)
	INC (NumProcs)
END ProcDec;

(* -------------------------------------------------------------------------- *)

PROCEDURE Series (ExpectedTerminators : TokSet);

(* RDSA procedure for an MSL series - TokSet is used to pass in a set of
   expected terminators for each series.  A set is used as more than one
   thing can terminate some series, eg ElseSym or FiSym in the case of an
   IF statement. Stop is treated differently as it has to end a program, so
   should always be on the lookout for it. *)

BEGIN
	REPEAT
		Stmt
	UNTIL (CurrentToken () IN ExpectedTerminators) OR (CurrentToken () = Stop);
	IF (CurrentToken () = Stop) AND (NOT (Stop IN ExpectedTerminators)) THEN
		Error (UnexpectedStop, Stop)
	END
END Series;

(* -------------------------------------------------------------------------- *)

PROCEDURE Stmt;

(* RDSA procedure for a statement in MSL. *)

BEGIN
	CASE CurrentToken () OF
		  Idr      : AssignSt;
		| WhileSym : WhileSt;
		| IfSym    : IfSt;
		| CallSym  : CallSt;
		| ReadSym  : ReadSt;
		| WriteSym : WriteSt
		
	ELSE
		(* Check for the Stop symbol and flag it as an unexpected Stop
		   rather than a bad statement starter *)
		CASE CurrentToken () OF
			  Stop       : Error (UnexpectedStop, Stop);
				       (* No call to JunkEater here as there is no
					  need to process beyond the first Stop symbol
					  encountered *)
			| ReserveSym : Error (BadReserve, ReserveSym);
				       (* RESERVE not allowed in program body *) 
				       JunkEater;
		ELSE
				Error (BadStmtStarter, CurrentToken ());
				JunkEater
		END
	END;
	(* Count this as a statement *)
	INC (NumStmts)
END Stmt;

(* -------------------------------------------------------------------------- *)

PROCEDURE AssignSt;

(* RDSA procedure for an assignment statement in MSL. *)

VAR AMode : AddrModes;
    Loc   : CARDINAL;

BEGIN
	AddressOfVariable (AMode, Loc); 
	MustBe (AssignSym);
	Expr;
	CASE AMode OF
		  Global : cg2 (SG, Loc);
		| Local  : cg2 (SL, Loc);
		| Stack  : cg1 (SI)
	END
END AssignSt;

(* -------------------------------------------------------------------------- *)

PROCEDURE WhileSt;

(* RDSA procedure for MSL while statement. *)

VAR LoopStart,             (* Used to store location for start of loop. *)
    FixUp      : CARDINAL; (* Used to fix the forward jump needed for a while. *)

BEGIN
	MustBe (WhileSym);

	(* Save this location in the program store for later use. *)
	LoopStart := GetPSPointerVal ();

	Expr;
	MustBe (DoSym);

	(* Put a jump to the loop exit here and remember to patch it up 
	   later. *)
	FixUp := GetPSPointerVal ();
	cg2 (JF, 0);

	Series (TokSet {OdSym});
	MustBe (OdSym);
	
	(* Now put a jump back to the start of the while loop in here. *)
	cg2 (J, LoopStart);

	(* Now fix up that loop exit reference outstanding from before. *)
	FixJump (FixUp) 
END WhileSt;

(* -------------------------------------------------------------------------- *)

PROCEDURE IfSt;

(* RDSA procedure for MSL if statement. *)

VAR FixUp1, 
    FixUp2 : CARDINAL; (* Locations for jumps required. *)

BEGIN
	MustBe (IfSym);
	Expr;
	MustBe (ThenSym);

	(* Need a jump if false here in case the following series is not
	   executed.  This will need to be fixed up to point to the ELSE. *)

	FixUp1 := GetPSPointerVal ();
	cg2 (JF, 0);

	Series (TokSet {ElseSym, FiSym});

	IF TokenIs (ElseSym) THEN

		(* Have a jump from the previous series to end of if stmt. *)
		FixUp2 := GetPSPointerVal ();
		cg2 (J, 0);     

		(* Make the previous jump false point to here. *)
		FixJump (FixUp1);       

		Series (TokSet {FiSym});
		
		(* Now fix up the jump from the IF block to end. *)
		FixJump (FixUp2)
	ELSE
		(* Only one jump was needed, fix it up to point to the end. *)
		FixJump (FixUp1)
	END;
	MustBe (FiSym);
END IfSt;

(* -------------------------------------------------------------------------- *)

PROCEDURE CallSt;

(* RDSA procedure for MSL call statement. Augmented to check that the 
   procedure being called actually exists and that it is being passed
   the right number of actual parameters.*)

VAR PotentialIdr : IdrChars;
    ParamCount,
    Result       : CARDINAL;

BEGIN
	MustBe (CallSym);

	(* Make space for this call. *)
	cg1 (HDR);

	GetIdrName (PotentialIdr); 
	MustBe (Idr);
	Result := LookUpInSymTable (PotentialIdr, ProcName);
	IF Result = 0 THEN
		ContextError (Call2UdProc, PotentialIdr)
	END;
	(* Count parameters. *)
	ParamCount := 0;
	IF TokenIs (Lpar) THEN
		Expr;
		INC (ParamCount);
		WHILE TokenIs (Comma) DO
			Expr;
			INC (ParamCount)
		END;
		MustBe (Rpar)
	END;
	(* Now check number of parameters against symbol table, but
	   only if the procedure exists!! *)
	IF (Result > 0) AND (HowManyParams (Result) <> ParamCount) THEN
		ContextError (WrongParamCount, PotentialIdr)
	ELSE
		(* Generate code for doing the call to the proc. *)
		IF Result > 0 THEN
			cg3 (JSR, GetEntryAddress (Result), HowManyParams (Result))
		END
	END
END CallSt;

(* -------------------------------------------------------------------------- *)

PROCEDURE ReadSt;

(* RDSA Read for MSL. *)

VAR AMode : AddrModes;
    Loc   : CARDINAL;

BEGIN
	MustBe (ReadSym);
	IF TokenIs (Hash) THEN
		ContentsOfVariable;
		cg1 (RTXT)      
	ELSE
		AddressOfVariable (AMode, Loc);
		cg1 (RNUM);
		CASE AMode OF
			  Global : cg2 (SG, Loc);
			| Local  : cg2 (SL, Loc);
			| Stack  : cg1 (SI);
		END
	END;
	WHILE TokenIs (Comma) DO
		IF TokenIs (Hash) THEN
			ContentsOfVariable;
			cg1 (RTXT)      
		ELSE
			 AddressOfVariable (AMode, Loc);  
			cg1 (RNUM); 
			CASE AMode OF 
				  Global : cg2 (SG, Loc);
				| Local  : cg2 (SL, Loc); 
				| Stack  : cg1 (SI);
			END

		END
	END
END ReadSt;

(* -------------------------------------------------------------------------- *)

PROCEDURE WriteSt;

(* RDSA procedure for MSL write statement. *)

VAR Op : TMopcode;

BEGIN
	MustBe (WriteSym);
	IF (TokenIs (Hash)) OR (CurrentToken () = Text) THEN
		(* Dealing with a text write. *)
		Op := WTXT
	ELSE
		(* Dealing with a numeric write. *)
		Op := WNUM
	END;
	Expr;
	cg1 (Op);
	WHILE TokenIs (Comma) DO
		IF (TokenIs (Hash)) OR (CurrentToken () = Text)  THEN
			(* Dealing with a text write. *)
			Op := WTXT
		ELSE
			(* Dealing with a numeric write. *)
			Op := WNUM
		END;
		Expr;
		cg1 (Op)
	END;
	cg1 (WNL)
END WriteSt;

(* -------------------------------------------------------------------------- *)

PROCEDURE Expr;

(* RDSA procedure for MSL expression. *)

VAR Op : TMopcode;

BEGIN
	Operand;
	WHILE TokenIs (Opr) DO
		CASE CurrentOperator () OF
			  Plus   : Op := ADDop;
			| Minus  : Op := SUBop;
			| Mult   : Op := MULTop;
			| Divide : Op := DVDop;
			| LT     : Op := LTop;
			| LE     : Op := LEop;
			| GT     : Op := GTop;
			| GE     : Op := GEop;
			| NE     : Op := NEop;
			| EQ     : Op := EQop;
			| Or     : Op := ORop;
			| And    : Op := ANDop;
		END;
		Operand;
		cg1 (Op)
	END
END Expr;

(* -------------------------------------------------------------------------- *)

PROCEDURE Operand;

(* RDSA procedure for MSL operand. *)

VAR Len,                 (* Length of the text. *)
    TextLoc : CARDINAL;  (* Location of the text in data store. *)
    TheText : LineChars; (* The content of the text. *)
    Loc : CARDINAL;
    AMode : AddrModes;

BEGIN
	CASE CurrentToken () OF
		  Int  : FindNextSym;
			 cg2 (LC, CurrentIntVal ());
		| Text : (* Need to get the length of the text and its 'value'. *)
			 GetCurrentSymRep (TheText, Len);
			 (* Now reserve some space in the data store for this. 
			    Len appears to be the length of the text and enclosing
			    quotes, so take 1 off as we want length + 1 for the
			    text length bit. *)
			 TextLoc := ReserveSpace (Len-1); 
			 (* Copy the length of the string and content into
			    data store. Don't want the quotes, so Len-2 *)
			 StoreText (TheText, Len-2, TextLoc);
			 cg2 (LC, TextLoc);
			 FindNextSym;
		| Idr  : ContentsOfVariable;
		| Lpar : FindNextSym;
			 Expr;
			 MustBe (Rpar)
	ELSE
		Error (BadOperand, CurrentToken ());
	END
END Operand;

(* -------------------------------------------------------------------------- *)

PROCEDURE ContentsOfVariable;

(* This, and the procedure below, replace the old Variable procedure. *)

VAR PotentialIdr : IdrChars;
    Result       : CARDINAL;

BEGIN
	GetIdrName (PotentialIdr);
	MustBe (Idr);
	Result := LookUpInSymTable (PotentialIdr, GlobVar);
	IF Result = 0 THEN
		(* Try to see if this is a formal parameter, and if so
		   whether it is in scope. *)
		Result := LookUpInSymTable (PotentialIdr, FormalParam);
		IF Result = 0 THEN
			(* This is a bad variable - probably a procedure. *)
			ContextError (BadUseOfProc, PotentialIdr)
		ELSE
			(* This will be a formal parameter, check if it's in
			   scope. *)
			IF GetProcRef (Result) <> NowProcessing THEN
				ContextError (OutOfScope, PotentialIdr) 
			ELSE
				(* Generate some code for formal parameter. *)
				cg2 (LL, GetPosition (Result))
			END
		END
	ELSE
		(* This is a global, generate code for this. *)
		cg2 (LG, GetRTSL (Result))
	END;
	IF TokenIs (Exc) THEN
		Operand;
		(* Add up to get address. *)
		cg1 (ADDop);
		(* Now need to do a load indirect. *)
		cg1 (LI)
	END
END ContentsOfVariable;

(* -------------------------------------------------------------------------- *)

PROCEDURE AddressOfVariable (VAR Mode : AddrModes; VAR Locn : CARDINAL);

(* This is the second procedure to replace the old Variable procedure.
   Locn is CARDINAL not INTEGER as suggested on the tutorial sheet, as
   it can never be negative. *)

VAR PotentialIdr : IdrChars;
    Result       : CARDINAL;

BEGIN
	GetIdrName (PotentialIdr);
	MustBe (Idr);
	Result := LookUpInSymTable (PotentialIdr, GlobVar);
	IF Result = 0 THEN
		(* Try to see if this is a formal parameter, and if so
		   whether it is in scope. *)
		Result := LookUpInSymTable (PotentialIdr, FormalParam);
		IF Result = 0 THEN
			(* This is a bad variable - probably a procedure. *) 
			ContextError (BadUseOfProc, PotentialIdr)
		ELSE
			(* This will be a formal parameter, check if it's in 
			   scope. *)
			IF GetProcRef (Result) <> NowProcessing THEN
				ContextError (OutOfScope, PotentialIdr)
			ELSE
				(* Found a formal parameter - set Mode. *)
				Mode := Local;
				Locn := GetPosition (Result)
			END
		END
	ELSE
		(* Found a global variable - set Mode accordingly. *)
		Mode := Global;
		Locn := GetRTSL (Result)
	END;
	IF TokenIs (Exc) THEN
		(* Generate code for getting the variable address. *)
		CASE Mode OF
			  Global : cg2 (LG, Locn);
			| Local  : cg2 (LL, Locn);
		END;
		Operand;
		(* Set to stack mode. *)
		Mode := Stack;
		(* Add up *)
		cg1 (ADDop)
	END
END AddressOfVariable;

(* -------------------------------------------------------------------------- *)

END Analyser.
