
include std/io.e
include std/filesys.e
include std/convert.e
include std/sequence.e
include std/map.e as m

sequence symbols = "{}[]().,;+-*/&|<>=~"
sequence keywords = {"class","constructor","function","method","field","static","var","int","char","boolean","void","true","false","null","this","let","do","if","else","while","return"}

puts(SCREEN, "please enter the path to the input jack files directory:\n")
-- get the path to the input files directory.
sequence path = gets(0)
-- get the path without the \n at the end.
path = path[1..$-1]

puts(SCREEN, "\nplease enter the path to the output files directory:\n")
-- get the path to the destination directory.
sequence pathDest = gets(0)
-- get the path without the \n at the end.
pathDest = pathDest[1..$-1]

-- for the tokenizer to check char by char.
atom currentChar

-- for the parser to check token by token.
sequence currentToken
sequence currentTokenElem

-- to hold the current number of file for translation.
integer currentInputFileNum

-- to hold the number of the result file for the current input file.
integer currentresultFileNum

-- to hold the class name, useful when calling methods and functions.
sequence currentClassName

-- indices for symbol tables elements
integer staticIndex, fieldIndex
integer argIndex, varIndex

-- counters for program flow labels
integer ifLabelCounter, whileLabelCounter

-- hash maps for the symbol tables
map classScopeST, subroutineScopeST

----------------------------
-- input jack files setup --
----------------------------

sequence folderName
sequence dirInfo
sequence jackFilesNames = {}


-- if input was a path for directory set the input and output file accordingly.
folderName = filename(path)
dirInfo = dir(path)

-- get all the jack file names from the directory and put them in a sequence of strings.
for i = 1 to length(dirInfo) do  
	if length(dirInfo[i][D_NAME]) > 5 and equal(dirInfo[i][D_NAME][$-4..$],".jack") and match("a", dirInfo[i][D_ATTRIBUTES]) then
		jackFilesNames = append(jackFilesNames, dirInfo[i][D_NAME])
	end if
end for
	
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
-- here we start the program just by activating the two main functions, the tokenizer and after that the parser.
----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
tokenizer()

parser()
	
------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------
-- this is the main function of the tokenizer that uses "state" functions of the automat for finding tokens.
------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------

procedure tokenizer()
	---------------------------------------
	-- start of tokenizer for every file --
	---------------------------------------

	for i = 1 to length(jackFilesNames) do  

		currentInputFileNum = open(path & '\\' & jackFilesNames[i], "r")

		if currentInputFileNum = -1 then
			puts(1, "Can't open result file\n")
			abort(1)
		end if
		
		currentresultFileNum = open(pathDest & '\\' & jackFilesNames[i][1..$-5] & "T.xml", "w")

		if currentresultFileNum = -1 then
			puts(1, "Can't open result file\n")
			abort(1)
		end if
		
		-- start of writing to result file.
		printf(currentresultFileNum, "<tokens>\n")
		
		currentChar = getc(currentInputFileNum)
		-- starting from state 0 of the automat.
		Q0()
		
		printf(currentresultFileNum, "</tokens>\n")
		
		
		close(currentInputFileNum)
		close(currentresultFileNum)
		
	end for
end procedure
-------------------------------
-- automat for making tokens --
-------------------------------

-- starting state to check what kind of token we might make.
procedure Q0()
	while currentChar != EOF do
		if currentChar = '/' then
			Q1()
		elsif (currentChar >= 'a' and currentChar <= 'z') or (currentChar >= 'A' and currentChar <= 'Z') or (currentChar = '_') then
			Q6()
		elsif match({currentChar}, symbols) then
			Q7()
		elsif match({currentChar}, "0123456789") then
			Q8()
		elsif currentChar = '"' then
			Q9()
		else
			currentChar = getc(currentInputFileNum)
		end if
	end while
end procedure

-- this state is in case of the char "/", we need to make sure whether it is a start of a comment or just the symbol.
procedure Q1()
	currentChar = getc(currentInputFileNum)
	if currentChar != EOF then
		if currentChar = '/' then
			Q2()
		elsif currentChar = '*' then
			Q3()
		else
			printf(currentresultFileNum, "<symbol> / </symbol>\n")
		end if
	else
		printf(currentresultFileNum, "<symbol> / </symbol>\n")
	end if
	
