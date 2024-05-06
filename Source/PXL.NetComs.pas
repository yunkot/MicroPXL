unit PXL.NetComs;
(*
 * This file is part of Micro Platform eXtended Library (MicroPXL).
 * Copyright (c) 2015 - 2024 Yuriy Kotsarenko. All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in
 * compliance with the License. You may obtain a copy of the License at
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software distributed under the License is
 * distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and limitations under the License.
 *)
{< Provides communication and multiplayer capabilities by using simple message system based on UDP communication
  protocol. }
interface

{$INCLUDE PXL.Config.inc}
{$IFDEF FPC}
  {$PACKRECORDS C}
{$ENDIF}

uses
{$IFDEF MSWINDOWS}
  {$IFDEF FPC}
    WinSock2,
  {$ELSE}
    WinSock,
  {$ENDIF}
{$ENDIF}

{$IFDEF FPC}
  {$IFDEF UNIX}
    termio, BaseUnix,
  {$ENDIF}

  Sockets,
{$ELSE}
  {$IFDEF POSIX}
    {$DEFINE DELPHI_POSIX}
    {$WARN UNIT_PLATFORM OFF}
    Posix.Errno, Posix.NetinetIn, Posix.Unistd, Posix.SysSocket, Posix.Fcntl,
  {$ENDIF}
{$ENDIF}

  PXL.TypeDef;

