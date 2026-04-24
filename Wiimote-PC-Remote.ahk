; Wiimote-PC-Remote https://github.com/elModo7/Wiimote-PC-Remote
; Credits:
; - TheGood for AHKHID: https://github.com/jleb/AHKHID/blob/master/AHKHID.ahk
; - GeekDude / G33kDude for Neutron: https://github.com/G33kDude/Neutron.ahk
#NoEnv
#SingleInstance, Force
#Include lib\AHKHID.ahk
#Include lib\Neutron.ahk
ListLines, Off
SetBatchLines, -1
SetWorkingDir, %A_ScriptDir%

global neutron, CurrentButton := "A"
global ButtonOrder := ["Up", "Down", "Left", "Right", "A", "B", "1", "2", "Plus", "Minus", "Home"]

EnsureFolders()
EnsureButtonFiles()

neutron := new NeutronWindow()
neutron.Load("Wiimote-PC-Remote.html")
neutron.Gui("+LabelNeutron +Resize +MinSize960x650")
neutron.Show("w1120 h900", "Wiimote-PC-Remote")
PopulateUi()
RegisterWiimote()
return

FileInstall, Wiimote-PC-Remote.html, Wiimote-PC-Remote.html

NeutronClose:
NeutronEscape:
ExitApp
return

RegisterWiimote()
{
	global neutron
	GuiHandle := neutron.hWnd
	AHKHID_UseConstants()
	OnMessage(0x00FF, "InputMsg")
	AHKHID_AddRegister(1)
	AHKHID_AddRegister(1, 5, GuiHandle, 256)
	AHKHID_Register()
}

InputMsg(wParam, lParam)
{
	Critical
	r := AHKHID_GetInputData(lParam, uData)
	code := SubStr(Bin2Hex(&uData, r), 2, 5)
	button := ButtonFromHidCode(code)
	if (button != "")
	{
		HighlightPressed(button)
		Gosub, %button%
	}
}

ButtonFromHidCode(code)
{
	if (code = "00008")
		return "A"
	if (code = "00004")
		return "B"
	if (code = "00002")
		return "1"
	if (code = "00001")
		return "2"
	if (code = "01000")
		return "Plus"
	if (code = "00010")
		return "Minus"
	if (code = "00080")
		return "Home"
	if (code = "00800")
		return "Up"
	if (code = "00400")
		return "Down"
	if (code = "00100")
		return "Left"
	if (code = "00200")
		return "Right"
	return ""
}

HighlightPressed(button)
{
	global neutron
	try neutron.wnd.flashPressed(button)
}

SelectButton(neutron, button)
{
	global CurrentButton
	CurrentButton := button
	LoadButtonIntoEditor(button)
}

GenerateMapping(neutron, event:="")
{
	try event.preventDefault()
	formData := neutron.GetFormData(neutron.qs("#mappingForm"))
	button := formData.selectedButton
	code := BuildMappingScript(button, formData)
	neutron.qs("#script").value := code
	neutron.qs("#editorSummary").innerText := DescribeScript(code)
}

SaveCurrent(neutron, event)
{
	global CurrentButton
	event.preventDefault()
	formData := neutron.GetFormData(event.target)
	button := formData.selectedButton
	code := EnsureLabeledScript(button, formData.script)
	WriteButtonScript(button, code)
	CurrentButton := button
	RefreshButtonSummary(button)
	neutron.qs("#script").value := code
	neutron.qs("#editorSummary").innerText := DescribeScript(code)
	SetStatus("Saved. Press Ctrl+Shift+R or Apply to reload the includes.")
}

ClearCurrent(neutron, event)
{
	global CurrentButton
	button := CurrentButton
	code := DefaultButtonScript(button)
	neutron.qs("#script").value := code
	neutron.qs("#editorSummary").innerText := "No action assigned"
}

ReloadMappings(neutron, event:="")
{
	Reload
}

SaveProfile(neutron, event)
{
	event.preventDefault()
	formData := neutron.GetFormData(event.target)
	name := CleanProfileName(formData.profileName)
	if (name = "")
	{
		SetStatus("Enter a profile name.")
		return
	}
	target := A_ScriptDir "\profiles\" name
	FileCreateDir, %target%
	FileCopyDir, %A_ScriptDir%\btn, %target%, 1
	SetStatus("Profile saved: " name)
	RefreshProfiles()
}

