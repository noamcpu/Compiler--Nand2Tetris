

-- C:\Users\yinon\Desktop\nand2tetris\projects\08\FunctionCalls\StaticsTest
-- C:\Users\yinon\Desktop\nand2tetris\projects\08\FunctionCalls\NestedCall
-- C:\Users\yinon\Desktop\nand2tetris\projects\08\FunctionCalls\FibonacciElement
-- C:\Users\yinon\Desktop\nand2tetris\projects\08\FunctionCalls\SimpleFunction\SimpleFunction.vm
-- C:\Users\yinon\Desktop\nand2tetris\projects\08\ProgramFlow\FibonacciSeries\FibonacciSeries.vm
-- C:\Users\yinon\Desktop\nand2tetris\projects\08\ProgramFlow\BasicLoop\BasicLoop.vm


include std/filesys.e
include std/convert.e
include std/sequence.e

integer labelCounter = 1


-- get the path to the vm file or directory
sequence path = gets(0)
-- get the path without the \n at the end
path = path[1..$-1]

-- to check if we are handling a path for directory with vm files or a path to one vm file
integer inputType = file_type(path)

-- to get the current file name with a dot in the end
sequence inputFileName

-- to hold the current number of file for translation
integer currentInputFileNum

-- to hold the number of the result file
integer resultFileNum


-------------------------
-- input vm file setup --
-------------------------

sequence folderName
sequence dirInfo
sequence VMfilesNames = {}


-- if input was a path for directory set the input and output file accordingly
if inputType = 2 then
	folderName = filename(path)
	dirInfo = dir(path)
	-- get all the vm file names from the directory and put them in a sequence of strings
	for i = 1 to length(dirInfo) do  
		if length(dirInfo[i][D_NAME]) > 2 and equal(dirInfo[i][D_NAME][$-2..$],".vm") and match("a", dirInfo[i][D_ATTRIBUTES]) then
			VMfilesNames = append(VMfilesNames, dirInfo[i][D_NAME])
		end if
	end for
	
	resultFileNum = open(path & '\\' & folderName & ".asm", "w")

	if resultFileNum = -1 then
		puts(1, "Can't open result file\n")
		abort(1)
	end if
	
-- else if input was a path for vm file set the input and output file accordingly
elsif inputType = 1 then

	VMfilesNames = {filename(path)}
	
	resultFileNum = open(path[1..$-3] & ".asm", "w")

	if resultFileNum = -1 then
		puts(1, "Can't open result file\n")
		abort(1)
	end if
	
	path = pathname(path)
	
end if

--------------------------
-- start of translation --
--------------------------

-- bootstrapping in case of multiple vm files to translate
if length(VMfilesNames) > 1 then
	printf(resultFileNum , "@256\nD=A\n@SP\nM=D\n")
	asmCall("Sys.init",0)
end if

-- run over all the vm files to translate
for i=1 to length(VMfilesNames) do

	--open the current file to translate
	currentInputFileNum = open(path & '\\' & VMfilesNames[i], "r")
	if currentInputFileNum = -1 then
		puts(1, "Can't open input file\n")
		abort(1)
	end if
	
	-- get the current file name with a dot in the end
	inputFileName = VMfilesNames[i][1..$-2]
	
	object line = gets(currentInputFileNum)

	-- translate each line in vm file to hack assembly

	while sequence(line) do

		line = line[1..$-1]
		-- the split function does not like empty sequences so we check in case of an empty row in input file
		if length(line) = 0 then
			line = gets(currentInputFileNum)
			continue
		end if
		line = split_any(line," \t")

		switch line[1] do
			case "add" then
				add()
			case "sub" then
				sub()
			case "neg" then
				neg()
			case "eq" then
				eq()
			case "gt" then
				gt()
			case "lt" then
				lt()
			case "and" then
				asmAnd()
			case "or" then
				asmOr()
			case "not" then
				asmNot()
			case "push", "pop" then
				pushAndPop(line[1], line[2],to_integer(line[3]))
			case "label" then
				asmLabel(line[2])
			case "goto" then
				asmGoto(line[2])
			case "if-goto" then
				ifGoto(line[2])
			case "function" then
				asmFunction(line[2], to_integer(line[3]))
			case "call" then
				asmCall(line[2], to_integer(line[3]))
			case "return" then
				asmReturn()
		end switch
				
		line = gets(currentInputFileNum)
	end while

