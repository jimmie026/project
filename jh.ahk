class File {
	__New(dnc, data) {
		this.DncFiles := dnc
		this.Data := data
	}
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
	FindAndArchive(m, param := "") {
		this.mins := m
		
		Loop, Files, % this.DncFiles "\*.cnc"
		{
			this.FoundFile := A_LoopFileName
			
			if (param = "rip" && !this.IsValidRipFile(this.FoundFile)) {
				Continue
			}
			
			TimeCompleted := this.GetTimeCompleted(this.FileContent, this.FoundFile)
			
			if (this.TimeDifference(TimeCompleted)) {
				this.Archive(this.FoundFile)
			}
		}
	}
	IsValidRipFile(filename) {
		IsRipFile := RegExReplace(filename, ".cnc", "")
		return (StrLen(IsRipFile) = 4)
	}
	GetTimeCompleted(filecontent, filename) {
		History := new History()
		return History.JobCompleted(filecontent, filename)
	}
	Archive(filename) {
		Source := this.DncFiles "\" filename
		Destination := this.DncFiles "\Archive\"
		
		FileMove, % Source , % Destination
		
		this.Counter()
		
		Sleep, 3000
	}
	TimeDifference(timecompleted) {
		FormatTime, SystemTime,, HH:mm
		
		TimeCompletedMinutes := this.GetMinutes(timecompleted)
		SystemTimeMinutes := this.GetMinutes(SystemTime)
		
		return TimeDifference := (SystemTimeMinutes - TimeCompletedMinutes >= this.mins) ? true : false
		
	}
	GetMinutes(Time)
	{
		TimeParts := StrSplit(Time, ":")
		Return (TimeParts[1] * 60) + TimeParts[2]
	}
	Counter() {
		IniRead, Counter, % Data, Counters, CncArchive
		
		Counter++
		
		IniWrite, % Counter, % Data, Counters, CncArchive
		
		return Counter
	}
}

class History {
	JobCompleted(filecontent, filename) {
		
		if (!filecontent) {
			MsgBox, Sourcefile does not contain any data.
			return
		}
		
		EndTime := this.GetEndTime(filecontent, filename)
		
		return (EndTime) ? EndTime : false
	}	
	GetEndTime(filecontent, filename) {
		IsCompleted := "Job completed."
		EndTime := ""
		EndType := ""
		Pos := 1
		
		Loop
		{
			if (!InStr(EndType, IsCompleted)) {
				FoundPos := RegExMatch(filecontent, filename, MatchStr, Pos)

				if (!MatchStr) {
					return false
					break
				}

				Pos := FoundPos+StrLen(MatchStr)
				RegExMatch(filecontent, "EndTime="".+?""", EndTime, Pos)
				EndTime := SubStr(EndTime, -8, 5)
				RegExMatch(filecontent, "EndType="".+?""", EndType, Pos)
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