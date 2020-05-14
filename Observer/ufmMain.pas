unit ufmMain;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms, Dialogs, StdCtrls, ExtCtrls,
  Generics.Collections, ComCtrls;

const
  CM_PROCEND = WM_USER + 10;
  SC_STAYONTOP = WM_USER + 11;

type
  TWhichFontFather = class(TForm)
    btn1: TButton;
    pnl1: TPanel;
    btn2: TButton;
    lvFonts: TListView;
    procedure FormDestroy(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure btn1Click(Sender: TObject);
  private
    { Private declarations }
    FFontCache: TDictionary<string, Integer>;
    procedure AddOrUpdateFont(info: string);
    procedure LaunchAndHook(szExe: string; szDll: string);
    procedure WMCopyData(var Msg: TWMCopyData); message WM_COPYDATA;
    procedure CMProcEnd(var Msg: TMessage); message CM_PROCEND;
    procedure WMSysCommand(var Message: TWMSysCommand); message WM_SYSCOMMAND;
  public
    { Public declarations }
  end;

  TFONTINFO = packed record
    FontWanted: array[0..LF_FACESIZE - 1] of Char;
    FontStyle: array[0..LF_FACESIZE - 1] of Char;
  end;

  PFontInfo = ^TFONTINFO;

var
  WhichFontFather: TWhichFontFather;

implementation

{$R *.dfm}

procedure ProcWaiter(PHandle: THandle);
begin
  WaitForSingleObject(PHandle, INFINITE);
  CloseHandle(PHandle);
  PostMessage(WhichFontFather.Handle, CM_PROCEND, 0, 0);
end;

function RemoteInjectTo(const Guest, AlterGuest: WideString; const procHandle: THandle; bKillTimeOut: Boolean; nTimeout:
  DWORD; var thrdHandle: Thandle): DWORD;
// 远程注入函数
type
  lpparam = record
    LibFileName: Pointer;
    LibAlterFileName: Pointer;
    hfile: Thandle;
    dwFlag: Cardinal;
    func, exitthread: Pointer;
  end;

  plpparam = ^lpparam;

  TLoadLibEx = function(lpLibFileName: PWideChar; hfile: Thandle; dwFlags: DWORD): HMODULE; stdcall;

  TExitThread = procedure(dwExitCode: DWORD); stdcall;
var
  { 被注入的进程句柄,进程ID }
  dwRemoteProcessId: DWORD;

  { 写入远程进程的内容大小 }
  memSize: DWORD;

  { 写入到远程进程后的地址 }
  pszLibMem: Pointer;
  iReturnCode: Boolean;
  TempVar: SIZE_T;
  TempDWORD: Cardinal;

  { 指向函数LoadLibraryW的地址 }
  pfnStartAddr: TFNThreadStartRoutine;

  { dll全路径,需要写到远程进程的内存中去 }
  pszLibAFilename: PWideChar;
  pszLibAAlterFileName: PWideChar;
  lpLibParam: lpparam;

  // Delphi always assume the thread param is in RCX while in CreateRemoteThread, it's in R8
  // Adding an extra useless variable tricks delphi to use R8 as its parameter source
  // Stack balance is not important as we will call ExitThread to terminate our thread without returns

  function loader({$IFDEF WIN64}dumy: NativeUInt; {$ENDIF}param: plpparam): HMODULE; stdcall;
  begin
    Result := TLoadLibEx(param^.func)(param^.LibFileName, 0, LOAD_WITH_ALTERED_SEARCH_PATH);
    if Result = 0 then
      TLoadLibEx(param^.func)(param^.LibAlterFileName, 0, 0);
    TExitThread(param^.exitthread)(Result);
  end;

begin
  Result := 0;
  if procHandle = 0 then
  begin
    Result := 0;
    Exit;
  end;

  { 为注入的dll文件路径分配内存大小,由于为WideChar,故要乘2 }
  GetMem(pszLibAFilename, Length(Guest) * 2 + 2);
  StringToWideChar(Guest, pszLibAFilename, Length(Guest) * 2 + 2);
  GetMem(pszLibAAlterFileName, Length(AlterGuest) * 2 + 2);
  StringToWideChar(AlterGuest, pszLibAAlterFileName, Length(AlterGuest) * 2 + 2);

  memSize := (1 + Length(Guest)) * SizeOf(WChar) + (Length(AlterGuest) + 1) * SizeOf(WChar) + SizeOf(lpLibParam) + 100; // 100=Loader大小
  pszLibMem := VirtualAllocEx(procHandle, nil, memSize, MEM_COMMIT or MEM_RESERVE, PAGE_EXECUTE_READWRITE);
  if pszLibMem = nil then
  begin
    FreeMem(pszLibAFilename);
    FreeMem(pszLibAAlterFileName);
    Result := 0;
    Exit;
  end;
  lpLibParam.LibFileName := Pointer(NativeUInt(pszLibMem) + SizeOf(lpLibParam));
  lpLibParam.LibAlterFileName := Pointer(NativeUInt(pszLibMem) + SizeOf(lpLibParam) + (Length(Guest) + 1) * SizeOf(WChar));
  lpLibParam.hfile := 0;
  lpLibParam.dwFlag := LOAD_WITH_ALTERED_SEARCH_PATH;
  lpLibParam.func := GetProcAddress(GetModuleHandle('Kernel32'), 'LoadLibraryExW');
  lpLibParam.exitthread := GetProcAddress(GetModuleHandle('Kernel32'), 'ExitThread');
  TempVar := 0;
  WriteProcessMemory(procHandle, pszLibMem, @lpLibParam, SizeOf(lpLibParam), TempVar);
  WriteProcessMemory(procHandle, Pointer(NativeUInt(pszLibMem) + memSize - 100), @loader, 100, TempVar);

  iReturnCode := WriteProcessMemory(procHandle, lpLibParam.LibFileName, pszLibAFilename, (1 + lstrlenW(pszLibAFilename)) * SizeOf(WChar), TempVar);
  if iReturnCode then
    iReturnCode := WriteProcessMemory(procHandle, lpLibParam.LibAlterFileName, pszLibAAlterFileName, (1 + Length(AlterGuest))
      * SizeOf(WChar), TempVar);
  if iReturnCode then
  begin
    TempVar := 0;
    { 在远程进程中启动dll }
    thrdHandle := CreateRemoteThread(procHandle, nil, 0, Pointer(NativeUInt(pszLibMem) + memSize - 100), pszLibMem, 0, TempDWORD);
    if thrdHandle = 0 then
    begin
      VirtualFreeEx(procHandle, pszLibMem, memSize, MEM_DECOMMIT or MEM_RELEASE);
      FreeMem(pszLibAFilename);
      FreeMem(pszLibAAlterFileName);
      Result := 0;
      Exit;
    end;
    if bKillTimeOut then
      (WaitForSingleObject(thrdHandle, nTimeout));
    // Sleep(100);
    GetExitCodeThread(thrdHandle, Result);
  end;
  { 释放内存空间 }
  // if Result <> 0 then
  if bKillTimeOut and (Result <> STILL_ACTIVE) then
  begin
    VirtualFreeEx(procHandle, pszLibMem, memSize, MEM_DECOMMIT or MEM_RELEASE);
    CloseHandle(thrdHandle);
  end;
  FreeMem(pszLibAFilename);
end;

procedure TWhichFontFather.FormDestroy(Sender: TObject);
begin
  FFontCache.Free;
end;

procedure TWhichFontFather.FormCreate(Sender: TObject);
var
  SysMenu: HMENU;
begin
  SysMenu := GetSystemMenu(Handle, False);
  AppendMenu(SysMenu, MF_SEPARATOR, 0, '');
  AppendMenu(SysMenu, MF_STRING, SC_STAYONTOP, '&Stay on top');
  FFontCache := TDictionary<string, Integer>.Create;
end;

procedure TWhichFontFather.AddOrUpdateFont(info: string);
var
  n: Integer;
begin
  lvFonts.Items.BeginUpdate;
  try
    if FFontCache.ContainsKey(info) then
    begin
      with lvFonts.Items[FFontCache[info]] do
      begin
        n := Integer(SubItems.Objects[0]);
        SubItems.Objects[0] := Pointer(n + 1);
        Caption := Format('%s *%d', [info, n + 1]);
        Selected := True;
      end;
    end
    else
    begin
      with lvFonts.Items.Add do
      begin
        Caption := info;
        SubItems.AddObject('', Pointer(1));
        FFontCache.Add(info, index);
      end;
    end;
  finally
    lvFonts.Items.EndUpdate;
  end;
end;

procedure TWhichFontFather.btn1Click(Sender: TObject);
const
{$IFDEF WIN64}
  MACTYPE_DLL = 'MacType64.dll';
  MACTYPE_CORE_DLL = 'MacType64.Core.dll';
  WHICHFONT_DLL = 'WhichFont64.dll';
{$ELSE}
  MACTYPE_DLL = 'MacType.dll';
  MACTYPE_CORE_DLL = 'MacType.Core.dll';
  WHICHFONT_DLL = 'WhichFont.dll';
{$ENDIF}
begin
  if GetModuleHandle(MACTYPE_DLL) + GetModuleHandle(MACTYPE_CORE_DLL) <> 0 then
  begin
    MessageBox(Handle, 'Please turn off MacType before start tracing', 'Warning', MB_OK or MB_ICONWARNING);
    exit;
  end;
  with TOpenDialog.Create(nil) do
  try
    Filter := 'Excutable|*.exe';
    Options := Options + [ofFileMustExist];
    if Execute then
    begin
      lvFonts.Clear;
      FFontCache.Clear;
      pnl1.Hide;
      LaunchAndHook(FileName, ExtractFilePath(ParamStr(0)) + WHICHFONT_DLL);
      btn1.Hide;
    end;
  finally
    Free;
  end;
end;

procedure TWhichFontFather.CMProcEnd(var Msg: TMessage);
begin
  lvFonts.AddItem('------ Process exited ------', nil);
  pnl1.Show;
end;

procedure TWhichFontFather.LaunchAndHook(szExe, szDll: string);
var
  si: TStartupInfo;
  pi: TProcessInformation;
  dumy: DWORD;
  dumyHandle: THandle;
  bWow64Proc: BOOL;
begin
  if not FileExists(szDll) then
  begin
    MessageBox(Handle, 'WhichFont.dll not found!', nil, MB_OK or MB_ICONERROR);
    Exit;
  end;
  fillchar(si, sizeof(si), 0);
  si.cb := sizeof(si);
  si.wShowWindow := SW_SHOW;
  if CreateProcess(nil, PChar(szExe), nil, nil, False, CREATE_SUSPENDED, nil, nil, si, pi) then
  begin
  {$IFDEF WIN64}
    if IsWow64Process(pi.hProcess, @bWow64Proc) and bWow64Proc then
    begin
      lvFonts.AddItem('---- Use WhichFont.exe for x86 processes ----', nil);
      ResumeThread(pi.hThread);
      CloseHandle(pi.hThread);
      CloseHandle(pi.hProcess);
      pnl1.Show;
      Exit;
    end;
  {$ELSE}
    if IsWow64Process(GetCurrentProcess(), bWow64Proc) and bWow64Proc then // ourself is running in a x64 platform
      if IsWow64Process(pi.hProcess, @bWow64Proc) and (not bWow64Proc) then
      begin
        lvFonts.AddItem('---- Use WhichFont64.exe for x64 processes ----', nil);
        ResumeThread(pi.hThread);
        CloseHandle(pi.hThread);
        CloseHandle(pi.hProcess);
        pnl1.Show;
        Exit;
      end;
  {$ENDIF}

    begin
      CloseHandle(BeginThread(nil, 0, @ProcWaiter, Pointer(pi.hProcess), 0, dumy));
      RemoteInjectTo(szDll, '', pi.hProcess, False, 5000, dumyHandle);
      ResumeThread(pi.hThread);
      CloseHandle(pi.hThread);
    end;
  end;
end;

procedure TWhichFontFather.WMCopyData(var Msg: TWMCopyData);
begin
  if (Msg.CopyDataStruct.dwData = $12344321) and (Msg.CopyDataStruct.lpData <> nil) then // check magic word
  begin
    with PFontInfo(Msg.CopyDataStruct.lpData)^ do
      AddOrUpdateFont(Format('%s [%s]', [FontWanted, FontStyle]));
  end;
end;

procedure TWhichFontFather.WMSysCommand(var Message: TWMSysCommand);
begin
  inherited;
  case Message.CmdType of
    SC_STAYONTOP:
      begin
        if Self.FormStyle = fsStayOnTop then
        begin
          self.FormStyle := fsNormal;
          CheckMenuItem(GetSystemMenu(Handle, False), SC_STAYONTOP, MF_BYCOMMAND or MF_UNCHECKED);
        end
        else
        begin
          self.FormStyle := fsStayOnTop;
          CheckMenuItem(GetSystemMenu(Handle, False), SC_STAYONTOP, MF_BYCOMMAND or MF_CHECKED);
        end;
      end;
  end;
end;

end.

