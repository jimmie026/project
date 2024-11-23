class File {
	__New(dnc, data) {
		this.DncFiles := dnc ; Initiates DncFiles directory path.
		this.Data := data ; Inititates data.ini path.
	}
	;----------------------------------------
	;	Opening SourceFile.
	;----------------------------------------
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
	;----------------------------------------
	;	Finding files in DncFiles dir and archiving
	;	them when criterias are met.
	;----------------------------------------
	FindAndArchive(m, param := "") {
		this.mins := m
		
		Loop, Files, % this.DncFiles "\*.cnc"
		{
			this.FoundFile := A_LoopFileName
			
			if (param = "rip" && !this.IsValidRipFile(this.FoundFile)) { ; This code wont be useful for anyone else than the dev.
				Continue
			}
			
			TimeCompleted := this.GetTimeCompleted(this.FileContent, this.FoundFile) ; REVIEW THIS ONE.
			
			if (this.TimeDifference(TimeCompleted)) {
				this.Archive(this.FoundFile)
			}
		}
	}
	;----------------------------------------
	;	Valitating the length of the file found in DncFiles.
	;----------------------------------------
	IsValidRipFile(filename) {
		IsRipFile := RegExReplace(filename, ".cnc", "")
		return (StrLen(IsRipFile) = 4) ; Checking if the files only contains 4 characters.
	}
	;----------------------------------------
	;	Getting timestamp when a specific file are completed.
	;----------------------------------------
	GetTimeCompleted(filecontent, filename) {
		History := new History()
		return History.JobCompleted(filecontent, filename) ; Returning timestamp.
	}
	;----------------------------------------
	;	Archiving file.
	;----------------------------------------
	Archive(filename) {
		Source := this.DncFiles "\" filename
		Destination := this.DncFiles "\Archive\"
		
		FileMove, % Source , % Destination
		
		this.Counter()
		
		Sleep, 3000
	}
	;----------------------------------------
	;	Checking how old the file is.
	;----------------------------------------
	TimeDifference(timecompleted) {
		FormatTime, SystemTime,, HH:mm
		
		TimeCompletedMinutes := this.GetMinutes(timecompleted)
		SystemTimeMinutes := this.GetMinutes(SystemTime)
		
		return TimeDifference := (SystemTimeMinutes - TimeCompletedMinutes >= this.mins) ? true : false ; this.mins is the variable where the time you want to wait after a file was completed before you want to move it.
		
	}
	;----------------------------------------
	;	Splitting hour and minutes to minutes.
	;----------------------------------------
	GetMinutes(Time)
	{
		TimeParts := StrSplit(Time, ":")
		Return (TimeParts[1] * 60) + TimeParts[2]
	}
	;----------------------------------------
	;	Countning archived files.
	;----------------------------------------
	Counter() {
		IniRead, Counter, % Data, Counters, CncArchive
		
		Counter++
		
		IniWrite, % Counter, % Data, Counters, CncArchive
		
		return Counter
	}
}

class History {
	;----------------------------------------
	; Getting a timestamp when the file was completed.
	;----------------------------------------
	JobCompleted(filecontent, filename) {
		
		EndTime := this.GetEndTime(filecontent, filename)
		
		return (EndTime) ? EndTime : false
	}
	;----------------------------------------
	;	Looping through the job history to check if
	;	the file was completed. If the file was halted
	;	or was not completed, the script will leave this file.
	;----------------------------------------
	GetEndTime(filecontent, filename) {
		IsCompleted := "Job completed." ; EndType string to search for.
		EndTime := ""
		EndType := ""
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
}
DncFiles := "C:\Users\jimmi\Desktop\DncFiles"
Data := "C:\Users\jimmi\Desktop\data.ini"
JobHistory := "C:\Users\jimmi\Desktop\JobHistory.xjh"

File := new File(DncFiles, Data)

if (File.Open(JobHistory)) {
	File.FindAndArchive(10)
}