LoadProfile(neutron, event)
{
	try event.preventDefault()
	formData := neutron.GetFormData(neutron.qs("#profileForm"))
	name := CleanProfileName(formData.profileName)
	if (name = "")
	{
		SetStatus("Enter a profile name.")
		return
	}
	source := A_ScriptDir "\profiles\" name
	if !FileExist(source)
	{
		SetStatus("That profile does not exist.")
		return
	}
	FileCopyDir, %source%, %A_ScriptDir%\btn, 1
	SetStatus("Profile loaded. Reloading...")
	Reload
}

DeleteProfile(neutron, event)
{
	try event.preventDefault()
	formData := neutron.GetFormData(neutron.qs("#profileForm"))
	name := CleanProfileName(formData.profileName)
	if (name = "")
	{
		SetStatus("Enter a profile name.")
		return
	}
	target := A_ScriptDir "\profiles\" name
	if !FileExist(target)
	{
		SetStatus("That profile does not exist.")
		return
	}
	FileRemoveDir, %target%, 1
	SetStatus("Profile deleted: " name)
	RefreshProfiles()
}

PopulateUi()
{
	global ButtonOrder
	for i, button in ButtonOrder
		RefreshButtonSummary(button)
	RefreshProfiles()
	LoadButtonIntoEditor("A")
	SetStatus("Ready. Select a button and create a mapping.")
}

LoadButtonIntoEditor(button)
{
	global neutron
	code := ReadButtonScript(button)
	desc := DescribeScript(code)
	try neutron.wnd.selectButtonFromAhk(button, code, desc)
}

RefreshButtonSummary(button)
{
	global neutron
	code := ReadButtonScript(button)
	desc := DescribeScript(code)
	try neutron.wnd.setButtonSummary(button, desc)
}

RefreshProfiles()
{
	global neutron
	html := ""
	Loop, Files, %A_ScriptDir%\profiles\*, D
		html .= neutron.FormatHTML("<option value='{}'>{}</option>", A_LoopFileName, A_LoopFileName)
	try neutron.qs("#profileList").innerHTML := html
}

SetStatus(text)
{
	global neutron
	try neutron.qs("#status").innerText := text
}

BuildMappingScript(button, formData)
{
	mode := formData.mode
	if (mode = "button")
	{
		target := formData.targetButton
		if (target = "" || target = button)
			return DefaultButtonScript(button)
		return ButtonLabel(button) ":`nGosub, " ButtonLabel(target) "`nreturn`n"
	}
	if (mode = "key")
	{
		keys := Trim(formData.keySequence)
		if (keys = "")
			keys := "{Enter}"
		return ButtonLabel(button) ":`nSend, " keys "`nreturn`n"
	}
	if (mode = "macro")
	{
		lines := Trim(formData.macroLines, "`r`n`t ")
		if (lines = "")
			lines := "Send, {Enter}"
		return ButtonLabel(button) ":`n" NormalizeAhkLines(lines) "`nreturn`n"
	}
	if (mode = "run")
	{
		target := Trim(formData.runTarget)
		if (target = "")
			target := "notepad.exe"
		return ButtonLabel(button) ":`nRun, " target "`nreturn`n"
	}
	return EnsureLabeledScript(button, formData.script)
}

NormalizeAhkLines(text)
{
	out := ""
	Loop, Parse, text, `n, `r
	{
		line := Trim(A_LoopField)
		if (line = "")
			continue
		out .= line "`n"
	}
	return RTrim(out, "`n")
}

EnsureLabeledScript(button, code)
{
	code := Trim(code, "`r`n`t ")
	label := ButtonLabel(button)
	if (code = "")
		return DefaultButtonScript(button)
	firstLine := ""
	Loop, Parse, code, `n, `r
	{
		firstLine := Trim(A_LoopField)
		break
	}
	if (firstLine = label ":")
		return code "`n"
	return label ":`n" code "`nreturn`n"
}

DefaultButtonScript(button)
{
	return ButtonLabel(button) ":`nreturn`n"
}

