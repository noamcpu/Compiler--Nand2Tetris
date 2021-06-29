

include file.e
include std/convert.e
include std/sequence.e

-- name of path for vm files:
-- C:\Users\yinon\Desktop\tar0solution


integer currentInputFile
object line
sequence folderName = {}
sequence dirInfo
sequence VMfilesNames = {}

sequence path = gets(0)   

--get only the path to the directory without the \n at the end.
path = path[1..$-1]      


-- extract the name of the folder from the path (in our case tar0solution)
for i = length(path) to 1 by -1 do  
	if path[i] = '\\' then
		exit
	else
		folderName = prepend(folderName, path[i])
	end if
end for

dirInfo = dir(path)


-- get all the vm file names from the directory and put them in a sequence of strings
for i = 1 to length(dirInfo) do  
	if length(dirInfo[i][D_NAME]) > 2 and equal(dirInfo[i][D_NAME][$-2..$],".vm") and match("a", dirInfo[i][D_ATTRIBUTES]) then
		VMfilesNames = append(VMfilesNames, dirInfo[i][D_NAME])
	end if
end for


-- opening the result asm file as output
sequence resultFilePath = path & '\\' & folderName & ".asm"
integer resultFileNum = open(resultFilePath, "w")

if resultFileNum = -1 then
	puts(1, "Can't open result file\n")
	abort(1)
end if


atom totalCell = 0
atom totalBuy = 0

object command
integer inputFilesNum

-- running over all the input files
for i=1 to length(VMfilesNames) do

	inputFilesNum = open(path & '\\' & VMfilesNames[i], "r")
	if inputFilesNum = -1 then
		puts(1, "Can't open input file\n")
		abort(1)
	end if
	
	printf(resultFileNum, "%s\n",{VMfilesNames[i][1..$-3]})
	
	line = gets(inputFilesNum)
	
	-- running over all the lines of a file
	while sequence(line) do
		line = line[1..$-1]
		command = split(line)
		if equal(command[1], "cell") then
			HandleSell(command[2],to_integer(command[3]),to_number(command[4]))
		elsif  equal(command[1], "buy") then
			HandleBuy(command[2],to_integer(command[3]),to_number(command[4]))
		end if
		line = gets(inputFilesNum)
	end while
	
	close(inputFilesNum)
end for


-- procedure for sell command
procedure HandleSell(sequence Pname, integer amount, atom price)
	printf(resultFileNum, "$$$ CELL %s $$$\n",{Pname})
	totalCell += amount * price
	printf(resultFileNum, "%g\n",{amount * price})
end procedure

-- procedure for buy command
procedure HandleBuy(sequence Pname, integer amount, atom price)
	printf(resultFileNum, "### BUY %s ###\n",{Pname})
	totalBuy += amount * price
    printf(resultFileNum, "%g\n",{amount * price})
end procedure

printf(resultFileNum, "TOTAL BUY: %g\n",{totalBuy})
printf(resultFileNum, "TOTAL CELL: %g\n",{totalCell})

printf(1, "TOTAL BUY: %g\n",{totalBuy})
printf(1, "TOTAL CELL: %g\n",{totalCell})

close(resultFileNum)

gets(0)