type
  // A simple communication component that can transmit and receive messages through UDP protocol over local
  // network and/or Internet.
  TNetCom = class
  private const
    MaximumPacketSize = 8166;
  private type
  {$IFDEF DELPHI_POSIX}
    TSocket = Integer;
    TInAddr = record
      S_addr: Cardinal;
    end;

    TSockAddr = record
      sin_family: Word;
      sin_port: Word;
      sin_addr: TInAddr;
      sin_zero: array[0..7] of Byte;
    end;
  {$ENDIF}

    TPacketMessage = array[0..MaximumPacketSize - 1] of Byte;
  private const
    InvalidSocket = TSocket($FFFFFFFF);
    UnknownIP = '0.0.0.0';
  public type
    // Data reception event. In this event the incoming message should be interpreted and properly handled.
    // After this event executes, memory referenced by provided pointers is lost; therefore, to preserve
    // the message it is necessary to copy it somewhere within this event. Source host and port can be used
    // to identify the receiver and for sending replies.
    // @param(ASender Reference to the class that received the message, usually @link(TNetCom).)
    // @param(AHost Source host that sent the message.)
    // @param(APort Source port through which the message was sent.)
    // @param(AData Pointer to the beginning of message block.)
    // @param(ASize Size of the message block.)
    TReceiveEvent = procedure(const ASender: TObject; const AHost: StdString; const APort: Integer;
      const AData: Pointer; const ASize: Integer) of object;
  private
    FSocket: TSocket;
    FInitialized: Boolean;
    FLocalPort: Integer;
    FBroadcast: Boolean;
    FOnReceive: TReceiveEvent;
    FPacketMessage: TPacketMessage;

    FUpdateRefreshTime: Integer;
    FBytesReceived: Integer;
    FBytesSent: Integer;
    FSentPackets: Integer;
    FReceivedPackets: Integer;
    FBytesPerSec: Integer;
    FBytesTransferred: Integer;
    FLastTickCount: LongWord;

    class var FSessions: Integer;
{$IFDEF MSWINDOWS}
    class var FStringBuf: array[0..511] of AnsiChar;
    class var FSession: TWSAdata;
{$ENDIF}

    procedure IncrementSessions;
    procedure DecrementSessions;

    procedure SetLocalPort(const AValue: Integer);
    procedure SetBroadcast(const AValue: Boolean);
    procedure SetUpdateRefreshTime(const AValue: Integer);

    function GetLocalIP: StdString;
    function CreateSocket(const ABroadcast: Boolean): TSocket;
    procedure DestroySocket(var AHandle: TSocket);
    function BindSocket(const AHandle: TSocket; const ALocalPort: Integer): Boolean;
    function GetSocketPort(const AHandle: TSocket): Integer;
    function SetSocketToNonBlock(const AHandle: TSocket): Boolean;
    function SocketSendData(const AHandle: TSocket; const AData: Pointer; const ADataSize: Integer;
      const ADestHost: StdString; const ADestPort: Integer): Boolean;
    function SocketReceiveData(const AHandle: TSocket; const AData: Pointer; const AMaxDataSize: Integer;
      out ASrcHost: StdString; out ASrcPort: Integer): Integer;

    function HostToInt(const AHost: StdString): LongWord;
    function IntToHost(const AValue: LongWord): StdString;
    function IP4AddrToInt(const AText: StdString): LongWord;

    function InitializeSocket: Boolean;
    procedure FinalizeSocket;
    procedure SocketReceive;
  public
    { @exclude } constructor Create;
    { @exclude } destructor Destroy; override;

    // Initializes the component and begins listening to the given port for incoming messages.
    // @link(LocalPort) should be set before calling this function to set a specific listening port. If
    // @link(LocalPort) remains zero before this call, the listening port will be selected by the system from
    // among available ones and @link(LocalPort) will be updated to reflect this. @True is returned when the
    // operation was successful and @False otherwise.
    function Initialize: Boolean;

    // Finalizes the component and closes the communication link.
    procedure Finalize;

    // Converts text containing host address into the corresponding IP address.
    function ResolveHost(const AHost: StdString): StdString;

    // Converts text containing IP address into the corresponding host string.
    function ResolveIP(const AIPAddress: StdString): StdString;

    // Sends the specified message data block to the destination.
    // @param(Host Destination host or address where the message should be sent. Multicast and broadcast
    //   addresses are accepted, although should be used with care to not saturate the local network.)
    // @param(Port Destination port where the receiver is currently listening at.)
    // @param(Data Pointer to the message data block. The method copies the data to its internal structures,
    //   so it's not necessary to maintain the buffer after this call exits.)
    // @param(Size Size of the message data block.)
    // @returns(@True when the packet was sent successfully and @False when there were errors. It is
    //   important to note that since messages are sent through UDP protocol, @True return value doesn't
    //   necessarily mean that the packet was actually received.)
    function Send(const AHost: StdString; const APort: Integer; const AData: Pointer;
      const ASize: Integer): Boolean;

    // Handles internal communication and receives incoming messages; in addition, internal structures and
    // bandwidth usage are also updated. This method should be called as fast as possible and no less than
    // once per second. During the call to this method, @link(OnReceive) event may occur to notify the
    // reception of messages.
    procedure Update;

    // Resets all statistic parameters related to the current session such as number of packets transmitted,
    // bytes per second among others.
    procedure ResetStatistics;

    // Returns IP address of current machine. If several IP addresses are present, the last address in the
    // list is returned.
    property LocalIP: StdString read GetLocalIP;

    // Indicates whether the component has been properly initialized.
    property Initialized: Boolean read FInitialized;

    // Determines whether the communication should support broadcast and multicast messages. This can be
    // written to only before the component is initialized, but can be read from at any time.
    property Broadcast: Boolean read FBroadcast write SetBroadcast;

    // Local port that is used for listening and transmitting packets. This can be written to only before
    // the component is initialized, but can be read from at any time.
    property LocalPort: Integer read FLocalPort write SetLocalPort;

    // This event occurs when the data has been received. It should always be assigned to interpret any
    // incoming messages.
    property OnReceive: TReceiveEvent read FOnReceive write FOnReceive;

    // Time interval (in milliseconds) to consider for "BytesPerSec" calculation.
    property UpdateRefreshTime: Integer read FUpdateRefreshTime write SetUpdateRefreshTime;

    // Indicates how many bytes were received during the entire session.
    property BytesReceived: Integer read FBytesReceived;

    // Indicates how many bytes were sent during the entire session.
    property BytesSent: Integer read FBytesSent;

    // Indicates how many packets were sent during the entire session.
    property SentPackets: Integer read FSentPackets;

    // Indicates how many packets in total were received during the entire session.
    property ReceivedPackets: Integer read FReceivedPackets;

    // Indicates the current bandwidth usage in bytes per second. In order for this variable to have
    // meaningful values, it is necessary to call @link(Update) method at least once per second.
    property BytesPerSec: Integer read FBytesPerSec;
  end;

