unit PXL.Displays.HX8357;
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
  Types, PXL.Types, PXL.Boards.Types, PXL.Displays.Types;

type
  TDisplay = class(TCustomDrivenDisplay)
  private type
    PScreenColor = ^TScreenColor;
    TScreenColor = packed record
      Red: Byte;
      Green: Byte;
      Blue: Byte;
    end;
  private
    procedure SetWriteWindow(const AWriteRect: TRect);
  protected
    procedure InitSequence; override;
    procedure PresentBuffer(const ARect: TRect); override;

    function ReadPixel(const AX, AY: Integer): TIntColor; override;
    procedure WritePixel(const AX, AY: Integer; const AColor: TIntColor); override;

    function GetScanline(const AIndex: Integer): Pointer; override;
  public
    constructor Create(const AGPIO: TCustomGPIO; const ADataPort: TCustomDataPort;
      const APinDC: Integer; const APinRST: Integer = -1);
  end;

implementation

uses
  SysUtils, Math;

const
  CMD_COLUMN_ADDR_SET = $2A;
  CMD_DISPLAY_ON = $29;
  CMD_ENABLE_EXT = $B9;
  CMD_MEM_WRITE = $2C;
  CMD_PAGE_ADDR_SET = $2B;
  CMD_SET_ACCESS_CTRL = $36;
  CMD_SET_DISPLAY_CYCLE = $B4;
  CMD_SET_GAMMA_CURVE = $E0;
  CMD_SET_INT_OSC = $B0;
  CMD_SET_PANEL_CHR = $CC;
  CMD_SET_PIXEL_FORMAT = $3A;
  CMD_SET_POWER_CTRL = $B1;
  CMD_SET_RGB_INTFC = $B3;
  CMD_SET_STBA = $C0;
  CMD_SET_TEARING_FX = $35;
  CMD_SET_TEAR_SCANLINE = $44;
  CMD_SET_VCOM_VOLTAGE = $B6;
  CMD_SLEEP_OUT = $11;
  CMD_SW_RESET = $01;

constructor TDisplay.Create(const AGPIO: TCustomGPIO; const ADataPort: TCustomDataPort; const APinDC,
  APinRST: Integer);
begin
  FPhysicalOrientation := TOrientation.InversePortrait;
  FPhysicalSize := Point(320, 480);

  FScreenBufferSize := (FPhysicalSize.X * FPhysicalSize.Y) * SizeOf(TScreenColor);
  FScreenBuffer := AllocMem(FScreenBufferSize);

  inherited Create(AGPIO, ADataPort, APinDC, APinRST);
end;

procedure TDisplay.InitSequence;
begin
  WriteCommand(CMD_SW_RESET);
  Sleep(5);

  WriteCommand(CMD_ENABLE_EXT);
  WriteData([$FF, $83, $57]);

  WriteCommand(CMD_SET_RGB_INTFC);
  WriteData([$80, $00, $06, $06]);

  WriteCommand(CMD_SET_VCOM_VOLTAGE);
  WriteData($25);

  WriteCommand(CMD_SET_INT_OSC);
  WriteData($68);

  WriteCommand(CMD_SET_PANEL_CHR);
  WriteData($05);

  WriteCommand(CMD_SET_POWER_CTRL);
  WriteData([$00, $15, $1C, $1C, $83, $AA]);

  WriteCommand(CMD_SET_STBA);
  WriteData([$50, $50, $01, $3C, $1E, $08]);

  WriteCommand(CMD_SET_DISPLAY_CYCLE);
  WriteData([$02, $40, $00, $2A, $2A, $0D, $78]);

  WriteCommand(CMD_SET_GAMMA_CURVE);
  WriteData([$02, $0A, $11, $1D, $23, $35, $41, $4B, $4B, $42, $3A, $27, $1B, $08, $09, $03, $02, $0A, $11, $1D, $23,
    $35, $41, $4B, $4B, $42, $3A, $27, $1B, $08, $09, $03, $00, $01]);

  WriteCommand(CMD_SET_PIXEL_FORMAT);
  WriteData($FF);  // $55 for 16-bit

  WriteCommand(CMD_SET_ACCESS_CTRL);
  WriteData($88); // defines RGB/BGR and horizontal/vertical memory direction.

  WriteCommand(CMD_SET_TEARING_FX);
  WriteData($00);

  WriteCommand(CMD_SET_TEAR_SCANLINE);
  WriteData([$00, $02]);

  WriteCommand(CMD_SLEEP_OUT);
  Sleep(5);

  WriteCommand(CMD_DISPLAY_ON);
end;

procedure TDisplay.SetWriteWindow(const AWriteRect: TRect);
begin
  WriteCommand(CMD_COLUMN_ADDR_SET);
  WriteData([Cardinal(AWriteRect.Left) shr 8, Cardinal(AWriteRect.Left) and $FF,
    Cardinal(AWriteRect.Right - 1) shr 8, Cardinal(AWriteRect.Right - 1) and $FF]);

  WriteCommand(CMD_PAGE_ADDR_SET);
  WriteData([Cardinal(AWriteRect.Top) shr 8, Cardinal(AWriteRect.Top) and $FF,
    Cardinal(AWriteRect.Bottom - 1) shr 8, Cardinal(AWriteRect.Bottom - 1) and $FF]);

  WriteCommand(CMD_MEM_WRITE);

  FGPIO.PinValue[FPinDC] := TPinValue.High;
end;

procedure TDisplay.PresentBuffer(const ARect: TRect);
var
  I, LStartPos, LBytesToCopy, LBytesTotal: Integer;
begin
  SetWriteWindow(ARect);

  LBytesTotal := ARect.Width * ARect.Height * SizeOf(TScreenColor);
  LStartPos := (ARect.Top * FPhysicalSize.X + ARect.Left) * SizeOf(TScreenColor);

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
      LStartPos := ((ARect.Top + I) * FPhysicalSize.X + ARect.Left) * SizeOf(TScreenColor);
      LBytesToCopy := ARect.Width * SizeOf(TScreenColor);

      FDataPort.Write(Pointer(PtrUInt(FScreenBuffer) + Cardinal(LStartPos)), LBytesToCopy);
    end;
end;

function TDisplay.ReadPixel(const AX, AY: Integer): TIntColor;
var
  LSrcColor: PScreenColor;
begin
  LSrcColor := Pointer(PtrUInt(FScreenBuffer) + (Cardinal(AY) * Cardinal(FPhysicalSize.X) + Cardinal(AX)) *
    SizeOf(TScreenColor));

  Result := IntColorRGB(LSrcColor.Red, LSrcColor.Green, LSrcColor.Blue);
end;

procedure TDisplay.WritePixel(const AX, AY: Integer; const AColor: TIntColor);
var
  LDestColor: PScreenColor;
begin
  LDestColor := Pointer(PtrUInt(FScreenBuffer) + (Cardinal(AY) * Cardinal(FPhysicalSize.X) + Cardinal(AX)) *
    SizeOf(TScreenColor));

  LDestColor.Red := AColor and $FF;
  LDestColor.Green := (AColor shr 8) and $FF;
  LDestColor.Blue := (AColor shr 16) and $FF;
end;

function TDisplay.GetScanline(const AIndex: Integer): Pointer;
begin
  if (AIndex >= 0) and (AIndex < FPhysicalSize.Y) then
    Result := Pointer(PtrUInt(FScreenBuffer) + Cardinal(AIndex) * Cardinal(FPhysicalSize.X) *
      SizeOf(TScreenColor))
  else
    Result := nil;
end;

end.
