

include std/io.e
include std/filesys.e
include std/convert.e
include std/sequence.e


sequence symbols = "{}[]().,;+-*/&|<>=~"
sequence keywords = {"class","constructor","function","method","field","static","var","int","char","boolean","void","true","false","null","this","let","do","if","else","while","return"}

puts(SCREEN, "please enter the path to the input jack files directory:\n")
-- get the path to the input files directory.
sequence path = gets(0)
-- get the path without the \n at the end.
path = path[1..$-1]

puts(SCREEN, "\nplease enter the path to the output xml files directory:\n")
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
		
		currentresultFileNum = open(pathDest & '\\' & jackFilesNames[i][1..$-5] & ".xml", "w")

		if currentresultFileNum = -1 then
			puts(1, "Can't open result file\n")
			abort(1)
		end if
		
		-- start of parsing --
		currentToken = gets(currentInputFileNum)
		
		-- the root of the grammar is the class string.
		class()
		
		
		-- end of parsing --
		
		close(currentInputFileNum)
		close(currentresultFileNum)
		
	end for
end procedure

-- the root string, contains only one production rule.
procedure class()
	printf(currentresultFileNum, "<class>\n")
	
	currentToken = gets(currentInputFileNum)
	printf(currentresultFileNum, "<keyword> class </keyword>\n")
	
	currentToken = gets(currentInputFileNum)
	currentTokenElem = split(currentToken)
	currentTokenElem = currentTokenElem[2]
	identifier()
	
	currentToken = gets(currentInputFileNum)
	printf(currentresultFileNum, "<symbol> { </symbol>\n")
	
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
	
	printf(currentresultFileNum, "<symbol> } </symbol>\n")
	
	printf(currentresultFileNum, "</class>\n")
end procedure

-- this function is for the declaration of variables in the class (fields or statics).
procedure classVarDec()
	printf(currentresultFileNum, "<classVarDec>\n")
	
	if equal(currentTokenElem,"static") then
		printf(currentresultFileNum, "<keyword> static </keyword>\n")
	else
		printf(currentresultFileNum, "<keyword> field </keyword>\n")
	end if
	
	currentToken = gets(currentInputFileNum)
	currentTokenElem = split(currentToken)
	currentTokenElem = currentTokenElem[2]
	Type()
	
	currentToken = gets(currentInputFileNum)
	currentTokenElem = split(currentToken)
	currentTokenElem = currentTokenElem[2]
	identifier()
	
	currentToken = gets(currentInputFileNum)
	currentTokenElem = split(currentToken)
	currentTokenElem = currentTokenElem[2]
	while equal(currentTokenElem,",") do
		printf(currentresultFileNum, "<symbol> , </symbol>\n")
		currentToken = gets(currentInputFileNum)
		currentTokenElem = split(currentToken)
		currentTokenElem = currentTokenElem[2]
		identifier()
		currentToken = gets(currentInputFileNum)
		currentTokenElem = split(currentToken)
		currentTokenElem = currentTokenElem[2]
	end while
	
	printf(currentresultFileNum, "<symbol> ; </symbol>\n")
	
	printf(currentresultFileNum, "</classVarDec>\n")
end procedure

-- this function wraps the current token with the word type to specifiy that it refers to a type of a variable or function.
procedure Type()
	if equal(currentTokenElem,"int") then
		printf(currentresultFileNum, "<keyword> int </keyword>\n")
	elsif equal(currentTokenElem,"char") then
		printf(currentresultFileNum, "<keyword> char </keyword>\n")
	elsif equal(currentTokenElem,"boolean") then
		printf(currentresultFileNum, "<keyword> boolean </keyword>\n")
	else
		printf(currentresultFileNum, "<identifier> %s </identifier>\n", {currentTokenElem})
	end if
end procedure