implementation

uses
{$IFDEF FPC}
  StrUtils,
{$ENDIF}

  SysUtils, PXL.Timing;

const
  DefaultUpdateRefreshTime = 1000;

  CodeSocketGeneralError = -1;
  CodeSocketWouldBlock =
    {$IFDEF FPC}
      EsockEWOULDBLOCK
    {$ELSE}
      {$IFDEF MSWINDOWS}
        WSAEWOULDBLOCK
      {$ELSE}
        EWOULDBLOCK
      {$ENDIF}
    {$ENDIF};

constructor TNetCom.Create;
begin
  inherited;

  IncrementSessions;

  FSocket := InvalidSocket;
  FUpdateRefreshTime := DefaultUpdateRefreshTime;
end;

destructor TNetCom.Destroy;
begin
  if FInitialized then
    Finalize;

  DecrementSessions;

  inherited;
end;

procedure TNetCom.IncrementSessions;
begin
{$IFDEF MSWINDOWS}
  if FSessions <= 0 then
  begin
    if WSAStartup($101, FSession) = 0 then
      Inc(FSessions);

    Exit;
  end;
{$ENDIF}

  Inc(FSessions);
end;

procedure TNetCom.DecrementSessions;
begin
{$IFDEF MSWINDOWS}
  if FSessions = 1 then
  begin
    WSACleanup;
    FillChar(FSession, SizeOf(TWSAdata), 0);
  end;
{$ENDIF}

  if FSessions > 0 then
    Dec(FSessions);
end;

procedure TNetCom.SetLocalPort(const AValue: Integer);
begin
  if not FInitialized then
  begin
    FLocalPort := AValue;

    if FLocalPort < 0 then
      FLocalPort := 0
    else if FLocalPort > 65535 then
      FLocalPort := 65535;
  end;
end;

procedure TNetCom.SetBroadcast(const AValue: Boolean);
begin
  if not FInitialized then
    FBroadcast := AValue;
end;

procedure TNetCom.SetUpdateRefreshTime(const AValue: Integer);
begin
  FUpdateRefreshTime := AValue;

  if FUpdateRefreshTime <= 0 then
    FUpdateRefreshTime := 1;
end;

function TNetCom.GetLocalIP: StdString;
const
  DefaultIP = '127.0.0.1';
{$IFDEF MSWINDOWS}
type
  PInAddrs = ^TInAddrs;
  TInAddrs = array [Word] of PInAddr;
var
  LHostEnt: PHostEnt;
  LInAddp: PInAddrs;
{$ENDIF}
begin
  if FSessions <= 0 then
    Exit(DefaultIP);

{$IFDEF MSWINDOWS}
  GetHostName(FStringBuf, SizeOf(FStringBuf));

  LHostEnt := GetHostByName(FStringBuf);
  if LHostEnt = nil then
    Exit;

  LInAddp := Pointer(LHostEnt.h_addr_list);

  if LInAddp[0] <> nil then
    Result := IntToHost(LInAddp[0].S_addr);
{$ELSE}
  Result := DefaultIP;
{$ENDIF}
end;

function TNetCom.CreateSocket(const ABroadcast: Boolean): TSocket;
var
  LSocketOption: LongWord;
begin
{$IFDEF FPC}
  Result := fpSocket(PF_INET, SOCK_DGRAM, IPPROTO_UDP);
{$ELSE}
  Result := Socket(PF_INET, SOCK_DGRAM, IPPROTO_UDP);
{$ENDIF}

  if (Result <> InvalidSocket) and ABroadcast then
  begin
    LSocketOption := Ord(True);