end procedure

-- this state is when we know for sure that we are in a "//" type of comment, we wait until the file comes to a \n to start looking for tokens again.
procedure Q2()
	currentChar = getc(currentInputFileNum)
	while currentChar != EOF do
		if currentChar = '\n' then
			return
		else
			currentChar = getc(currentInputFileNum)
		end if
	end while
end procedure

-- this state is for the case when we found "/*" and we suspect that it might be a "/** ... */" type of comment.
procedure Q3()
	currentChar = getc(currentInputFileNum)
	if currentChar != EOF then
		if currentChar = '*' then
			Q4()
		else
			printf(currentresultFileNum, "<symbol> / </symbol>\n")
			printf(currentresultFileNum, "<symbol> * </symbol>\n")
		end if
	end if
end procedure

-- if we found in Q3 another "*" then we know that we start a "/** ... */" comment so we wait to find a "*" to maybe finish the comment.
procedure Q4()
	currentChar = getc(currentInputFileNum)
	while currentChar != EOF do
		if currentChar = '*' then
			Q5()
			return
		else
			currentChar = getc(currentInputFileNum)
		end if
	end while
end procedure

-- after we found a "*" in Q4 we check if this is really the end of the comment or if its just a random "*" in the comment.
procedure Q5()
	currentChar = getc(currentInputFileNum)
	if currentChar != EOF then
		if currentChar = '/' then
			currentChar = getc(currentInputFileNum)
			return
		elsif currentChar = '*' then
			Q5()
		else
			Q4()
		end if
	end if
end procedure

-- this state takes care of keyword and identifier tokens, we keep on receiving chars until the char does'nt match
-- the requirements for this kind of tokens (for example a space or "\n"),
-- and then we check: if its possibly a keyword we make a corresponding token and only else we make it an id token.
procedure Q6()
	sequence token = {}
	while currentChar != EOF do
		if not((currentChar >= 'a' and currentChar <= 'z') or (currentChar >= 'A' and currentChar <= 'Z') or (match({currentChar}, "0123456789_"))) then
			if match({token}, keywords) then
				printf(currentresultFileNum, "<keyword> %s </keyword>\n",{token})
			else
				printf(currentresultFileNum, "<identifier> %s </identifier>\n",{token})
			end if
			return
		end if
		token = token & currentChar
		currentChar = getc(currentInputFileNum)
	end while
	printf(currentresultFileNum, "<identifier> %s </identifier>\n",{token})
	
end procedure

-- this state takes care of symbol tokens (and checks if it is 1 of the special symbols on xml).
procedure Q7()
	if currentChar = '<' then
		printf(currentresultFileNum, "<symbol> &lt; </symbol>\n")
	elsif currentChar = '>' then
		printf(currentresultFileNum, "<symbol> &gt; </symbol>\n")
	elsif currentChar = '&' then
		printf(currentresultFileNum, "<symbol> &amp; </symbol>\n")
	else
		printf(currentresultFileNum, "<symbol> %s </symbol>\n", {currentChar})
	end if
	currentChar = getc(currentInputFileNum)
end procedure

-- this state takes care of integer constants by receiving chars until a non digit char appears.
procedure Q8()
	sequence token = {}
	while currentChar != EOF do
		if not(match({currentChar}, "0123456789")) then
			printf(currentresultFileNum, "<integerConstant> %s </integerConstant>\n",{token})
			return
		end if
		token = token & currentChar
		currentChar = getc(currentInputFileNum)
	end while
	printf(currentresultFileNum, "<integerConstant> %s </integerConstant>\n",{token})
end procedure

-- this state takes care of string constans simply by ignoring any char after the opening double quote symbol and waiting to find the closing double qoute symbol.
procedure Q9()
	sequence token = {}
	currentChar = getc(currentInputFileNum)
	while not(currentChar = EOF or currentChar = '"') do
		token = token & currentChar
		currentChar = getc(currentInputFileNum)
	end while
	printf(currentresultFileNum, "<stringConstant> %s </stringConstant>\n",{token})
	currentChar = getc(currentInputFileNum)
end procedure




------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------
-- this is the main function of the parser that uses a grammar so every set of production rules for a string is represented by a function.
------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------