-- this function is for the declaration of a subroutine (constructor, function or method).
procedure subroutineDec()
	printf(currentresultFileNum, "<subroutineDec>\n")
	
	if equal(currentTokenElem,"constructor") then
		printf(currentresultFileNum, "<keyword> constructor </keyword>\n")
	elsif equal(currentTokenElem,"function") then
		printf(currentresultFileNum, "<keyword> function </keyword>\n")
	else
		printf(currentresultFileNum, "<keyword> method </keyword>\n")
	end if
	
	currentToken = gets(currentInputFileNum)
	currentTokenElem = split(currentToken)
	currentTokenElem = currentTokenElem[2]
	if equal(currentTokenElem,"void") then
		printf(currentresultFileNum, "<keyword> void </keyword>\n")
	else
		Type()
	end if
	
	currentToken = gets(currentInputFileNum)
	currentTokenElem = split(currentToken)
	currentTokenElem = currentTokenElem[2]
	identifier()
	
	currentToken = gets(currentInputFileNum)
	printf(currentresultFileNum, "<symbol> ( </symbol>\n")
	
	currentToken = gets(currentInputFileNum)
	currentTokenElem = split(currentToken)
	currentTokenElem = currentTokenElem[2]
	parameterList()
	
	printf(currentresultFileNum, "<symbol> ) </symbol>\n")
	
	currentToken = gets(currentInputFileNum)
	subroutineBody()
	
	printf(currentresultFileNum, "</subroutineDec>\n")
end procedure

-- this function handles the list of parameters when declaring a subroutine.
procedure parameterList()
	printf(currentresultFileNum, "<parameterList>\n")
	
	if not equal(currentTokenElem, ")") then
		Type()
		
		currentToken = gets(currentInputFileNum)
		currentTokenElem = split(currentToken)
		currentTokenElem = currentTokenElem[2]
		identifier()
		
		currentToken = gets(currentInputFileNum)
		currentTokenElem = split(currentToken)
		currentTokenElem = currentTokenElem[2]
		while equal(currentTokenElem, ",") do
			printf(currentresultFileNum, "<symbol> , </symbol>\n")
			
			currentToken = gets(currentInputFileNum)
			currentTokenElem = split(currentToken)
			currentTokenElem = currentTokenElem[2]
			Type()
		
			currentToken = gets(currentInputFileNum)
			currentTokenElem = split(currentToken)
			currentTokenElem = currentTokenElem[2]
			identifier()
		
			currentToken = gets(currentInputFileNum)
			currentTokenElem = split(currentToken)
			currentTokenElem = currentTokenElem[2]
		end while
	end if
	
	printf(currentresultFileNum, "</parameterList>\n")
end procedure

-- this function handles all of var declarations and statements that might appear in the body of the subroutine.
procedure subroutineBody()
	printf(currentresultFileNum, "<subroutineBody>\n")
	
	printf(currentresultFileNum, "<symbol> { </symbol>\n")
	
	currentToken = gets(currentInputFileNum)
	currentTokenElem = split(currentToken)
	currentTokenElem = currentTokenElem[2]
	while equal(currentTokenElem, "var") do
		varDec()
		currentToken = gets(currentInputFileNum)
		currentTokenElem = split(currentToken)
		currentTokenElem = currentTokenElem[2]
	end while
	
	statements()
	
	printf(currentresultFileNum, "<symbol> } </symbol>\n")
	
	printf(currentresultFileNum, "</subroutineBody>\n")
end procedure

-- this function handles the declaration of variables in the start of a subroutine body.
procedure varDec()
	printf(currentresultFileNum, "<varDec>\n")
	
	printf(currentresultFileNum, "<keyword> var </keyword>\n")
	
	currentToken = gets(currentInputFileNum)
	currentTokenElem = split(currentToken)
	currentTokenElem = currentTokenElem[2]
	Type()
	
	currentToken = gets(currentInputFileNum)
	currentTokenElem = split(currentToken)
	currentTokenElem = currentTokenElem[2]
	identifier()
	
	currentToken = gets(currentInputFileNum)
	currentTokenElem = split(currentToken)
	currentTokenElem = currentTokenElem[2]
	while equal(currentTokenElem, ",") do
		printf(currentresultFileNum, "<symbol> , </symbol>\n")
		currentToken = gets(currentInputFileNum)
		currentTokenElem = split(currentToken)
		currentTokenElem = currentTokenElem[2]
		identifier()
		currentToken = gets(currentInputFileNum)
		currentTokenElem = split(currentToken)
		currentTokenElem = currentTokenElem[2]
	end while
	
	printf(currentresultFileNum, "<symbol> ; </symbol>\n")
	
	printf(currentresultFileNum, "</varDec>\n")
end procedure

-- this function is used for multiple causes. it handles any kind of identifier token in its context (subroutine, var or class name).
procedure identifier()
	printf(currentresultFileNum, "<identifier> %s </identifier>\n", {currentTokenElem})
