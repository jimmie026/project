;----------------------------------------------------------------
;
;	DncNinja 0.3.15
;
;	2024 - jimmie(at)skylto.se
;
;----------------------------------------------------------------
;
;	This is a library for archiving files in
;	the DncFiles-folder on a computer serving
;	MULTICAM machines.
;	When running a lot of files in a day,
;	the list in the hand unit tends to get
;	long after a day and it takes a lot
;	of time to scroll through the pages to
;	find the file you are searching for.
;
;	This Library will help you to keep the
;	filelist in the hand unit short.
;
;----------------------------------------------------------------

class File {
	__New(dnc, sub := "") {
		this.ErrorHandler := new ErrorHandler()
		
		if (dnc = "") {
			MsgBox, , DncNinja, Error! No path to DncFiles was provided.
			this.ErrorHandler.Push(A_ThisFunc, A_LineNumber, "No path to DncFiles was provided.")
			
			return false
		}
		if (sub) {
			this.DncFiles := dnc "\" sub ; Initiates DncFiles with chosen subdirectory.
		}
		else {
			this.DncFiles := dnc ; Initiates DncFiles root directory.
		}
		
		this.Data := A_ScriptDir "\data.ini" ; Inititates data.ini path.
		
	}
	;------------------------------------------------------------
	;	Opening SourceFile.
	;
	;	Usage:
	;	-	Provide the jobhistory file located
	;		in Coreo Command directory.
	;------------------------------------------------------------
	Open(filename) {
		
		SourceFile := FileOpen(filename, "r")
		this.FileContent := SourceFile.Read()
		
		SourceFile.Close()
		
		if (!IsObject(SourceFile)) {
			MsgBox, , DncNinja, Error! Could not open source file.
			this.ErrorHandler.Push(A_ThisFunc, A_LineNumber, "Could not open source file.")
			
			return false
		}
		else {
			return this.FileContent
		}
	}
	;------------------------------------------------------------
	;	Finding files in DncFiles dir and
	;	archiving them when criterias are met.
	;
	;	Usage:
	;	-	m = How many minutes from where the
	;		was completed before it will be
	;		triggered.
	;		param = If this one is left blank
	;		it will be triggered on all files.
	;		Else it will only be triggered on
	;		filenames with characters of 4 for
	;		an internal purpose of the dev.
	;------------------------------------------------------------
	FindAndArchive(m, param := "") {
		this.mins := m

		Loop, Files, % this.DncFiles "\*.cnc"
		{
			this.FoundFile := A_LoopFileName
			
			if (InStr(this.FoundFile, "[")) ; If a machine number is present in the filenamne, it will remove it before continuing.
			{
			
				this.FoundFile := RegExReplace(this.FoundFile, "\[[0-9]\]", "")
				
				Source := this.DncFiles "\" A_LoopFileName
				Destination := this.DncFiles "\" this.FoundFile
				
				FileMove, %Source%, %Destination%
				
				while (!Destination) {
					
					if (A_Index >= 10) {
						
						MsgBox, , DncNinja, Error! Could not rename file.
						this.ErrorHandler.Push(A_ThisFunc, A_LineNumber, "Could not rename file.")
						
						break
					}
					Sleep, 500
				}
			}
			
			if (param = "rip" && !this.IsValidRipFile(this.FoundFile)) { ; This code wont be useful for anyone else than the dev.
				Continue
			}
			
			TimeCompleted := this.GetTimeCompleted(this.FileContent, this.FoundFile)
	
			if (this.TimeDifference(TimeCompleted) || this.mins = 0) { ; If time criteria are met, these files will be archived OR if the time was set to 0 it will archive all of the files in the DncFiles folder.
				this.Archive(this.FileContent, this.FoundFile)
			}
			else {
				return false ; If there were no files to be moved it will retun false.
			}
		}
		return true
	}
	;------------------------------------------------------------
	;	Valitating the length of the file
	;	found in DncFiles.
	;------------------------------------------------------------
	IsValidRipFile(filename) {
		FilenameNoExt := RegExReplace(filename, ".cnc", "")
		
		return (StrLen(FilenameNoExt) = 4) ; Checking if the files only contains 4 characters.
	}
	;------------------------------------------------------------
	;	Getting timestamp when a specific
	;	file are completed.
	;------------------------------------------------------------
	GetTimeCompleted(filecontent, filename) {
		History := new History()
		
		return History.JobCompleted(filecontent, filename) ; Returning timestamp.
	}
	;------------------------------------------------------------
	;	Creating a new folder in Archive
	;	with todays date.
	;	Archiving the file into that folder
	;	with a machine number appended to the
	;	filename.
	;------------------------------------------------------------
	Archive(filecontent, filename) {
		FilenameNoExt := RegExReplace(filename, ".cnc", "")
		
		Machine := new Machine()
		History := new History()
		
		DateFolder := A_DD "-" A_MM "-" A_YYYY
		
		if (!FileExist(this.DncFiles "\Archive\" A_DD "-" A_MM "-" A_YYYY)) {
			FileCreateDir, % this.DncFiles "\Archive\" A_DD "-" A_MM "-" A_YYYY ; Creating folder with todays date.
			
			while (!FileExist(this.DncFiles "\Archive\" A_DD "-" A_MM "-" A_YYYY)) {
				if (A_Index >= 10) {
					DncFiles := this.DncFiles
					
					MsgBox, , DncNinja, Error! Could not create %DateFolder% in %DncFiles% "\Archive\"
					this.ErrorHandler.Push(A_ThisFunc, A_LineNumber, "Could not create folder in DncFiles")
					
					return false
				}
				sleep, 500
			}
		}
			
		MachineNR := Machine.Get(History.GetConnection(filecontent, filename))
		
		if (!MachineNR) {
			MachineNR := 0 ; If the machine number could not be found, it will still proceed, but the machine number in the filename will be set to 0.
		}
		
		Source := this.DncFiles "\" filename
		Destination := this.DncFiles "\Archive\" DateFolder "\" FilenameNoExt "[" MachineNR "].cnc" ; Appending machine number to the filename.
		
		FileMove, %Source% , %Destination%
		
		while (!Destination) {
				
			if (A_Index >= 10) {
				MsgBox, , DncNinja, Error! Could not move file.
				this.ErrorHandler.Push(A_ThisFunc, A_LineNumber, "Could not move file")
				
				break
			}
			Sleep, 500
		}
		
		this.Counter(1)
		
		Sleep, 3000 ; Loop if !FileExist instead.
		
		return true
	}
	;------------------------------------------------------------
	;	Checking the time since the file was
	;	completed.
	;------------------------------------------------------------
	TimeDifference(timecompleted) {
		FormatTime, SystemTime,, HH:mm
		
		TimeCompletedMinutes := this.GetMinutes(timecompleted) ; Comparing the time when the file was completed with the systems time.
		SystemTimeMinutes := this.GetMinutes(SystemTime)
		
		return TimeDifference := (SystemTimeMinutes - TimeCompletedMinutes >= this.mins) ? true : false ; this.mins is the variable where the time you want to wait after a file was completed before you want to move it.
		
	}
	;------------------------------------------------------------
	;	Splitting hour and minutes to minutes.
	;------------------------------------------------------------
	GetMinutes(Time)
	{
		TimeParts := StrSplit(Time, ":")
		Return (TimeParts[1] * 60) + TimeParts[2] ; Converting time to minutes.
	}
	;------------------------------------------------------------
	;	Countning archived files.
	;------------------------------------------------------------
	Counter(x := "") {
		if (!FileExist(A_ScriptDir "\data.ini")) {
			FileAppend, , %A_ScriptDir%\data.ini
			While (!FileExist(A_ScriptDir "\data.ini")) {
				if (A_Index >= 10) {
					MsgBox, , DncNinja, Could not create data.ini in %A_ScriptDir%.
					this.ErrorHandler.Push(A_ThisFunc, A_LineNumber, "Could not create data.ini")
					
					return false
				}
				Sleep, 500
			}
			IniWrite, 0, % this.Data, Counters, ArchivedFiles
		}
		IniRead, Counter, % this.Data, Counters, ArchivedFiles
		
		if (x = 1) {
			Counter++
		}
		else if (x = 0){ ; A negative counting will only be beployed if there was a pullback. 
			Counter--
		}
		
		IniWrite, % Counter, % this.Data, Counters, ArchivedFiles ; Saving the counter externaly.
		
		return Counter
	}
	;------------------------------------------------------------
	;	Restoring a file that once have been archived.
	;------------------------------------------------------------
	PullBack(filename) {
		
		
		FileExsisting := false
		
		Loop, Files, % this.DncFiles "\Archive\" filename "[*].cnc", R ; It will search for the file in the subdirectories of Archive.(R)
		{
			Source := A_LoopFileLongPath
			Destination := this.DncFiles
			
			FileExsisting := true
			
			break
		}
		
		if (FileExsisting) {
			FileMove, %Source%, %Destination%, 1

			this.Counter(0)
		
			return true
		}
		else {
			MsgBox, , DncNinja, Error! File does not exsist in archive.
			this.ErrorHandler.Push(A_ThisFunc, A_LineNumber, "File does not exsist in archive")
			
			return false
		}
	}
}

class History {
	;------------------------------------------------------------
	;	Getting a timestamp when the file 
	;	was completed.
	;------------------------------------------------------------
	JobCompleted(filecontent, filename) {
		
		EndTime := this.GetEndTime(filecontent, filename)
		
		return (EndTime) ? EndTime : false
	}
	;------------------------------------------------------------
	;	Looping through the job history to
	;	check if the file was completed.
	;	If the file was halted or was not
	;	completed in any other way, the script
	;	will leave this file.
	;------------------------------------------------------------
	GetEndTime(filecontent, filename) {
		IsCompleted := "Job completed." ; EndType string to search for.
		EndTime := ""
		EndType := ""
		Connection := ""
		Pos := 1
		
		Loop
		{
			if (!InStr(EndType, IsCompleted)) {
				FoundPos := RegExMatch(filecontent, filename, MatchStr, Pos) ; Finding the filename-string in job history-file.

				if (!MatchStr) {
					return false
					break
				}

				Pos := FoundPos+StrLen(MatchStr)
				RegExMatch(filecontent, "EndTime="".+?""", EndTime, Pos) ; Finding the time when the job was completed.
				EndTime := SubStr(EndTime, -8, 5) ; Removing seconds fromt he timestamp.
				RegExMatch(filecontent, "EndType="".+?""", EndType, Pos) ; Finding the endtype i.e if the job was completed or halted.
			}
			else {
				return EndTime
			}
		}
	}
	;------------------------------------------------------------
	;	Looping through the job history to
	;	locate the machineID.
	;------------------------------------------------------------
	GetConnection(filecontent, filename) {
		IsCompleted := "Job completed." ; EndType string to search for.
		EndType := ""
		MachineID := ""
		Pos := 1
		
		Loop
		{
			if (!InStr(EndType, IsCompleted)) {
				FoundPos := RegExMatch(filecontent, filename, MatchStr, Pos) ; Finding the filename-string in job history-file.

				if (!MatchStr) {
					return false
				}

				Pos := FoundPos+StrLen(MatchStr)
				RegExMatch(filecontent, "EndType="".+?""", EndType, Pos) ; Finding the endtype i.e if the job was completed or halted.
				RegExMatch(filecontent, "Connection="".+?""", MachineID, Pos)
				RegExMatch(MachineID, "\((\d+)\)", MachineID)
				MachineID := MachineID1 ; The output will contain () and RegEx will yield a 1 after the output variable. This variable contains the match from Gruop 1 when matching.
			}
			else {
				return MachineID
			}
		}
	}
}

class Machine {
	__New(l) {
		this.List := l ; Machinelist array.
		if (this.List = "") {
			MsgBox, , DncNinja, Error! No machine list was provided.
			this.ErrorHandler.Push(A_ThisFunc, A_LineNumber, "No machine list was provided.")
			
			return false
		}
		this.ErrorHandler := new ErrorHandler()
	}
	;------------------------------------------------------------
	;	Matching the machineNR withe the
	;	MachineID. This is for those who have
	;	more than one machine so you can keep
	;	track on wich machine have completed
	;	the job and append the machineNR to
	;	the archived files name.
	;
	;	Usage:
	;	-	machineID = Provide multicams
	;		machineID to get the machineNR
	;		in return from the library.
	;------------------------------------------------------------
	Get(machineID) {
		for k, v in this.List
		{	
			machineNR := k
			if (v = machineID) {
				return machineNR ; MFindning and matching the MachineNr with the MachineID.
			}
		}
		MsgBox, , DncNinja, Error! Could not get the machine number.
		this.ErrorHandler.Push(A_ThisFunc, A_LineNumber, "Could not get the machine number.")
		
		return false
	}
	;------------------------------------------------------------
	;	Parcing out the list of machines in
	;	the  library.
	;------------------------------------------------------------
	GetLibrary() {
		for k, v in this.List
		{
			MachineNR := k
			MachineID := v
			if (v = "undefined") {
				Continue
			}
			else {
				Library .= MachineNR "(" MachineID ")`n" ; Parsing a list of machines.
			}
		}
		if (Library = "") {
			MsgBox, , DncNinja, Error! There are no machines in the library.
			this.ErrorHandler.Push(A_ThisFunc, A_LineNumber, "No machine found.")
			
			return false
		}
		MsgBox, , DncNinja, List of machines in the library: `n %Library%
		return true
	}
	
}
class ErrorHandler {
	Push(from, line, msg) {
		TimeStamp := A_DD "-" A_MM "-" A_YYYY  "[" A_Hour ":" A_Min "]"
		ErrorMessage := TimeStamp " - " from " @ line: " line  " ( " msg " )`n"
		
		FileAppend, %ErrorMessage%, %A_ScriptDir%\ErrorLog.txt
	}
}


;------------------------------------------------------------
;	Settings
;
;	1 = Machine number. 00000 = Multicam
;	machine ID.
;	Change the machine ID before usage.
;	Add more machines if needed by placing
;	a , in the array.
;	( {1: 00000, 2: 00000} and so on.)
;------------------------------------------------------------
MachineList := {1: 00000} ; Provide machine ID before runing.
DncFiles := "\DncFiles" ; Provide correct path before running.
SubDirectory := "" ; Provide correct path before running. Use this only if you dont work i the root of DncFiles.
JobHistory := "\JobHistory.xjh" ;Provide correct path before running.

;------------------------------------------------------------
;	Initiating objects.
;------------------------------------------------------------
Machine := new Machine(MachineList)
File := new File(DncFiles) ; You can add SubDirectory as an parameter after DncFiles if your working direcory isn't the root of DncFiles.

;------------------------------------------------------------
;	Running the script.
;------------------------------------------------------------
File.Open(JobHistory) ; Provide correct path before running.
File.FindAndArchive(0) ; Set the time in minutes. 0 will archive all.