procedure parser()
	----------------------
	-- start of parsing --
	----------------------
	for i = 1 to length(jackFilesNames) do  

		currentInputFileNum = open(pathDest & '\\' & jackFilesNames[i][1..$-5] & "T.xml", "r")

		if currentInputFileNum = -1 then
			puts(1, "Can't open result file\n")
			abort(1)
		end if
		
		currentresultFileNum = open(pathDest & '\\' & jackFilesNames[i][1..$-5] & ".vm", "w")

		if currentresultFileNum = -1 then
			puts(1, "Can't open result file\n")
			abort(1)
		end if
		
		-- start of parsing --
		currentToken = gets(currentInputFileNum)
		
		-- the root of the grammar is the class string.
		class()
		
		
		-- end of parsing for current file --
		
		close(currentInputFileNum)
		delete_file(pathDest & '\\' & jackFilesNames[i][1..$-5] & "T.xml")
		close(currentresultFileNum)
		
	end for
end procedure

-- the root string, contains only one production rule.
procedure class()
	classScopeST = m:new()
	ifLabelCounter = 0
	whileLabelCounter = 0
	staticIndex = 0
	fieldIndex = 0 
	
	currentToken = gets(currentInputFileNum)
	-- "class" token
	
	currentToken = gets(currentInputFileNum)
	currentTokenElem = split(currentToken)
	currentTokenElem = currentTokenElem[2]
	-- "identifier" token
	
	currentClassName = currentTokenElem
	
	currentToken = gets(currentInputFileNum)
	-- "{" token
	
	currentToken = gets(currentInputFileNum)
	currentTokenElem = split(currentToken)
	currentTokenElem = currentTokenElem[2]
	while equal(currentTokenElem,"static") or equal(currentTokenElem,"field") do
		classVarDec()
		currentToken = gets(currentInputFileNum)
		currentTokenElem = split(currentToken)
		currentTokenElem = currentTokenElem[2]
	end while
	
	while equal(currentTokenElem,"constructor") or equal(currentTokenElem,"function") or equal(currentTokenElem,"method") do
		subroutineDec()
		currentToken = gets(currentInputFileNum)
		currentTokenElem = split(currentToken)
		currentTokenElem = currentTokenElem[2]
	end while
	-- "}" token
end procedure

-- this function is for the declaration of variables in the class (fields or statics).
procedure classVarDec()
	-- "static" or "field" token
	sequence Kind,Type,Name
	
	Kind = currentTokenElem
	
	currentToken = gets(currentInputFileNum)
	currentTokenElem = split(currentToken)
	currentTokenElem = currentTokenElem[2]
	-- "int" or any identifier token for type of var
	
	Type = currentTokenElem
	
	currentToken = gets(currentInputFileNum)
	currentTokenElem = split(currentToken)
	currentTokenElem = currentTokenElem[2]
	-- "identifier" token
	
	Name = currentTokenElem
	
	-- adding variable to the class symbol table
	if equal(Kind, "field") then
		put(classScopeST, Name, {Type, Kind, fieldIndex})
		fieldIndex += 1
	else
		put(classScopeST, Name, {Type, Kind, staticIndex})
		staticIndex += 1
	end if
	
	currentToken = gets(currentInputFileNum)
	currentTokenElem = split(currentToken)
	currentTokenElem = currentTokenElem[2]
	while equal(currentTokenElem,",") do
		currentToken = gets(currentInputFileNum)
		currentTokenElem = split(currentToken)
		currentTokenElem = currentTokenElem[2]
		
		Name = currentTokenElem
		-- adding more variables to the class symbol table
		if equal(Kind, "field") then
			put(classScopeST, Name, {Type, Kind, fieldIndex})
			fieldIndex += 1
		else
			put(classScopeST, Name, {Type, Kind, staticIndex})
			staticIndex += 1
		end if
		
		currentToken = gets(currentInputFileNum)
		currentTokenElem = split(currentToken)
		currentTokenElem = currentTokenElem[2]
	end while
	-- ";" token
end procedure