end procedure

-- this function handles the list of statement that might appear somewhere in a scope (in a subroutine, body of if or else statments).
procedure statements()
	printf(currentresultFileNum, "<statements>\n")
	
	while equal(currentTokenElem, "let") or equal(currentTokenElem, "if") or equal(currentTokenElem, "while") or equal(currentTokenElem, "do") or equal(currentTokenElem, "return") do
		statement()
	end while
	
	printf(currentresultFileNum, "</statements>\n")
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
	printf(currentresultFileNum, "<letStatement>\n")
	
	printf(currentresultFileNum, "<keyword> let </keyword>\n")
	
	currentToken = gets(currentInputFileNum)
	currentTokenElem = split(currentToken)
	currentTokenElem = currentTokenElem[2]
	identifier()
	
	currentToken = gets(currentInputFileNum)
	currentTokenElem = split(currentToken)
	currentTokenElem = currentTokenElem[2]
	if equal(currentTokenElem, "[") then
		printf(currentresultFileNum, "<symbol> [ </symbol>\n")
		
		currentToken = gets(currentInputFileNum)
		currentTokenElem = split(currentToken)
		currentTokenElem = currentTokenElem[2]
		expression()
		
		printf(currentresultFileNum, "<symbol> ] </symbol>\n")
		
		currentToken = gets(currentInputFileNum)
		currentTokenElem = split(currentToken)
		currentTokenElem = currentTokenElem[2]
	end if
	
	printf(currentresultFileNum, "<symbol> = </symbol>\n")
	
	currentToken = gets(currentInputFileNum)
	currentTokenElem = split(currentToken)
	currentTokenElem = currentTokenElem[2]
	expression()
	
	printf(currentresultFileNum, "<symbol> ; </symbol>\n")
	
	currentToken = gets(currentInputFileNum)
	currentTokenElem = split(currentToken)
	currentTokenElem = currentTokenElem[2]
	
	printf(currentresultFileNum, "</letStatement>\n")
end procedure

-- this function handles a "if" type statement.
procedure ifStatement()
	printf(currentresultFileNum, "<ifStatement>\n")
	
	printf(currentresultFileNum, "<keyword> if </keyword>\n")
	
	currentToken = gets(currentInputFileNum)
	printf(currentresultFileNum, "<symbol> ( </symbol>\n")
	
	currentToken = gets(currentInputFileNum)
	currentTokenElem = split(currentToken)
	currentTokenElem = currentTokenElem[2]
	expression()
	
	printf(currentresultFileNum, "<symbol> ) </symbol>\n")
	
	currentToken = gets(currentInputFileNum)
	printf(currentresultFileNum, "<symbol> { </symbol>\n")
	
	currentToken = gets(currentInputFileNum)
	currentTokenElem = split(currentToken)
	currentTokenElem = currentTokenElem[2]
	statements()
	
	printf(currentresultFileNum, "<symbol> } </symbol>\n")
	
	currentToken = gets(currentInputFileNum)
	currentTokenElem = split(currentToken)
	currentTokenElem = currentTokenElem[2]
	if equal(currentTokenElem, "else") then
		printf(currentresultFileNum, "<keyword> else </keyword>\n")
		
		currentToken = gets(currentInputFileNum)
		printf(currentresultFileNum, "<symbol> { </symbol>\n")
	
		currentToken = gets(currentInputFileNum)
		currentTokenElem = split(currentToken)
		currentTokenElem = currentTokenElem[2]
		statements()
	
		printf(currentresultFileNum, "<symbol> } </symbol>\n")
		
		currentToken = gets(currentInputFileNum)
		currentTokenElem = split(currentToken)
		currentTokenElem = currentTokenElem[2]
	end if
	
	printf(currentresultFileNum, "</ifStatement>\n")
end procedure

