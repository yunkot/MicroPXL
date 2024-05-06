unit PXL.Displays.SSD1351;
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
  PXL.Types, PXL.Boards.Types, PXL.Displays.Types;

type
  TDisplay = class(TCustomDrivenDisplay)
  public const
    OLED128x128: TPoint = (X: 128; Y: 128);
    OLED128x96: TPoint = (X: 128; Y: 96);
  private
    FScreenSize: TPoint;

    procedure SetWriteWindow(const AWriteRect: TRect);
  protected
    procedure InitSequence; override;
    procedure PresentBuffer(const ARect: TRect); override;

    function ReadPixel(const AX, AY: Integer): TIntColor; override;
    procedure WritePixel(const AX, AY: Integer; const AColor: TIntColor); override;

    function GetScanline(const AIndex: Integer): Pointer; override;
  public
    constructor Create(const AScreenSize: TPoint; const AGPIO: TCustomGPIO;
      const ADataPort: TCustomDataPort; const APinDC: Integer; const APinRST: Integer = -1);

    property ScreenSize: TPoint read FScreenSize;
  end;

implementation

uses
  SysUtils, Math;

const
  CMD_SET_COLUMN = $15;
  CMD_SET_ROW = $75;
  CMD_WRITE_RAM = $5C;
  CMD_SET_REMAP = $A0;
  CMD_START_LINE = $A1;
  CMD_DISPLAY_OFFSET = $A2;
  CMD_NORMAL_DISPLAY = $A6;
  CMD_FUNCTIONSELECT = $AB;
  CMD_DISPLAY_OFF = $AE;
  CMD_DISPLAY_ON = $AF;
  CMD_PRECHARGE = $B1;
  CMD_CLOCK_DIV = $B3;
  CMD_SET_VSL = $B4;
  CMD_SET_GPIO = $B5;
  CMD_PRECHARGE2 = $B6;
  CMD_VCOMH = $BE;
  CMD_CONTRAST_ABC = $C1;
  CMD_CONTRAST_MASTER = $C7;
  CMD_MUX_RATIO = $CA;
  CMD_COMMAND_LOCK = $FD;

constructor TDisplay.Create(const AScreenSize: TPoint; const AGPIO: TCustomGPIO;
  const ADataPort: TCustomDataPort; const APinDC: Integer; const APinRST: Integer);
begin
  FScreenSize := AScreenSize;

  FPhysicalOrientation := TOrientation.Landscape;
  FPhysicalSize := FScreenSize;

  FScreenBufferSize := (FPhysicalSize.X * FPhysicalSize.Y) * SizeOf(Word);
  FScreenBuffer := AllocMem(FScreenBufferSize);

  inherited Create(AGPIO, ADataPort, APinDC, APinRST);
end;

procedure TDisplay.InitSequence;
begin
  WriteCommand(CMD_COMMAND_LOCK);
  WriteData($12);

  WriteCommand(CMD_COMMAND_LOCK);
  WriteData($B1);

  WriteCommand(CMD_DISPLAY_OFF);

  WriteCommand(CMD_CLOCK_DIV);
  WriteCommand($F1);

  WriteCommand(CMD_MUX_RATIO);
  WriteData(127);

  WriteCommand(CMD_SET_REMAP);
  WriteData($74);

  WriteCommand(CMD_SET_COLUMN);
  WriteData([$00, $7F]);

  WriteCommand(CMD_SET_ROW);
  WriteData([$00, $7F]);

  WriteCommand(CMD_START_LINE);

  if FScreenSize.Y = 96 then
    WriteData(96)
  else
    WriteData(0);

  WriteCommand(CMD_DISPLAY_OFFSET);
  WriteData($00);

  WriteCommand(CMD_SET_GPIO);
  WriteData($00);

  WriteCommand(CMD_FUNCTIONSELECT);
  WriteData($01);

  WriteCommand(CMD_PRECHARGE);
  WriteCommand($32);

  WriteCommand(CMD_VCOMH);
  WriteCommand($05);

  WriteCommand(CMD_NORMAL_DISPLAY);

  WriteCommand(CMD_CONTRAST_ABC);
  WriteData([$C8, $80, $C8]);

  WriteCommand(CMD_CONTRAST_MASTER);
  WriteData($0F);

  WriteCommand(CMD_SET_VSL);
  WriteData([$A0, $B5, $55]);

  WriteCommand(CMD_PRECHARGE2);
  WriteData($01);

  WriteCommand(CMD_DISPLAY_ON);
