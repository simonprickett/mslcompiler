IMPLEMENTATION MODULE Utils;

(* Utility module to go with the MSL analyser.
   
   Author : Simon Prickett
   Module : CS310, Programming Language Implementation
   FAO    : Dr Elsworth
   Date   : 26/11/95
*)

(* -------------------------------------------------------------------------- *)

FROM InOut IMPORT
	Write, WriteString, WriteInt, WriteLn;

FROM Lex IMPORT
	CurrentIntVal, CurrentOperator, Token, Operator;

FROM Listing IMPORT
	WriteOperator;

(* -------------------------------------------------------------------------- *)

PROCEDURE Header;

(* Prints a header banner for the output of the Analyser. *)

BEGIN
	WriteString ("****** STARTING MSL COMPILER ******");
	WriteLn;
	WriteLn
END Header;

(* -------------------------------------------------------------------------- *)

PROCEDURE Footer;

(* Prints a footer banner for the output of the Analyser. *)

BEGIN
	WriteLn;
	WriteLn;
	WriteString ("******  END OF MSL COMPILER  ******");
	WriteLn;
	WriteLn
END Footer;

(* -------------------------------------------------------------------------- *)

PROCEDURE Statistics (ProcsFound, StmtsFound, ErrorsFound : CARDINAL);

(* Prints a brief statistical summary of what was found. *)

BEGIN
	WriteLn;
	WriteLn;
	WriteString ("Statistics :");
	WriteLn;
	WriteString ("============");
	WriteLn;
	WriteLn;
	WriteString ("The program contained ");
	WriteInt (ProcsFound, 0);
	IF ProcsFound = 1 THEN
		WriteString (" procedure, ")
	ELSE
		WriteString (" procedures, ")
	END;
	WriteInt (StmtsFound, 0);
	IF StmtsFound = 1 THEN
		WriteString (" statement, and ")
	ELSE
		WriteString (" statements, and ")
	END;
	WriteInt (ErrorsFound, 0);
	IF ErrorsFound = 1 THEN
		WriteString (" syntax error.")
	ELSE
		WriteString (" syntax errors.")
	END;
	WriteLn;
	WriteLn
END Statistics;

(* -------------------------------------------------------------------------- *)

PROCEDURE WriteToken (ToWrite : Token);

(* Takes one of the members of the enumerated type Token and turns it into
   a text string representation.  Produces slightly more readable output
   than the WriteToken defined elsewhere. *)

BEGIN
	CASE ToWrite OF
		  Idr        : WriteString ("Identifier");
		| Int        : WriteInt (CurrentIntVal (), 0);
		| Text       : WriteString ("Text");
		| Opr        : CASE CurrentOperator () OF
					  EQ : Write ("=");
					| LT : Write ("<");
					| GT : Write (">");
					| LE : WriteString ("<=");
					| GE : WriteString (">=");
					| NE : WriteString ("<>");
					| Or : Write ("%");
					| And : Write ("&");
					| Plus : Write ("+");
					| Minus : Write ("-");
					| Mult : Write ("*");
					| Divide : Write ("/");
			       ELSE
					(* Should never be called, but included in case. *)
					WriteString ("Unknown Operator")
			       END; 
		| AssignSym  : WriteString (":=");
		| Lpar       : Write ("(");
		| Rpar       : Write (")");
		| Comma      : Write (",");
		| Stop       : Write (".");
		| Exc        : Write ("!");
		| Hash       : Write ("#");
		| IfSym      : WriteString ("IF");
		| ThenSym    : WriteString ("THEN");
		| ElseSym    : WriteString ("ELSE");
		| FiSym      : WriteString ("FI");
		| WhileSym   : WriteString ("WHILE");
		| DoSym      : WriteString ("DO");
		| OdSym      : WriteString ("OD");
		| ProcSym    : WriteString ("PROC");
		| EndSym     : WriteString ("END");
		| CallSym    : WriteString ("CALL");
		| WriteSym   : WriteString ("WRITE");
		| ReadSym    : WriteString ("READ");
		| ReserveSym : WriteString ("RESERVE")
	ELSE
		(* Should never get called as the lexical analyser should
		   trap such errors... *)

		WriteString ("Unknown Symbol")
	END
END WriteToken;

(* -------------------------------------------------------------------------- *)

END Utils.