-- this function is for the declaration of a subroutine (constructor, function or method).
procedure subroutineDec()
	subroutineScopeST = m:new()
	
	argIndex = 0
	varIndex = 0
	
	sequence subrout = currentTokenElem
	
	currentToken = gets(currentInputFileNum)
	currentTokenElem = split(currentToken)
	currentTokenElem = currentTokenElem[2]
	
	currentToken = gets(currentInputFileNum)
	currentTokenElem = split(currentToken)
	currentTokenElem = currentTokenElem[2]
	
	sequence subroutName = currentTokenElem
	
	currentToken = gets(currentInputFileNum)
	
	if equal(subrout,"method") then
		put(subroutineScopeST, "this", {currentClassName, "argument", argIndex})
		argIndex+=1
	end if
	
	currentToken = gets(currentInputFileNum)
	currentTokenElem = split(currentToken)
	currentTokenElem = currentTokenElem[2]
	parameterList()
	
	currentToken = gets(currentInputFileNum)
	subroutineBody(subrout,subroutName)
end procedure

-- this function handles the list of parameters when declaring a subroutine.
procedure parameterList()
	sequence Kind,Type,Name
	
	if not equal(currentTokenElem, ")") then
		Kind = "argument"
		
		Type = currentTokenElem
		
		currentToken = gets(currentInputFileNum)
		currentTokenElem = split(currentToken)
		currentTokenElem = currentTokenElem[2]
		
		Name = currentTokenElem
		
		put(subroutineScopeST, Name, {Type, Kind, argIndex})
		argIndex += 1
		
		currentToken = gets(currentInputFileNum)
		currentTokenElem = split(currentToken)
		currentTokenElem = currentTokenElem[2]
		while equal(currentTokenElem, ",") do
			currentToken = gets(currentInputFileNum)
			currentTokenElem = split(currentToken)
			currentTokenElem = currentTokenElem[2]
			
			Type = currentTokenElem
		
			currentToken = gets(currentInputFileNum)
			currentTokenElem = split(currentToken)
			currentTokenElem = currentTokenElem[2]
			
			Name = currentTokenElem
			
			put(subroutineScopeST, Name, {Type, Kind, argIndex})
			argIndex += 1
		
			currentToken = gets(currentInputFileNum)
			currentTokenElem = split(currentToken)
			currentTokenElem = currentTokenElem[2]
		end while
	end if
end procedure

-- this function handles all of var declarations and statements that might appear in the body of the subroutine.
procedure subroutineBody(sequence subrout, sequence subroutName)
	currentToken = gets(currentInputFileNum)
	currentTokenElem = split(currentToken)
	currentTokenElem = currentTokenElem[2]
	while equal(currentTokenElem, "var") do
		varDec()
		currentToken = gets(currentInputFileNum)
		currentTokenElem = split(currentToken)
		currentTokenElem = currentTokenElem[2]
	end while
	
	-- every type of subroutine has a different way to start
	switch subrout do
		case "constructor" then
			printf(currentresultFileNum, "function %s.%s %d\n", {currentClassName, subroutName, varIndex})
			printf(currentresultFileNum, "push constant %d\n", {fieldIndex})
			printf(currentresultFileNum, "call Memory.alloc 1\n")
			printf(currentresultFileNum, "pop pointer 0\n")
		case "method" then
			printf(currentresultFileNum, "function %s.%s %d\n", {currentClassName, subroutName, varIndex})
			printf(currentresultFileNum, "push argument 0\n")
			printf(currentresultFileNum, "pop pointer 0\n")
		case "function" then
			printf(currentresultFileNum, "function %s.%s %d\n", {currentClassName, subroutName, varIndex})
	end switch
	
	statements()
end procedure

-- this function handles the declaration of variables in the start of a subroutine body.
procedure varDec()
	sequence Kind,Type,Name
	
	Kind = "var"
	
	currentToken = gets(currentInputFileNum)
	currentTokenElem = split(currentToken)
	currentTokenElem = currentTokenElem[2]
	
	Type = currentTokenElem
	
	currentToken = gets(currentInputFileNum)
	currentTokenElem = split(currentToken)
	currentTokenElem = currentTokenElem[2]
	
	Name = currentTokenElem
	
	put(subroutineScopeST, Name, {Type, Kind, varIndex})
	varIndex += 1
	
	currentToken = gets(currentInputFileNum)
	currentTokenElem = split(currentToken)
	currentTokenElem = currentTokenElem[2]
	while equal(currentTokenElem, ",") do
		currentToken = gets(currentInputFileNum)
		currentTokenElem = split(currentToken)
		currentTokenElem = currentTokenElem[2]
		
		Name = currentTokenElem
		
		put(subroutineScopeST, Name, {Type, Kind, varIndex})
		varIndex += 1
		
		currentToken = gets(currentInputFileNum)
		currentTokenElem = split(currentToken)
		currentTokenElem = currentTokenElem[2]
	end while