-- this function handles a "while" type statement.
procedure whileStatement()
	printf(currentresultFileNum, "<whileStatement>\n")
	
	printf(currentresultFileNum, "<keyword> while </keyword>\n")
	
	currentToken = gets(currentInputFileNum)
	printf(currentresultFileNum, "<symbol> ( </symbol>\n")
	
	currentToken = gets(currentInputFileNum)
	currentTokenElem = split(currentToken)
	currentTokenElem = currentTokenElem[2]
	expression()
	
	printf(currentresultFileNum, "<symbol> ) </symbol>\n")
	
	currentToken = gets(currentInputFileNum)
	printf(currentresultFileNum, "<symbol> { </symbol>\n")
	
	currentToken = gets(currentInputFileNum)
	currentTokenElem = split(currentToken)
	currentTokenElem = currentTokenElem[2]
	statements()
	
	printf(currentresultFileNum, "<symbol> } </symbol>\n")
	
	currentToken = gets(currentInputFileNum)
	currentTokenElem = split(currentToken)
	currentTokenElem = currentTokenElem[2]
	
	printf(currentresultFileNum, "</whileStatement>\n")
end procedure

-- this function handles a "do" type statement.
procedure doStatement()
	printf(currentresultFileNum, "<doStatement>\n")
	
	printf(currentresultFileNum, "<keyword> do </keyword>\n")
	
	currentToken = gets(currentInputFileNum)
	currentTokenElem = split(currentToken)
	currentTokenElem = currentTokenElem[2]
	identifier()
	
	currentToken = gets(currentInputFileNum)
	currentTokenElem = split(currentToken)
	currentTokenElem = currentTokenElem[2]
	subroutineCall()
	
	currentToken = gets(currentInputFileNum)
	currentTokenElem = split(currentToken)
	currentTokenElem = currentTokenElem[2]
	printf(currentresultFileNum, "<symbol> ; </symbol>\n")
	
	currentToken = gets(currentInputFileNum)
	currentTokenElem = split(currentToken)
	currentTokenElem = currentTokenElem[2]
	
	printf(currentresultFileNum, "</doStatement>\n")
end procedure

-- this function handles a "return" type statement.
procedure returnStatement()
	printf(currentresultFileNum, "<returnStatement>\n")
	
	printf(currentresultFileNum, "<keyword> return </keyword>\n")
	
	currentToken = gets(currentInputFileNum)
	currentTokenElem = split(currentToken)
	currentTokenElem = currentTokenElem[2]
	if not equal(currentTokenElem, ";") then
		expression()
	end if
	
	printf(currentresultFileNum, "<symbol> ; </symbol>\n")
	
	currentToken = gets(currentInputFileNum)
	currentTokenElem = split(currentToken)
	currentTokenElem = currentTokenElem[2]
	
	printf(currentresultFileNum, "</returnStatement>\n")
end procedure

-- this function handles the use of expressions in statement (for example the expression "a + 4 - x[3] * y.add(5)").
procedure expression()
	printf(currentresultFileNum, "<expression>\n")
	
	currentTokenElem = split(currentToken)
	term()
	
	while match(currentTokenElem, "+-*/|=") or equal(currentTokenElem, "&lt;") or equal(currentTokenElem, "&gt;") or equal(currentTokenElem, "&amp;") do
		op()
		
		currentToken = gets(currentInputFileNum)
		currentTokenElem = split(currentToken)
		term()
	end while
	
	printf(currentresultFileNum, "</expression>\n")
end procedure

-- this function handles a specific term that might appear in an expression (example: "moneyAmount" or "23").
procedure term()
	printf(currentresultFileNum, "<term>\n")
	
	if equal(currentTokenElem[1],"<integerConstant>") then
		printf(currentresultFileNum, "<integerConstant> %s </integerConstant>\n", {currentTokenElem[2]})
		
		currentToken = gets(currentInputFileNum)
		currentTokenElem = split(currentToken)
		currentTokenElem = currentTokenElem[2]
	elsif equal(currentTokenElem[1],"<stringConstant>") then
		printf(currentresultFileNum, "<stringConstant> %s </stringConstant>\n", {join(currentTokenElem[2..$-1])})
		
		currentToken = gets(currentInputFileNum)
		currentTokenElem = split(currentToken)
		currentTokenElem = currentTokenElem[2]
	elsif match({currentTokenElem[2]}, keywords) then
		currentTokenElem = currentTokenElem[2]
		keywordConstant()
		
		currentToken = gets(currentInputFileNum)
		currentTokenElem = split(currentToken)
		currentTokenElem = currentTokenElem[2]
	elsif equal(currentTokenElem[2],"(") then
		printf(currentresultFileNum, "<symbol> ( </symbol>\n")
		
		currentToken = gets(currentInputFileNum)
		currentTokenElem = split(currentToken)
		currentTokenElem = currentTokenElem[2]
		expression()
		
		printf(currentresultFileNum, "<symbol> ) </symbol>\n")
		
		currentToken = gets(currentInputFileNum)
		currentTokenElem = split(currentToken)
		currentTokenElem = currentTokenElem[2]
	elsif equal(currentTokenElem[2],"-") or equal(currentTokenElem[2],"~") then
		currentTokenElem = split(currentToken)
		currentTokenElem = currentTokenElem[2]
		unaryOp()
		
		currentToken = gets(currentInputFileNum)
		currentTokenElem = split(currentToken)
		term()
	else
		currentTokenElem = split(currentToken)
		currentTokenElem = currentTokenElem[2]
		idTerm()
	end if
	
	printf(currentresultFileNum, "</term>\n")