DescribeScript(code)
{
	code := Trim(code)
	if (code = "" || code ~= "is)^[A-Za-z0-9]+:\s*return$")
		return " No action"
	if RegExMatch(code, "im)^\s*Gosub,\s*([A-Za-z0-9]+)", m)
		return " Remaps to " DisplayName(m1)
	if RegExMatch(code, "im)^\s*Send,\s*(.+)$", m)
		return " Sends " Shorten(m1, 34)
	if RegExMatch(code, "im)^\s*Run,\s*(.+)$", m)
		return " Opens " Shorten(m1, 34)
	if RegExMatch(code, "im)^\s*MsgBox,\s*(.+)$", m)
		return " Message " Shorten(m1, 30)
	return " Custom script"
}

Shorten(text, max)
{
	text := Trim(text)
	if (StrLen(text) <= max)
		return text
	return SubStr(text, 1, max - 1) "..."
}

DisplayName(label)
{
	if (label = "Plus")
		return "+"
	if (label = "Minus")
		return "-"
	return label
}

ReadButtonScript(button)
{
	path := ButtonFile(button)
	FileRead, code, %path%
	if ErrorLevel
		code := DefaultButtonScript(button)
	return code
}

WriteButtonScript(button, code)
{
	path := ButtonFile(button)
	FileDelete, %path%
	FileAppend, %code%, %path%
}

ButtonFile(button)
{
	if (button = "Plus")
		return A_ScriptDir "\btn\+.ahk"
	if (button = "Minus")
		return A_ScriptDir "\btn\-.ahk"
	return A_ScriptDir "\btn\" button ".ahk"
}

ButtonLabel(button)
{
	return button
}

CleanProfileName(name)
{
	name := Trim(name)
	name := RegExReplace(name, "[\\/:*?""<>|]", "-")
	return name
}

EnsureFolders()
{
	FileCreateDir, %A_ScriptDir%\btn
	FileCreateDir, %A_ScriptDir%\profiles
}

EnsureButtonFiles()
{
	global ButtonOrder
	for i, button in ButtonOrder
	{
		path := ButtonFile(button)
		if !FileExist(path)
			WriteButtonScript(button, DefaultButtonScript(button))
	}
}

#Include btn\Up.ahk
#Include btn\-.ahk
#Include btn\+.ahk
#Include btn\1.ahk
#Include btn\2.ahk
#Include btn\A.ahk
#Include btn\B.ahk
#Include btn\Down.ahk
#Include btn\Home.ahk
#Include btn\Left.ahk
#Include btn\Right.ahk

Bin2Hex(addr, len)
{
	static fun, ptr
	if (fun = "")
	{
		if A_IsUnicode
			if (A_PtrSize = 8)
				h=4533c94c8bd14585c07e63458bd86690440fb60248ffc2418bc9410fb6c0c0e8043c090fb6c00f97c14180e00f66f7d96683e1076603c8410fb6c06683c1304180f8096641890a418bc90f97c166f7d94983c2046683e1076603c86683c13049ffcb6641894afe75a76645890ac366448909c3
			else h=558B6C241085ED7E5F568B74240C578B7C24148A078AC8C0E90447BA090000003AD11BD2F7DA66F7DA0FB6C96683E2076603D16683C230668916240FB2093AD01BC9F7D966F7D96683E1070FB6D06603CA6683C13066894E0283C6044D75B433C05F6689065E5DC38B54240833C966890A5DC3
		else h=558B6C241085ED7E45568B74240C578B7C24148A078AC8C0E9044780F9090F97C2F6DA80E20702D1240F80C2303C090F97C1F6D980E10702C880C1308816884E0183C6024D75CC5FC606005E5DC38B542408C602005DC3
		VarSetCapacity(fun, StrLen(h) // 2)
		Loop % StrLen(h) // 2
			NumPut("0x" . SubStr(h, 2 * A_Index - 1, 2), fun, A_Index - 1, "Char")
		ptr := A_PtrSize ? "Ptr" : "UInt"
		DllCall("VirtualProtect", ptr, &fun, ptr, VarSetCapacity(fun), "UInt", 0x40, "UInt*", 0)
	}
	VarSetCapacity(hex, A_IsUnicode ? 4 * len + 2 : 2 * len + 1)
	DllCall(&fun, ptr, &hex, ptr, addr, "UInt", len, "CDecl")
	VarSetCapacity(hex, -1)
	return hex
}
