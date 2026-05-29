[Setup]
AppId={{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}
AppName=OnlyAudio
AppVersion=2.2.0
AppPublisher=AudioFeel
AppPublisherURL=https://github.com/onlyaudio
DefaultDirName={autopf}\OnlyAudio
DefaultGroupName=OnlyAudio
AllowNoIcons=yes
OutputDir=installer_output
OutputBaseFilename=OnlyAudio_Setup
SetupIconFile=onlyaudio.ico
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\onlyaudio_by_audiofeel.exe
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
; Close running instance before install/uninstall
CloseApplications=force
CloseApplicationsFilter=onlyaudio_by_audiofeel.exe

[Languages]
Name: "french"; MessagesFile: "compiler:Languages\French.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\OnlyAudio"; Filename: "{app}\onlyaudio_by_audiofeel.exe"; IconFilename: "{app}\onlyaudio_by_audiofeel.exe"
Name: "{group}\Désinstaller OnlyAudio"; Filename: "{uninstallexe}"
Name: "{autodesktop}\OnlyAudio"; Filename: "{app}\onlyaudio_by_audiofeel.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\onlyaudio_by_audiofeel.exe"; Description: "Lancer OnlyAudio"; Flags: nowait postinstall skipifsilent

[Code]
function GetUninstallString(): String;
var
  UninstallKey: String;
  UninstallString: String;
begin
  Result := '';
  UninstallKey := 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{#SetupSetting("AppId")}_is1';
  if RegQueryStringValue(HKCU, UninstallKey, 'UninstallString', UninstallString) then
    Result := UninstallString
  else if RegQueryStringValue(HKLM, UninstallKey, 'UninstallString', UninstallString) then
    Result := UninstallString;
end;

function IsUpgrade(): Boolean;
begin
  Result := (GetUninstallString() <> '');
end;

function UninstallPrevious(): Integer;
var
  UninstallString: String;
  ResultCode: Integer;
begin
  Result := 0;
  UninstallString := GetUninstallString();
  if UninstallString <> '' then
  begin
    UninstallString := RemoveQuotes(UninstallString);
    if Exec(UninstallString, '/VERYSILENT /NORESTART /SUPPRESSMSGBOXES', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
      Result := 0
    else
      Result := ResultCode;
  end;
end;

function InitializeSetup(): Boolean;
begin
  Result := True;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  Msg: String;
begin
  if CurStep = ssInstall then
  begin
    if IsUpgrade() then
    begin
      Msg := 'Une version précédente de OnlyAudio a été détectée.' + #13#10 +
             'Elle sera désinstallée avant de poursuivre.' + #13#10#13#10 +
             'Voulez-vous continuer ?';
      if MsgBox(Msg, mbConfirmation, MB_YESNO) = IDYES then
        UninstallPrevious()
      else
        Abort;
    end;
  end;
end;