end procedure

-- this function handles the list of statement that might appear somewhere in a scope (in a subroutine, body of if or else statments).
procedure statements()
	while equal(currentTokenElem, "let") or equal(currentTokenElem, "if") or equal(currentTokenElem, "while") or equal(currentTokenElem, "do") or equal(currentTokenElem, "return") do
		statement()
	end while
end procedure

-- this function handles one specific statement (let, if, while, do or return).
procedure statement()
	if equal(currentTokenElem, "let") then
		letStatement()
	elsif equal(currentTokenElem, "if") then
		ifStatement()
	elsif equal(currentTokenElem, "while") then
		whileStatement()
	elsif equal(currentTokenElem, "do") then
		doStatement()
	else 
		returnStatement()
	end if
end procedure

-- this function handles a "let" type statement.
procedure letStatement()
	-- to check if we need to assign to a regular var or an array
	integer arrayAssignment = 0
	
	currentToken = gets(currentInputFileNum)
	currentTokenElem = split(currentToken)
	currentTokenElem = currentTokenElem[2]
	
	sequence varName = currentTokenElem
	-- using the map to retrieve the information about the given var name (type, kind, #)
	sequence details
	if has(subroutineScopeST, varName) then
		details = get(subroutineScopeST, varName) 
	else
		details = get(classScopeST, varName) 
	end if
	
	currentToken = gets(currentInputFileNum)
	currentTokenElem = split(currentToken)
	currentTokenElem = currentTokenElem[2]
	-- in case of assigning a value to an array at some index:
	if equal(currentTokenElem, "[") then
		arrayAssignment = 1
		
		currentToken = gets(currentInputFileNum)
		currentTokenElem = split(currentToken)
		currentTokenElem = currentTokenElem[2]
		expression()
		
		if equal(details[2], "var") then
			printf(currentresultFileNum, "push local %d\n", {details[3]})
		elsif equal(details[2], "argument") then
			printf(currentresultFileNum, "push argument %d\n", {details[3]})
		elsif equal(details[2], "field") then
			printf(currentresultFileNum, "push this %d\n", {details[3]})
		else
			printf(currentresultFileNum, "push static %d\n", {details[3]})
		end if
		
		printf(currentresultFileNum, "add\n")
		
		currentToken = gets(currentInputFileNum)
		currentTokenElem = split(currentToken)
		currentTokenElem = currentTokenElem[2]
	end if
	
	currentToken = gets(currentInputFileNum)
	currentTokenElem = split(currentToken)
	currentTokenElem = currentTokenElem[2]
	expression()
	
	-- checking where the var is declared using the symbol table and popping the result from the expression to it
	if arrayAssignment = 1 then
		printf(currentresultFileNum, "pop temp 0\npop pointer 1\npush temp 0\npop that 0\n")
	else
		if equal(details[2], "var") then
			printf(currentresultFileNum, "pop local %d\n", {details[3]})
		elsif equal(details[2], "argument") then
			printf(currentresultFileNum, "pop argument %d\n", {details[3]})
		elsif equal(details[2], "field") then
			printf(currentresultFileNum, "pop this %d\n", {details[3]})
		else
			printf(currentresultFileNum, "pop static %d\n", {details[3]})
		end if
	end if
	
	currentToken = gets(currentInputFileNum)
	currentTokenElem = split(currentToken)
	currentTokenElem = currentTokenElem[2]
end procedure

-- this function handles a "if" type statement.
procedure ifStatement()
	integer labelNum = ifLabelCounter
	ifLabelCounter += 1
	
	currentToken = gets(currentInputFileNum)
	
	currentToken = gets(currentInputFileNum)
	currentTokenElem = split(currentToken)
	currentTokenElem = currentTokenElem[2]
	expression()
	
	printf(currentresultFileNum, "not\n")
	
	printf(currentresultFileNum, "if-goto condNotMet%d\n",{labelNum})
	
	currentToken = gets(currentInputFileNum)
	
	currentToken = gets(currentInputFileNum)
	currentTokenElem = split(currentToken)
	currentTokenElem = currentTokenElem[2]
	statements()
	
	printf(currentresultFileNum, "goto endif%d\n",{labelNum})
	
	printf(currentresultFileNum, "label condNotMet%d\n",{labelNum})
	
	currentToken = gets(currentInputFileNum)
	currentTokenElem = split(currentToken)
	currentTokenElem = currentTokenElem[2]
	if equal(currentTokenElem, "else") then
		currentToken = gets(currentInputFileNum)
	
		currentToken = gets(currentInputFileNum)
		currentTokenElem = split(currentToken)
		currentTokenElem = currentTokenElem[2]
		statements()
		
		currentToken = gets(currentInputFileNum)
		currentTokenElem = split(currentToken)
		currentTokenElem = currentTokenElem[2]
	end if
	
	printf(currentresultFileNum, "label endif%d\n",{labelNum})
end procedure

-- this function handles a "while" type statement.
procedure whileStatement()
	integer labelNum = whileLabelCounter
	whileLabelCounter += 1
	
	printf(currentresultFileNum, "label start%d\n",{labelNum})
	
	currentToken = gets(currentInputFileNum)
	
	currentToken = gets(currentInputFileNum)
	currentTokenElem = split(currentToken)
	currentTokenElem = currentTokenElem[2]
	expression()
	
	printf(currentresultFileNum, "not\n")
	
	printf(currentresultFileNum, "if-goto end%d\n",{labelNum})
	
	currentToken = gets(currentInputFileNum)
	
	currentToken = gets(currentInputFileNum)
	currentTokenElem = split(currentToken)
	currentTokenElem = currentTokenElem[2]
	statements()
	
	printf(currentresultFileNum, "goto start%d\n",{labelNum})
	
	printf(currentresultFileNum, "label end%d\n",{labelNum})
	
	currentToken = gets(currentInputFileNum)
	currentTokenElem = split(currentToken)
	currentTokenElem = currentTokenElem[2]
end procedure

-- this function handles a "do" type statement.
procedure doStatement()
	currentToken = gets(currentInputFileNum)
	currentTokenElem = split(currentToken)
	currentTokenElem = currentTokenElem[2]
	
	sequence Name = currentTokenElem
	
	currentToken = gets(currentInputFileNum)
	currentTokenElem = split(currentToken)
	currentTokenElem = currentTokenElem[2]
	subroutineCall(Name)
	
	printf(currentresultFileNum, "pop temp 0\n")
	
	currentToken = gets(currentInputFileNum)
	currentTokenElem = split(currentToken)
	currentTokenElem = currentTokenElem[2]
	
	currentToken = gets(currentInputFileNum)
	currentTokenElem = split(currentToken)
	currentTokenElem = currentTokenElem[2]
end procedure

-- this function handles a "return" type statement.
procedure returnStatement()
	currentToken = gets(currentInputFileNum)
	currentTokenElem = split(currentToken)
	currentTokenElem = currentTokenElem[2]
	if not equal(currentTokenElem, ";") then
		expression()
	else
		printf(currentresultFileNum, "push constant 0\n")
	end if
	
	printf(currentresultFileNum, "return\n")
	
	currentToken = gets(currentInputFileNum)
	currentTokenElem = split(currentToken)
	currentTokenElem = currentTokenElem[2]
end procedure

-- this function handles the use of expressions in statement (for example the expression "a + 4 - x[3] * y.add(5)").
procedure expression()
	currentTokenElem = split(currentToken)
	term()
	
	while match(currentTokenElem, "+-*/|=") or equal(currentTokenElem, "&lt;") or equal(currentTokenElem, "&gt;") or equal(currentTokenElem, "&amp;") do
		sequence op = currentTokenElem
		
		currentToken = gets(currentInputFileNum)
		currentTokenElem = split(currentToken)
		term()
		switch op do
			case "+" then
				printf(currentresultFileNum, "add\n")
			case "-" then
				printf(currentresultFileNum, "sub\n")
			case "*" then
				printf(currentresultFileNum, "call Math.multiply 2\n")
			case "/" then
				printf(currentresultFileNum, "call Math.divide 2\n")
			case "|" then
				printf(currentresultFileNum, "or\n")
			case "=" then
				printf(currentresultFileNum, "eq\n")
			case "&lt;" then
				printf(currentresultFileNum, "lt\n")
			case "&gt;" then
				printf(currentresultFileNum, "gt\n")
			case "&amp;" then
				printf(currentresultFileNum, "and\n")
		end switch
	end while
end procedure

-- this function handles a specific term that might appear in an expression (example: "moneyAmount" or "23").
procedure term()
	if equal(currentTokenElem[1],"<integerConstant>") then
		printf(currentresultFileNum, "push constant %s\n", {currentTokenElem[2]})
		
		currentToken = gets(currentInputFileNum)
		currentTokenElem = split(currentToken)
		currentTokenElem = currentTokenElem[2]
	elsif equal(currentTokenElem[1],"<stringConstant>") then
		sequence stringConst = join(currentTokenElem[2..$-1])
		integer stringLength = length(stringConst)
		atom character
		
		printf(currentresultFileNum, "push constant %d\n", {stringLength})
		printf(currentresultFileNum, "call String.new 1\n")
		
		for i = 1 to stringLength do
			character = stringConst[i]
			printf(currentresultFileNum, "push constant %d\n", {character})
			printf(currentresultFileNum, "call String.appendChar 2\n")
		end for
		
		currentToken = gets(currentInputFileNum)
		currentTokenElem = split(currentToken)
		currentTokenElem = currentTokenElem[2]
	elsif match({currentTokenElem[2]}, keywords) then
		currentTokenElem = currentTokenElem[2]
		
		if equal(currentTokenElem, "false") or equal(currentTokenElem, "null") then
			printf(currentresultFileNum, "push constant 0\n")
		elsif equal(currentTokenElem, "true") then
			printf(currentresultFileNum, "push constant 0\n")
			printf(currentresultFileNum, "not\n")
		elsif equal(currentTokenElem, "this") then
			printf(currentresultFileNum, "push pointer 0\n")
		end if
		
		currentToken = gets(currentInputFileNum)
		currentTokenElem = split(currentToken)
		currentTokenElem = currentTokenElem[2]
	elsif equal(currentTokenElem[2],"(") then
		
		currentToken = gets(currentInputFileNum)
		currentTokenElem = split(currentToken)
		currentTokenElem = currentTokenElem[2]
		expression()
		
		currentToken = gets(currentInputFileNum)
		currentTokenElem = split(currentToken)
		currentTokenElem = currentTokenElem[2]
	elsif equal(currentTokenElem[2],"-") or equal(currentTokenElem[2],"~") then
		currentTokenElem = currentTokenElem[2]
		sequence op = currentTokenElem
		
		currentToken = gets(currentInputFileNum)
		currentTokenElem = split(currentToken)
		term()
		if equal(op,"-") then
			printf(currentresultFileNum, "neg\n")
		else
			printf(currentresultFileNum, "not\n")
		end if
	else
		currentTokenElem = split(currentToken)
		currentTokenElem = currentTokenElem[2]
		idTerm()
	end if
end procedure

-- this function is not an original part of the given grammar, we made it for helping us resolve the fact that the grammar is not entirely LL(0),
-- so instead of using lookahead we changed the grammar a bit to make it LL(0).
procedure idTerm()
	sequence Name = currentTokenElem
	sequence details
	
	currentToken = gets(currentInputFileNum)
	currentTokenElem = split(currentToken)
	currentTokenElem = currentTokenElem[2]
	
	if equal(currentTokenElem,"[") then
		-- get the expression to know the offset for the array address and put in the stack
		currentToken = gets(currentInputFileNum)
		currentTokenElem = split(currentToken)
		currentTokenElem = currentTokenElem[2]
		expression()
		
		-- get the address of the start of the array and put in the stack
		if has(subroutineScopeST, Name) then
			-- if the variable name is in the subroutine scope
			details = get(subroutineScopeST, Name)
			if equal(details[2],"var") then
				printf(currentresultFileNum, "push local %d\n", {details[3]})
			else
				printf(currentresultFileNum, "push argument %d\n", {details[3]})
			end if
		else
			-- else if the variable name is in the class scope
			details = get(classScopeST, Name)
			if	equal(details[2], "field") then
				printf(currentresultFileNum, "push this %d\n", {details[3]})
			else
				printf(currentresultFileNum, "push static %d\n", {details[3]})
			end if
		end if	
		
		-- put the value of the array at specified index in the stack using that pointer
		printf(currentresultFileNum, "add\n")
		printf(currentresultFileNum, "pop pointer 1\n")
		printf(currentresultFileNum, "push that 0\n")
		
		currentToken = gets(currentInputFileNum)
		currentTokenElem = split(currentToken)
		currentTokenElem = currentTokenElem[2]
	elsif equal(currentTokenElem,"(") or equal(currentTokenElem,".") then
		subroutineCall(Name)
		
		currentToken = gets(currentInputFileNum)
		currentTokenElem = split(currentToken)
		currentTokenElem = currentTokenElem[2]
	else -- just a var name, and not an array or a subroutine call
		-- get the value of the variable and put it in the stack
		if has(subroutineScopeST, Name) then
			-- if the variable name is in the subroutine scope
			details = get(subroutineScopeST, Name)
			if equal(details[2],"var") then
				printf(currentresultFileNum, "push local %d\n", {details[3]})
			else
				printf(currentresultFileNum, "push argument %d\n", {details[3]})
			end if
		else
			-- else if the variable name is in the class scope
			details = get(classScopeST, Name)
			if	equal(details[2], "field") then
				printf(currentresultFileNum, "push this %d\n", {details[3]})
			else
				printf(currentresultFileNum, "push static %d\n", {details[3]})
			end if
		end if
	end if
	
end procedure

-- this function handles a subroutine call, we changed this function a bit too to make the grammar LL(0).
procedure subroutineCall(sequence Name)
	integer numOfArgs = 0
	if equal(currentTokenElem,"(") then -- in case of '(' the Name given is the function name
		printf(currentresultFileNum, "push pointer 0\n")
		numOfArgs += 1
		
		currentToken = gets(currentInputFileNum)
		currentTokenElem = split(currentToken)
		currentTokenElem = currentTokenElem[2]
		numOfArgs += expressionList()
		
		printf(currentresultFileNum, "call %s.%s %d\n", {currentClassName, Name, numOfArgs})
	else -- in case of '.' the Name given is a variable or class name
		sequence subroutineName
		sequence details
		
		currentToken = gets(currentInputFileNum)
		currentTokenElem = split(currentToken)
		currentTokenElem = currentTokenElem[2]
		
		subroutineName = currentTokenElem
		
		if has(subroutineScopeST,Name) then -- if the name before the '.' is a variable declared in the current subroutine (argument or var)
			details = get(subroutineScopeST,Name)
			if equal(details[2],"var") then
				printf(currentresultFileNum, "push local %d\n", {details[3]})
			else
				printf(currentresultFileNum, "push argument %d\n", {details[3]})
			end if
            numOfArgs += 1
		elsif has(classScopeST, Name) then -- if the name before the '.' is a variable declared in the current class (field or static)
			details = get(classScopeST, Name)
			if	equal(details[2], "field") then
				printf(currentresultFileNum, "push this %d\n", {details[3]})
			else
				printf(currentresultFileNum, "push static %d\n", {details[3]})
			end if
			numOfArgs+=1
        else -- if the name before the '.' is a class name and we call a function (static subroutine) or a constructor
			details = {Name}
        end if
		
		currentToken = gets(currentInputFileNum)
		currentTokenElem = split(currentToken)
		currentTokenElem = currentTokenElem[2]
		
		currentToken = gets(currentInputFileNum)
		currentTokenElem = split(currentToken)
		currentTokenElem = currentTokenElem[2]
		numOfArgs += expressionList()
		
		printf(currentresultFileNum, "call %s.%s %d\n", {details[1], subroutineName, numOfArgs})
	end if
end procedure

-- this function handles the list of parameters given to a subroutine when calling a subroutine.
function expressionList()
	integer numOfExpressions = 0
	
	if not equal(currentTokenElem,")") then
		expression()
		numOfExpressions += 1
		while equal(currentTokenElem,",") do
			currentToken = gets(currentInputFileNum)
			currentTokenElem = split(currentToken)
			currentTokenElem = currentTokenElem[2]
			expression()
			numOfExpressions += 1
		end while
	end if
	
	return numOfExpressions
end function

