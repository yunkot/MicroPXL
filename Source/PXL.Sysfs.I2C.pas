unit PXL.Sysfs.I2C;
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
interface

{$INCLUDE PXL.Config.inc}

uses
  PXL.TypeDef, PXL.Boards.Types, PXL.Sysfs.Types;

type
  TSysfsI2C = class(TCustomPortI2C)
  private
    FSystemPath: StdString;
    FHandle: TUntypedHandle;
    FCurrentAddress: Cardinal;
  public
    constructor Create(const ASystemPath: StdString);
    destructor Destroy; override;

    procedure SetAddress(const AAddress: Cardinal); override;

    function Read(const ABuffer: Pointer; const ABufferSize: Cardinal): Cardinal; override;
    function Write(const ABuffer: Pointer; const ABufferSize: Cardinal): Cardinal; override;

    function ReadByte(out AValue: Byte): Boolean; override;
    function WriteByte(const AValue: Byte): Boolean; override;

    function WriteQuick(const AValue: Byte): Boolean;

    function ReadByteData(const ACommand: Byte; out AValue: Byte): Boolean; override;
    function WriteByteData(const ACommand, AValue: Byte): Boolean; override;

    function ReadWordData(const ACommand: Byte; out AValue: Word): Boolean; override;
    function WriteWordData(const ACommand: Byte; const AValue: Word): Boolean; override;

    function ReadBlockData(const ACommand: Byte; const ABuffer: Pointer;
      const ABufferSize: Cardinal): Cardinal; override;
    function WriteBlockData(const ACommand: Byte; const ABuffer: Pointer;
      const ABufferSize: Cardinal): Cardinal; override;

    function ProcessCall(const ACommand: Byte; var AValue: Word): Boolean;
    function ProcessBlockCall(const ACommand: Byte; const ABuffer: Pointer;
      const ABufferSize: Cardinal): Cardinal;

    property SystemPath: StdString read FSystemPath;
    property Handle: TUntypedHandle read FHandle;
  end;

  ESysfsI2COpen = class(ESysfsFileOpen);
  ESysfsI2CAddress = class(ESysfsGeneric);
  ESysfsI2CBusWrite = class(ESysfsFileWrite);
  ESysfsI2CBusRead = class(ESysfsFileRead);
  ESysfsI2CBusProcess = class(ESysfsFileRead);

resourcestring
  SCannotOpenFileForI2C = 'Cannot open I2C file <%s> for reading and writing.';
  SCannotSetI2CSlaveAddress = 'Cannot set <0x%x> slave address for I2C bus.';
  SErrorReadI2CRawBytes = 'Error reading <%d> raw byte(s) from I2C bus.';
  SErrorWriteI2CRawBytes = 'Error writing <%d> raw byte(s) to I2C bus.';
  SErrorReadI2CDataBytes = 'Error reading <%d> data byte(s) from I2C bus.';
  SErrorWriteI2CDataBytes = 'Error writing <%d> data byte(s) to I2C bus.';
  SErrorReadI2CDataBlock = 'Error reading data block from I2C bus.';
  SErrorProcessI2CDataBytes = 'Error processing <%d> data byte(s) with I2C bus.';

implementation

uses
  SysUtils, BaseUnix, PXL.Sysfs.Buses;

constructor TSysfsI2C.Create(const ASystemPath: StdString);
begin
  inherited Create;

  FSystemPath := ASystemPath;
  FCurrentAddress := High(Cardinal);

  FHandle := fpopen(FSystemPath, O_RDWR);
  if FHandle < 0 then
  begin
    FHandle := 0;
    raise ESysfsI2COpen.Create(Format(SCannotOpenFileForI2C, [FSystemPath]));
  end;
end;

destructor TSysfsI2C.Destroy;
begin
  if FHandle <> 0 then
  begin
    fpclose(FHandle);
    FHandle := 0;
  end;

  inherited;
end;

