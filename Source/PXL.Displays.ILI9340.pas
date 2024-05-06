unit PXL.Displays.ILI9340;
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
    constructor Create(const AGPIO: TCustomGPIO; const ADataPort: TCustomDataPort; const APinDC: Integer;
      const APinRST: Integer = -1);
  end;

implementation

uses
  SysUtils, Math;

const
  CMD_COLUMN_ADDR_SET = $2A;
  CMD_DISPLAY_FUNCTION_CTRL = $B6;
  CMD_DISPLAY_ON = $29;
  CMD_FRAME_RATE_CTRL = $B1;
  CMD_GAMMA_SET = $26;
  CMD_MEM_ACCESS_CTRL = $36;
  CMD_MEM_WRITE = $2C;
  CMD_NEG_GAMMA_CORRECT = $E1;
  CMD_PAGE_ADDR_SET = $2B;
  CMD_POS_GAMMA_CORRECT = $E0;
  CMD_POWER_CTRL_1 = $C0;
  CMD_POWER_CTRL_2 = $C1;
  CMD_SET_PIXEL_FORMAT = $3A;
  CMD_SLEEP_OUT = $11;
  CMD_SW_RESET = $01;
  CMD_VCOM_CTRL_1 = $C5;
  CMD_VCOM_CTRL_2 = $C7;

constructor TDisplay.Create(const AGPIO: TCustomGPIO; const ADataPort: TCustomDataPort;
  const APinDC: Integer; const APinRST: Integer);
begin
  FPhysicalOrientation := TOrientation.InversePortrait;
  FPhysicalSize := Point(240, 320);

  FScreenBufferSize := (FPhysicalSize.X * FPhysicalSize.Y) * SizeOf(TScreenColor);
  FScreenBuffer := AllocMem(FScreenBufferSize);

  inherited Create(AGPIO, ADataPort, APinDC, APinRST);
end;

procedure TDisplay.InitSequence;
begin
  WriteCommand(CMD_SW_RESET);
  Sleep(5);

  WriteCommand($EF);
  WriteData([$03, $80, $02]);

  WriteCommand($CF);
  WriteData([$00, $C1, $30]);

  WriteCommand($ED);
  WriteData([$64, $03, $12, $81]);

  WriteCommand($E8);
  WriteData([$85, $00, $78]);

  WriteCommand($CB);
  WriteData([$39, $2C, $00, $34, $02]);

  WriteCommand($F7);
  WriteData($20);

  WriteCommand($EA);
  WriteData([$00, $00]);

  WriteCommand(CMD_POWER_CTRL_1);
  WriteData($23);

  WriteCommand(CMD_POWER_CTRL_2);
  WriteData($10);

  WriteCommand(CMD_VCOM_CTRL_1);
  WriteData($3E);
  WriteData($28);

  WriteCommand(CMD_VCOM_CTRL_2);
  WriteData($86);

  WriteCommand(CMD_MEM_ACCESS_CTRL);
  WriteData($48);

  WriteCommand(CMD_SET_PIXEL_FORMAT);
  WriteData($66);

  WriteCommand(CMD_FRAME_RATE_CTRL);
  WriteData([$00, $18]);

  WriteCommand(CMD_DISPLAY_FUNCTION_CTRL);
  WriteData([$08, $82, $27]);

  WriteCommand($F2);
  WriteData($00);

  WriteCommand(CMD_GAMMA_SET);
  WriteData($01);

  WriteCommand(CMD_POS_GAMMA_CORRECT);
  WriteData([$0F, $31, $2B, $0C, $0E, $08, $4E, $F1, $37, $07, $10, $03, $0E, $09, $00]);

  WriteCommand(CMD_NEG_GAMMA_CORRECT);
  WriteData([$00, $0E, $14, $03, $11, $07, $31, $C1, $48, $08, $0F, $0C, $31, $36, $0F]);

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
    Result := Pointer(PtrUInt(FScreenBuffer) + Cardinal(AIndex) * Cardinal(FPhysicalSize.X) * SizeOf(TScreenColor))
  else
    Result := nil;
end;

end.