end procedure

-- this function is not an original part of the given grammar, we made it for helping us resolve the fact that the grammar is not entirely LL(0),
-- so instead of using lookahead we changed the grammar a bit to make it LL(0).
procedure idTerm()
	identifier()
	currentToken = gets(currentInputFileNum)
	currentTokenElem = split(currentToken)
	currentTokenElem = currentTokenElem[2]
	
	if equal(currentTokenElem,"[") then
		printf(currentresultFileNum, "<symbol> [ </symbol>\n")
			
		currentToken = gets(currentInputFileNum)
		currentTokenElem = split(currentToken)
		currentTokenElem = currentTokenElem[2]
		expression()
			
		printf(currentresultFileNum, "<symbol> ] </symbol>\n")
		
		currentToken = gets(currentInputFileNum)
		currentTokenElem = split(currentToken)
		currentTokenElem = currentTokenElem[2]
	elsif equal(currentTokenElem,"(") or equal(currentTokenElem,".") then
		subroutineCall()
		
		currentToken = gets(currentInputFileNum)
		currentTokenElem = split(currentToken)
		currentTokenElem = currentTokenElem[2]
	end if
	
end procedure

-- this function handles a subroutine call, we changed this function a bit too to make the grammar LL(0).
procedure subroutineCall()
	if equal(currentTokenElem,"(") then
		printf(currentresultFileNum, "<symbol> ( </symbol>\n")
		
		currentToken = gets(currentInputFileNum)
		currentTokenElem = split(currentToken)
		currentTokenElem = currentTokenElem[2]
		expressionList()
		
		printf(currentresultFileNum, "<symbol> ) </symbol>\n")
	else
		printf(currentresultFileNum, "<symbol> . </symbol>\n")
		
		currentToken = gets(currentInputFileNum)
		currentTokenElem = split(currentToken)
		currentTokenElem = currentTokenElem[2]
		identifier()
		
		currentToken = gets(currentInputFileNum)
		currentTokenElem = split(currentToken)
		currentTokenElem = currentTokenElem[2]
		printf(currentresultFileNum, "<symbol> ( </symbol>\n")
		
		currentToken = gets(currentInputFileNum)
		currentTokenElem = split(currentToken)
		currentTokenElem = currentTokenElem[2]
		expressionList()
		
		printf(currentresultFileNum, "<symbol> ) </symbol>\n")
	end if
end procedure

-- this function handles the list of parameters given to a subroutine when calling a subroutine.
procedure expressionList()
	printf(currentresultFileNum, "<expressionList>\n")
	
	if not equal(currentTokenElem,")") then
		expression()
		
		while equal(currentTokenElem,",") do
			printf(currentresultFileNum, "<symbol> , </symbol>\n")
			
			currentToken = gets(currentInputFileNum)
			currentTokenElem = split(currentToken)
			currentTokenElem = currentTokenElem[2]
			expression()
		end while
	end if
	
	printf(currentresultFileNum, "</expressionList>\n")
end procedure

-- this function handles all the operators between two terms.
procedure op()
	printf(currentresultFileNum, "<symbol> %s </symbol>\n", {currentTokenElem})
end procedure

-- this function is called when a term has got a unary opearator beside it (for example -x or ~x).
procedure unaryOp()
	printf(currentresultFileNum, "<symbol> %s </symbol>\n", {currentTokenElem})
end procedure

-- this function is called when we use the keywords this, false, true and null in expressions.
procedure keywordConstant()
	printf(currentresultFileNum, "<keyword> %s </keyword>\n", {currentTokenElem})
end procedure