procedure TSysfsI2C.SetAddress(const AAddress: Cardinal);
begin
  if FCurrentAddress <> AAddress then
  begin
    FCurrentAddress := AAddress;

    if FCurrentAddress <> High(Cardinal) then
      if fpioctl(FHandle, I2C_SLAVE, Pointer(FCurrentAddress)) < 0 then
        raise ESysfsI2CAddress.Create(Format(SCannotSetI2CSlaveAddress, [FCurrentAddress]));
  end;
end;

function TSysfsI2C.Read(const ABuffer: Pointer; const ABufferSize: Cardinal): Cardinal;
var
  LBytesRead: Integer;
begin
  if (ABuffer = nil) or (ABufferSize <= 0) then
    raise ESysfsInvalidParams.Create(SInvalidParameters);

  LBytesRead := fpread(FHandle, ABuffer^, ABufferSize);
  if LBytesRead < 0 then
    raise ESysfsI2CBusRead.Create(Format(SErrorReadI2CRawBytes, [ABufferSize]));

  Result := Cardinal(LBytesRead);
end;

function TSysfsI2C.Write(const ABuffer: Pointer; const ABufferSize: Cardinal): Cardinal;
var
  LBytesWritten: Integer;
begin
  if (ABuffer = nil) or (ABufferSize <= 0) then
    raise ESysfsInvalidParams.Create(SInvalidParameters);

  LBytesWritten := fpwrite(FHandle, ABuffer^, ABufferSize);
  if LBytesWritten < 0 then
    raise ESysfsI2CBusWrite.Create(Format(SErrorWriteI2CRawBytes, [ABufferSize]));

  Result := Cardinal(LBytesWritten);
end;

function TSysfsI2C.ReadByte(out AValue: Byte): Boolean;
var
  LRes: Integer;
begin
  LRes := i2c_smbus_read_byte(FHandle);
  if LRes < 0 then
    raise ESysfsI2CBusRead.Create(Format(SErrorReadI2CRawBytes, [SizeOf(Byte)]));

  Result := LRes >= 0;
  if Result then
    AValue := LRes;
end;

function TSysfsI2C.WriteByte(const AValue: Byte): Boolean;
var
  LRes: Integer;
begin
  LRes := i2c_smbus_write_byte(FHandle, AValue);
  if LRes < 0 then
    raise ESysfsI2CBusWrite.Create(Format(SErrorWriteI2CRawBytes, [SizeOf(Byte)]));

  Result := LRes >= 0;
end;

function TSysfsI2C.WriteQuick(const AValue: Byte): Boolean;
var
  LRes: Integer;
begin
  LRes := i2c_smbus_write_quick(FHandle, AValue);
  if LRes < 0 then
    raise ESysfsI2CBusWrite.Create(Format(SErrorWriteI2CRawBytes, [SizeOf(Byte)]));

  Result := LRes >= 0;
end;

function TSysfsI2C.ReadByteData(const ACommand: Byte; out AValue: Byte): Boolean;
var
  LRes: Integer;
begin
  LRes := i2c_smbus_read_byte_data(FHandle, ACommand);
  if LRes < 0 then
    raise ESysfsI2CBusRead.Create(Format(SErrorReadI2CDataBytes, [SizeOf(Byte)]));

  Result := LRes >= 0;
  if Result then
    AValue := LRes;
end;

function TSysfsI2C.WriteByteData(const ACommand, AValue: Byte): Boolean;
var
  LRes: Integer;
begin
  LRes := i2c_smbus_write_byte_data(FHandle, ACommand, AValue);
  if LRes < 0 then
    raise ESysfsI2CBusWrite.Create(Format(SErrorWriteI2CDataBytes, [SizeOf(Byte)]));

  Result := LRes >= 0;
end;

function TSysfsI2C.ReadWordData(const ACommand: Byte; out AValue: Word): Boolean;
var
  LRes: Integer;
begin
  LRes := i2c_smbus_read_word_data(FHandle, ACommand);
  if LRes < 0 then
    raise ESysfsI2CBusRead.Create(Format(SErrorReadI2CDataBytes, [SizeOf(Word)]));

  Result := LRes >= SizeOf(Word);
  if Result then
    AValue := LRes;
end;

function TSysfsI2C.WriteWordData(const ACommand: Byte; const AValue: Word): Boolean;
var
  LRes: Integer;
