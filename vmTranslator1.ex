

include file.e
include std/convert.e
include std/sequence.e


integer labelCounter = 1

-- get the path to the vm file
sequence path = gets(0)
-- get the path without the \n at the end
path = path[1..$-1]
sequence inputFileName = split(path, '\\')
-- get the file name with a dot in the end for static segment in pop and push
inputFileName = inputFileName[$][1..$-2]


-------------------------
-- input vm file setup --
-------------------------

integer InputFileNum = open(path, "r")

if InputFileNum = -1 then
	puts(1, "Can't open input file\n")
	abort(1)
end if

---------------------------
-- result asm file setup --
---------------------------

sequence resultFilePath = path[1..$-3] & ".asm"
integer resultFileNum = open(resultFilePath, "w")

if resultFileNum = -1 then
	puts(1, "Can't open result file\n")
	abort(1)
end if

--------------------------
-- start of translation --
--------------------------

object line = gets(InputFileNum)

-- translate each line in vm file to hack assembly

while sequence(line) do

	line = line[1..$-1]
	-- the split function does not like empty sequences so we check in case of an empty row in input file
	if length(line) = 0 then
		line = gets(InputFileNum)
		continue
	end if
	line = split(line)

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
	end switch
			
	line = gets(InputFileNum)
end while


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

-- euphoria closes files automatically when the program terminates but it's good practice to manually close them
close(InputFileNum)
close(resultFileNum)