{$IFDEF FPC}
    fpSetSockOpt(Result, SOL_SOCKET, SO_BROADCAST, @LSocketOption, SizeOf(LSocketOption));
{$ELSE}
  {$IFDEF DELPHI_POSIX}
    SetSockOpt(Result, SOL_SOCKET, SO_BROADCAST, LSocketOption, SizeOf(LSocketOption));
  {$ELSE}
    SetSockOpt(Result, SOL_SOCKET, SO_BROADCAST, @LSocketOption, SizeOf(LSocketOption));
  {$ENDIF}
{$ENDIF}
  end;
end;

procedure TNetCom.DestroySocket(var AHandle: TSocket);
begin
  if AHandle <> InvalidSocket then
  begin
{$IFDEF DELPHI_POSIX}
    __close(AHandle);
{$ELSE}
    CloseSocket(AHandle);
{$ENDIF}
    AHandle := InvalidSocket;
  end;
end;

function TNetCom.BindSocket(const AHandle: TSocket; const ALocalPort: Integer): Boolean;
var
  LTempAddr: TSockAddr;
begin
  FillChar(LTempAddr, SizeOf(TSockAddr), 0);

  LTempAddr.sin_port := ALocalPort;
  LTempAddr.sin_family := AF_INET;

{$IFDEF FPC}
  Result := fpBind(AHandle, @LTempAddr, SizeOf(TSockAddr)) = 0;
{$ELSE}
  {$IFDEF DELPHI_POSIX}
    Result := Bind(AHandle, sockaddr(LTempAddr), SizeOf(TSockAddr)) = 0;
  {$ELSE}
    Result := Bind(AHandle, LTempAddr, SizeOf(TSockAddr)) = 0;
  {$ENDIF}
{$ENDIF}
end;

function TNetCom.GetSocketPort(const AHandle: TSocket): Integer;
var
  LTempAddr: TSockAddr;
  LSocketOption: {$IFDEF DELPHI_POSIX}Cardinal{$ELSE}LongWord{$ENDIF};
begin
  FillChar(LTempAddr, SizeOf(TSockAddr), 0);
  LSocketOption := SizeOf(LTempAddr);

{$IFDEF FPC}
  fpGetSockName(AHandle, @LTempAddr, @LSocketOption);
{$ELSE}
  {$IFDEF DELPHI_POSIX}
    GetSockName(AHandle, sockaddr(LTempAddr), LSocketOption);
  {$ELSE}
    GetSockName(AHandle, LTempAddr, Integer(LSocketOption));
  {$ENDIF}
{$ENDIF}

  Result := LTempAddr.sin_port;
end;

function TNetCom.SetSocketToNonBlock(const AHandle: TSocket): Boolean;
{$IFNDEF DELPHI_POSIX}
var
  LSocketOption: LongWord;
{$ENDIF}
begin
{$IFNDEF DELPHI_POSIX}
  LSocketOption := Cardinal(True);
{$ENDIF}

{$IFDEF MSWINDOWS}
  {$IFDEF FPC}
    Result := ioctlsocket(AHandle, FIONBIO, @LSocketOption) = 0;
  {$ELSE}
    Result := ioctlsocket(AHandle, FIONBIO, Integer(LSocketOption)) = 0;
  {$ENDIF}
{$ENDIF}

{$IFDEF FPC}
  {$IFDEF UNIX}
    Result := fpioctl(AHandle, FIONBIO, @LSocketOption) = 0;
  {$ENDIF}
{$ENDIF}

{$IFDEF DELPHI_POSIX}
  Result := fcntl(AHandle, F_SETFL, O_NONBLOCK) <> -1;
{$ENDIF}
end;

function TNetCom.SocketSendData(const AHandle: TSocket; const AData: Pointer; const ADataSize: Integer;
  const ADestHost: StdString; const ADestPort: Integer): Boolean;
var
  LTempAddr: TSockAddr;
  LRes: Integer;
begin
  FillChar(LTempAddr, SizeOf(TSockAddr), 0);

  LTempAddr.sin_addr.S_addr := HostToInt(ADestHost);
  if Integer(LTempAddr.sin_addr.S_addr) = 0 then
    Exit(False);

  LTempAddr.sin_family := AF_INET;
  LTempAddr.sin_port := ADestPort;