end for
-------------------------------------
-- procedures for arithmetic stack --
-------------------------------------

procedure add() 
	printf(resultFileNum , "@SP\nM=M-1\nA=M\nD=M\nA=A-1\nM=D+M\n")
end procedure

procedure sub() 
	printf(resultFileNum , "@SP\nM=M-1\nA=M\nD=M\nA=A-1\nM=M-D\n")
end procedure

procedure neg() 
	printf(resultFileNum , "@SP\nA=M-1\nM=-M\n")
end procedure

procedure eq() 
	printf(resultFileNum , "@SP\nM=M-1\nA=M\nD=M\nA=A-1\nD=M-D\nM=0\n@TRUE%d\nD;JEQ\n@END%d\n0;JMP\n(TRUE%d)\n@SP\nA=M-1\nM=-1\n(END%d)\n", {labelCounter,labelCounter,labelCounter,labelCounter})
	labelCounter += 1
end procedure

procedure gt() 
	printf(resultFileNum , "@SP\nM=M-1\nA=M\nD=M\nA=A-1\nD=M-D\nM=0\n@TRUE%d\nD;JGT\n@END%d\n0;JMP\n(TRUE%d)\n@SP\nA=M-1\nM=-1\n(END%d)\n", {labelCounter,labelCounter,labelCounter,labelCounter})
	labelCounter += 1
end procedure

procedure lt() 
	printf(resultFileNum , "@SP\nM=M-1\nA=M\nD=M\nA=A-1\nD=M-D\nM=0\n@TRUE%d\nD;JLT\n@END%d\n0;JMP\n(TRUE%d)\n@SP\nA=M-1\nM=-1\n(END%d)\n", {labelCounter,labelCounter,labelCounter,labelCounter})
	labelCounter += 1
end procedure

procedure asmAnd() 
	printf(resultFileNum , "@SP\nM=M-1\nA=M\nD=M\nA=A-1\nM=D&M\n")
end procedure

procedure asmOr() 
	printf(resultFileNum , "@SP\nM=M-1\nA=M\nD=M\nA=A-1\nM=D|M\n")
end procedure

procedure asmNot() 
	printf(resultFileNum , "@SP\nA=M-1\nM=!M\n")
end procedure

---------------------------------
-- procedure for push and pop --
---------------------------------

procedure pushAndPop(sequence command, sequence segment, integer offset) 

	if equal(command,"pop") then
		printf(resultFileNum , "@SP\nM=M-1\nA=M\nD=M\n@13\nM=D\n")
	end if
	
	sequence fromVal = "M"
	switch segment do
		case "local" then
			loc_arg_this_that("LCL", offset)
		case "argument" then
			loc_arg_this_that("ARG", offset)
		case "this" then
			loc_arg_this_that("THIS", offset)
		case "that" then
			loc_arg_this_that("THAT", offset)
		case "temp" then
			printf(resultFileNum , "@%d\nD=A\n@5\nA=D+A\n", {offset})
		case "static" then
			printf(resultFileNum , "@%s%d\n", {inputFileName,offset})
		case "pointer" then
			if offset = 0 then
				printf(resultFileNum , "@THIS\n")
			elsif offset = 1 then
				printf(resultFileNum , "@THAT\n")
			end if
		case "constant" then
			printf(resultFileNum , "@%d\n", {offset})
			fromVal = "A"
			
	end switch
	
	if equal(command,"push") then
		printf(resultFileNum , "D=%s\n@SP\nM=M+1\nA=M-1\nM=D\n", {fromVal})
	elsif equal(command,"pop") then
		printf(resultFileNum , "D=A\n@14\nM=D\n@13\nD=M\n@14\nA=M\nM=D\n")
	end if
	
	