end;

procedure TDisplay.SetWriteWindow(const AWriteRect: TRect);
begin
  WriteCommand(CMD_SET_COLUMN);
  WriteData([AWriteRect.Left, AWriteRect.Right - 1]);

  WriteCommand(CMD_SET_ROW);
  WriteData([AWriteRect.Top, AWriteRect.Bottom - 1]);

  WriteCommand(CMD_WRITE_RAM);

  FGPIO.PinValue[FPinDC] := TPinValue.High;
end;

procedure TDisplay.PresentBuffer(const ARect: TRect);
var
  I, LStartPos, LBytesToCopy: Integer;
begin
  SetWriteWindow(ARect);
  LStartPos := (ARect.Top * FPhysicalSize.X + ARect.Left) * SizeOf(Word);

  if (ARect.Left = 0) and (ARect.Top = 0) and (ARect.Right = FPhysicalSize.X) and
    (ARect.Bottom = FPhysicalSize.Y) then
    for I := 0 to FScreenBufferSize div MaxSPITransferSize do
    begin // Full burst copy.
      LStartPos := I * MaxSPITransferSize;
      LBytesToCopy := Min(FScreenBufferSize - LStartPos, MaxSPITransferSize);

      if LBytesToCopy > 0 then
        FDataPort.Write(Pointer(PtrUInt(FScreenBuffer) + Cardinal(LStartPos)), LBytesToCopy)
      else
        Break;
    end
  else
    for I := 0 to ARect.Height - 1 do
    begin // Copy one scanline at a time.
      LStartPos := ((ARect.Top + I) * FPhysicalSize.X + ARect.Left) * SizeOf(Word);
      LBytesToCopy := ARect.Width * SizeOf(Word);

      FDataPort.Write(Pointer(PtrUInt(FScreenBuffer) + Cardinal(LStartPos)), LBytesToCopy);
    end;
end;

function TDisplay.ReadPixel(const AX, AY: Integer): TIntColor;
var
  LValue: PWord;
  LColor: Word;
begin
  LValue := PWord(PtrUInt(FScreenBuffer) + (Cardinal(AY) * Cardinal(FPhysicalSize.X) + Cardinal(AX)) *
    SizeOf(Word));
  LColor := ((LValue^ and $FF) shl 8) or (LValue^ shr 8);

  Result :=
    ((Cardinal(LColor and $1F) * 255) div 31) or
    (((Cardinal((LColor shr 5) and $3F) * 255) div 63) shl 8) or
    (((Cardinal((LColor shr 11) and $1F) * 255) div 31) shl 16) or
    $FF000000;
end;

procedure TDisplay.WritePixel(const AX, AY: Integer; const AColor: TIntColor);
var
  LValue: Word;
begin
  LValue := ((AColor shr 3) and $1F) or (((AColor shr 10) and $3F) shl 5) or
    (((AColor shr 19) and $1F) shl 11);

  PWord(PtrUInt(FScreenBuffer) + (Cardinal(AY) * Cardinal(FPhysicalSize.X) + Cardinal(AX)) * SizeOf(Word))^ :=
    ((LValue and $FF) shl 8) or (LValue shr 8);
end;

function TDisplay.GetScanline(const AIndex: Integer): Pointer;
begin
  Result := Pointer(PtrUInt(FScreenBuffer) + Cardinal(AIndex) * Cardinal(FPhysicalSize.X) * SizeOf(Word));
end;

end.