{$IFDEF FPC}
  LRes := fpSendTo(AHandle, AData, ADataSize, 0, @LTempAddr, SizeOf(TSockAddr));
{$ELSE}
  {$IFDEF DELPHI_POSIX}
    LRes := SendTo(AHandle, AData^, ADataSize, 0, sockaddr(LTempAddr), SizeOf(TSockAddr));
  {$ELSE}
    LRes := SendTo(AHandle, AData^, ADataSize, 0, LTempAddr, SizeOf(TSockAddr));
  {$ENDIF}
{$ENDIF}

  Result := (LRes > 0) and (LRes = ADataSize);
end;

function TNetCom.SocketReceiveData(const AHandle: TSocket; const AData: Pointer; const AMaxDataSize: Integer;
  out ASrcHost: StdString; out ASrcPort: Integer): Integer;
var
  LSocketOption: {$IFDEF DELPHI_POSIX}Cardinal{$ELSE}LongWord{$ENDIF};
  LTempAddr: TSockAddr;
begin
  LSocketOption := SizeOf(TSockAddr);
  FillChar(LTempAddr, SizeOf(TSockAddr), 0);

{$IFDEF FPC}
  Result := fpRecvFrom(AHandle, AData, AMaxDataSize, 0, @LTempAddr, @LSocketOption);
{$ELSE}
  {$IFDEF DELPHI_POSIX}
    Result := RecvFrom(AHandle, AData^, AMaxDataSize, 0, sockaddr(LTempAddr), LSocketOption);
  {$ELSE}
    Result := RecvFrom(AHandle, AData^, AMaxDataSize, 0, LTempAddr, Integer(LSocketOption));
  {$ENDIF}
{$ENDIF}

  if (Result = CodeSocketGeneralError) or (Result = CodeSocketWouldBlock) or (Result <= 0) then
    Exit(0);

  ASrcPort := LTempAddr.sin_port;
  ASrcHost := IntToHost(LTempAddr.sin_addr.S_addr);
end;

function TNetCom.IntToHost(const AValue: LongWord): StdString;
begin
  Result := IntToStr(PByte(@AValue)^) + '.' + IntToStr(PByte(PtrUInt(@AValue) + 1)^) + '.' +
    IntToStr(PByte(PtrUInt(@AValue) + 2)^) + '.' + IntToStr(PByte(PtrUInt(@AValue) + 3)^);
end;

function TNetCom.IP4AddrToInt(const AText: StdString): LongWord;
var
  I, LDotAt, LNextStartAt, LValue: Integer;
  LNumText: StdString;
begin
  Result := 0;
  LNextStartAt := 1;

  for I := 0 to 3 do
  begin
    if I < 3 then
    begin
    {$IFDEF FPC}
      LDotAt := PosEx('.', AText, LNextStartAt);
    {$ELSE}
      LDotAt := Pos('.', AText, LNextStartAt);
    {$ENDIF}
      if LDotAt = 0 then
        Exit;

      LNumText := Copy(AText, LNextStartAt, LDotAt - LNextStartAt);
      LNextStartAt := LDotAt + 1;
    end
    else
      LNumText := Copy(AText, LNextStartAt, (Length(AText) - LNextStartAt) + 1);

    LValue := StrToIntDef(LNumText, -1);
    if (LValue < 0) or (LValue > 255) then
      Exit;

    PByte(PtrUInt(@Result) + Cardinal(I))^ := LValue;
  end;
end;

function TNetCom.HostToInt(const AHost: StdString): LongWord;
{$IFDEF MSWINDOWS}
var
  LHostEnt: PHostEnt;
{$ENDIF}
begin
  Result := IP4AddrToInt(AHost);

{$IFDEF MSWINDOWS}
  if Result = 0 then
  begin
    StrPCopy(@FStringBuf, AHost);

    LHostEnt := GetHostByName(FStringBuf);
    if LHostEnt = nil then
      Exit;

    Result := PLongWord(LHostEnt.h_addr_list^)^;
  end;
{$ENDIF}
end;