begin
  LRes := i2c_smbus_write_word_data(FHandle, ACommand, AValue);
  if LRes < 0 then
    raise ESysfsI2CBusWrite.Create(Format(SErrorWriteI2CDataBytes, [SizeOf(Word)]));

  Result := LRes >= SizeOf(Word);
end;

function TSysfsI2C.ReadBlockData(const ACommand: Byte; const ABuffer: Pointer;
  const ABufferSize: Cardinal): Cardinal;
var
  LTempBuf: Pointer;
  LRes: Integer;
begin
  if (ABuffer = nil) or (ABufferSize <= 0) then
    raise ESysfsInvalidParams.Create(SInvalidParameters);

  if ABufferSize < I2C_SMBUS_BLOCK_MAX then
  begin
    GetMem(LTempBuf, I2C_SMBUS_BLOCK_MAX);
    try
      LRes := i2c_smbus_read_block_data(FHandle, ACommand, LTempBuf);
      if LRes < 0 then
        raise ESysfsI2CBusRead.Create(SErrorReadI2CDataBlock);

      if Cardinal(LRes) > ABufferSize then
        Cardinal(LRes) := ABufferSize;

      Move(LTempBuf^, ABuffer^, LRes);
    finally
      FreeMem(LTempBuf);
    end;
  end
  else
  begin
    LRes := i2c_smbus_read_block_data(FHandle, ACommand, ABuffer);
    if LRes < 0 then
      raise ESysfsI2CBusRead.Create(SErrorReadI2CDataBlock);
  end;

  Result := Cardinal(LRes);
end;

function TSysfsI2C.WriteBlockData(const ACommand: Byte; const ABuffer: Pointer;
  const ABufferSize: Cardinal): Cardinal;
var
  LRes: Integer;
begin
  if (ABuffer = nil) or (ABufferSize <= 0) then
    raise ESysfsInvalidParams.Create(SInvalidParameters);

  LRes := i2c_smbus_write_i2c_block_data(FHandle, ACommand, ABufferSize, ABuffer);
  if LRes < 0 then
    raise ESysfsI2CBusWrite.Create(Format(SErrorWriteI2CDataBytes, [ABufferSize]));

  Result := Cardinal(LRes);
end;

function TSysfsI2C.ProcessCall(const ACommand: Byte; var AValue: Word): Boolean;
var
  LRes: Integer;
begin
  LRes := i2c_smbus_process_call(FHandle, ACommand, AValue);
  if LRes < 0 then
    raise ESysfsI2CBusProcess.Create(Format(SErrorProcessI2CDataBytes, [SizeOf(Word)]));

  Result := LRes > 0;
  if Result then
    AValue := LRes;
end;

function TSysfsI2C.ProcessBlockCall(const ACommand: Byte; const ABuffer: Pointer;
  const ABufferSize: Cardinal): Cardinal;
var
  LTempBuf: Pointer;
  LRes: Integer;
begin
  if (ABuffer = nil) or (ABufferSize <= 0) then
    raise ESysfsInvalidParams.Create(SInvalidParameters);

  if ABufferSize < I2C_SMBUS_BLOCK_MAX then
  begin
    GetMem(LTempBuf, I2C_SMBUS_BLOCK_MAX);
    try
      Move(ABuffer^, LTempBuf, ABufferSize);

      LRes := i2c_smbus_block_process_call(FHandle, ACommand, ABufferSize, LTempBuf);
      if LRes < 0 then
        raise ESysfsI2CBusProcess.Create(Format(SErrorProcessI2CDataBytes, [ABufferSize]));

      if Cardinal(LRes) > ABufferSize then
        Cardinal(LRes) := ABufferSize;

      Move(LTempBuf^, ABuffer^, LRes);
    finally
      FreeMem(LTempBuf);
    end;
  end
  else
  begin
    LRes := i2c_smbus_block_process_call(FHandle, ACommand, ABufferSize, ABuffer);
    if LRes < 0 then
      raise ESysfsI2CBusProcess.Create(Format(SErrorProcessI2CDataBytes, [ABufferSize]));
  end;

  Result := Cardinal(LRes);
end;

end.
