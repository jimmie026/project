;----------------------------------------------------------------
;
;	DncNinja 0.1.0
;
;	2024 - jimmie(at)skylto.se
;
;----------------------------------------------------------------
;
;	This is a library for archiving files in
;	the DncFiles-folder on a computer serving
;	MULTICAM machines.
;	When running a lot of files in a day,
;	the list in the hand unit thends to get
;	long after a day and it takes a lot
;	of time to scroll through the pages to
;	find the file you are searching for.
;
;	This Library will help you to keep the
;	filelist in the hand unit short.
;
;----------------------------------------------------------------

class File {
	__New(dnc, data) {
		this.DncFiles := dnc ; Initiates DncFiles directory path.
		this.Data := data ; Inititates data.ini path.
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
			MsgBox, Error! Could not open source file.
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
			
			if (param = "rip" && !this.IsValidRipFile(this.FoundFile)) { ; This code wont be useful for anyone else than the dev.
				Continue
			}
			
			TimeCompleted := this.GetTimeCompleted(this.FileContent, this.FoundFile)
			
			if (this.TimeDifference(TimeCompleted)) { ; 
			
				this.Archive(this.FileContent, this.FoundFile)
			}
		}
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
		
		if (!FileExist(this.DncFiles "\Archive\" A_DD "-" A_MM "-" A_YYYY)) {
			FileCreateDir, % this.DncFiles "\Archive\" A_DD "-" A_MM "-" A_YYYY ; Creating folder with todays date.
			
			while (!FileExist(this.DncFiles "\Archive\" A_DD "-" A_MM "-" A_YYYY)) {
				sleep, 500
			}
		}
		
		DateFolder := A_DD "-" A_MM "-" A_YYYY
		
		MachineID := Machine.Get(History.GetConnection(filecontent, filename))
		
		Source := this.DncFiles "\" filename
		Destination := this.DncFiles "\Archive\" DateFolder "\" FilenameNoExt "[" MachineID "].cnc" ; Appending machine number to the filename.
		
		FileMove, %Source% , %Destination%
		
		this.Counter()
		
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
	Counter() {
		if (!FileExist(A_ScriptDir "\data.ini") {
			FileAppend, , %A_ScriptDir%\data.ini
			While (!FileExist(A_ScriptDir "\data.ini") {
				Sleep, 500
			}
		}
		IniRead, Counter, % Data, Counters, CncArchive
		
		Counter++
		
		IniWrite, % Counter, % Data, Counters, CncArchive ; Saving the counter externaly.
		
		return Counter
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
					break
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
				Library .= MachineNR "(" MachineID ")`n" ; Parsing list of machines.
			}
		}
		if (Library = "") {
			MsgBox, There are no machines in the library.
			return false
		}
		MsgBox % "List of machines in the library: `n" Library
		return true
	}
	
}


;------------------------------------------------------------
;	1 = Machine number. 00000 = Multicam
;	machine ID.
;	Change the machine ID before usage.
;	Add more machines if needed by placing
;	a , in the array.
;	( {1: 00000, 2: 00000} and so on.)
;------------------------------------------------------------
MachineList := {1: 00000} ; Provide machine ID before runing.
Machine := new Machine(MachineList)

DncFiles := "\DncFiles" ; Provide correct path before running.
Data := A_ScriptDir "\data.ini"
File := new File(DncFiles, Data)

History := new History()

;------------------------------------------------------------
;	Running the script.
;------------------------------------------------------------
File.Open("\JobHistory.xjh") ; Provide correct path before running.
File.FindAndArchive(0) ; Set the time in minutes.