function TNetCom.ResolveHost(const AHost: StdString): StdString;
var
  LAddress: LongWord;
begin
  if FSessions <= 0 then
    Exit(UnknownIP);

  LAddress := HostToInt(AHost);
  Result := IntToHost(LAddress);
end;

function TNetCom.ResolveIP(const AIPAddress: StdString): StdString;
{$IFDEF MSWINDOWS}
var
  LHostEnt: PHostEnt;
  LAddress: LongWord;
{$ENDIF}
begin
{$IFDEF MSWINDOWS}
  if FSessions <= 0 then
    Exit(UnknownIP);

  LAddress := HostToInt(AIPAddress);
  LHostEnt := GetHostByAddr(@LAddress, 4, AF_INET);

  if LHostEnt <> nil then
    Result := StdString(LHostEnt.h_name)
  else
    Result := UnknownIP;
{$ELSE}
  Result := UnknownIP;
{$ENDIF}
end;

function TNetCom.InitializeSocket: Boolean;
begin
  FSocket := CreateSocket(FBroadcast);
  if FSocket = InvalidSocket then
    Exit(False);

  if not BindSocket(FSocket, FLocalPort) then
  begin
    DestroySocket(FSocket);
    Exit(False);
  end;

  FLocalPort := GetSocketPort(FSocket);

  if not SetSocketToNonBlock(FSocket) then
  begin
    DestroySocket(FSocket);
    Exit(False);
  end;

  Result := True;
end;

procedure TNetCom.FinalizeSocket;
begin
  DestroySocket(FSocket);
end;

procedure TNetCom.ResetStatistics;
begin
  FBytesReceived := 0;
  FBytesSent := 0;
  FSentPackets := 0;
  FReceivedPackets := 0;
  FBytesPerSec := 0;
  FBytesTransferred := 0;
end;

function TNetCom.Initialize: Boolean;
begin
  if FSessions <= 0 then
    Exit(False);

  if FInitialized then
    Exit(False);

  if not InitializeSocket then
    Exit(False);

  ResetStatistics;

  FInitialized := True;
  FLastTickCount := GetSystemTickCount;

  Result := True;
end;

procedure TNetCom.Finalize;
begin
  if FInitialized then
  begin
    FinalizeSocket;
    FInitialized := False;
  end;
end;

function TNetCom.Send(const AHost: StdString; const APort: Integer; const AData: Pointer;
  const ASize: Integer): Boolean;
begin
  if (not FInitialized) or (Length(AHost) <= 0) or (AData = nil) or (ASize <= 0) then
    Exit(False);

  Result := SocketSendData(FSocket, AData, ASize, AHost, APort);
  if Result then
  begin
    Inc(FSentPackets);
    Inc(FBytesSent, ASize);
    Inc(FBytesTransferred, ASize);
  end;
end;

procedure TNetCom.SocketReceive;
var
  LReceivedBytes, LFromPort: Integer;
  LFromHost: StdString;
begin
  LReceivedBytes := SocketReceiveData(FSocket, @FPacketMessage[0], MaximumPacketSize, LFromHost, LFromPort);
  if LReceivedBytes < 1 then
    Exit;

  Inc(FReceivedPackets);
  Inc(FBytesReceived, LReceivedBytes);
  Inc(FBytesTransferred, LReceivedBytes);

  if Assigned(FOnReceive) then
    FOnReceive(Self, LFromHost, LFromPort, @FPacketMessage, LReceivedBytes);
end;

procedure TNetCom.Update;
var
  LNowTickCount, LElapsedTime: LongWord;
begin
  LNowTickCount := GetSystemTickCount;
  LElapsedTime := Abs(LNowTickCount - FLastTickCount);

  if LElapsedTime > Cardinal(FUpdateRefreshTime) then
  begin
    FLastTickCount := LNowTickCount;

    FBytesPerSec := (Int64(FBytesTransferred) * 1000) div LElapsedTime;
    FBytesTransferred := 0;
  end;

  if FInitialized then
    SocketReceive;
end;

initialization
  TNetCom.FSessions := 0;

end.