end procedure

--------------------------------------------
-- procedure for segments in push and pop --
--------------------------------------------

procedure loc_arg_this_that(sequence Ptype, integer offset)
	printf(resultFileNum , "@%d\nD=A\n@%s\nA=D+M\n", {offset,Ptype})
end procedure

---------------------------
-- program flow commands --
---------------------------

procedure asmLabel(sequence labelName)
	printf(resultFileNum , "(%s%s)\n", {inputFileName,labelName})
end procedure

procedure asmGoto(sequence labelName)
	printf(resultFileNum , "@%s%s\n0;JMP\n", {inputFileName,labelName})
end procedure

procedure ifGoto(sequence labelName)
	printf(resultFileNum , "@SP\nM=M-1\nA=M\nD=M\n@%s%s\nD;JNE\n", {inputFileName,labelName})
end procedure

-------------------------------
-- function calling commands --
-------------------------------

procedure asmFunction(sequence name, integer numOfArgs)
	printf(resultFileNum , "(%s)\n", {name})
	integer i = 0
	while i<numOfArgs do
		pushAndPop("push","constant",0)
		i += 1
	end while
end procedure

procedure asmCall(sequence name, integer numOfArgs)
	-- push return address, LCL, ARG, THIS and THAT.
	printf(resultFileNum , "@returnAddress%d\nD=A\n@SP\nM=M+1\nA=M-1\nM=D\n", {labelCounter})
	printf(resultFileNum , "@LCL\nD=M\n@SP\nM=M+1\nA=M-1\nM=D\n")
	printf(resultFileNum , "@ARG\nD=M\n@SP\nM=M+1\nA=M-1\nM=D\n")
	printf(resultFileNum , "@THIS\nD=M\n@SP\nM=M+1\nA=M-1\nM=D\n")
	printf(resultFileNum , "@THAT\nD=M\n@SP\nM=M+1\nA=M-1\nM=D\n")
	
	-- update ARG pointer and LCL pointer for new function called.
	printf(resultFileNum , "@5\nD=A\n@%d\nD=D+A\n@SP\nD=M-D\n@ARG\nM=D\n", {numOfArgs})
	printf(resultFileNum , "@SP\nD=M\n@LCL\nM=D\n")
	
	-- go to the start of the called function
	printf(resultFileNum , "@%s\n0;JMP\n", {name})
	
	printf(resultFileNum , "(returnAddress%d)\n", {labelCounter})
	labelCounter += 1
end procedure

procedure asmReturn()

	/* 13 - FRAME
	   14 - RET */
	   
	-- save the return address in RET (RAM[14]) using RAM[13] as temp FRAME
	printf(resultFileNum , "@LCL\nD=M\n@13\nM=D\n")
	printf(resultFileNum , "@5\nD=A\n@13\nA=M-D\nD=M\n@14\nM=D\n")
	
	
	
	-- reposition the return value from the bottom of the stack to the place in the stack before the function was called
	printf(resultFileNum , "@SP\nM=M-1\nA=M\nD=M\n@ARG\nA=M\nM=D\n")
	printf(resultFileNum , "@ARG\nD=M+1\n@SP\nM=D\n")
	
	
	-- restore the segments of the calling function
	printf(resultFileNum , "@13\nA=M-1\nD=M\n@THAT\nM=D\n")
	printf(resultFileNum , "@2\nD=A\n@13\nA=M-D\nD=M\n@THIS\nM=D\n")
	printf(resultFileNum , "@3\nD=A\n@13\nA=M-D\nD=M\n@ARG\nM=D\n")
	printf(resultFileNum , "@4\nD=A\n@13\nA=M-D\nD=M\n@LCL\nM=D\n")
	
	-- goto back to the place in code where the function was called
	printf(resultFileNum , "@14\nA=M\n0;JMP\n")
end procedure