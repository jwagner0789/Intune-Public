powershell.exe -Version 5.1 -WindowStyle hidden -NonInteractive -NoLogo -NoProfile -Command "& '%1'.Replace('pwrshll://', '').Trim('/') '%2'.Trim('/') '%3'.Trim('/') '%4'.Trim('/') '%5' '%6'.Trim('/') '%7'.Trim('/')"