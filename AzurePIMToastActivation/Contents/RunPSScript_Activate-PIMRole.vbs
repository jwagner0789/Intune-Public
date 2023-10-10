Dim commandString, shellObj, exitCode
commandString = "powershell.exe -NoProfile -NoLogo -NonInteractive -ExecutionPolicy Bypass -File ""C:\ProgramData\PIM_Activation\Activate-PIMRole.ps1"""
Set shellObj = CreateObject("WScript.Shell")
' exitCode = shellObj.Run (strCommand, [intWindowStyle], [bWaitOnReturn]) 
exitCode = shellObj.Run(commandString, 0, true)
WScript.Quit(exitCode)
