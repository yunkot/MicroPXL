program SerialCamera;
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
{
  This example illustrates how to take a snapshot from serial camera.

  Attention! Please follow these instructions before running the sample:

   1. Make sure that the serial camera is connected properly to UART pins on your device. Pay special attention to
      voltage levels as the majority devices, including Raspberry PI and BeagleBone Black tolerate only up to 3.3V.
      If that is the case, then make sure to apply voltage divider on UART's RX pin.

   2. Specify the path to the corresponding UART port on the device. This varies between devices but is usually
      located in "/dev/tty*". For BeagleBone Black, it is usually "/dev/ttyON" (where N is number of UART, usually 1).
      For Intel Galileo, it is usually "/dev/ttyS0", for Raspberry PI, it is "/dev/ttyAMA0".

   3. Note that on some devices such as Raspberry PI, the UART by default is used as debug console. Therefore, it is
      necessary to disable such feature (e.g. in raspi-config) before using that UART port.

   4. After compiling and uploading this sample, change its attributes to executable. It is also recommended to
      execute this application with administrative privileges. Something like this:
        chmod +x SerialCamera
        sudo ./SerialCamera

   5. Serial cameras such as VC0706 or LSY201 transfer images through UART. This is quite slow and delicate process,
      and many things can go wrong. It is recommended to use only hardware UART ports connected directly to the camera
      (but again, pay attention on voltage levels) for this purpose, without any helpers such as SC16IS7x0 chip or
      intermediaries such as XBee.
}
uses
  // The following line can be replaced to "PXL.Cameras.LSY201" depending on camera's brand.
  PXL.Cameras.VC0706,
//  PXL.Cameras.LSY201,

  SysUtils, Classes, PXL.Types, PXL.Boards.Types, PXL.Sysfs.UART;

const
// Please make sure that this path points to the appropriate UART where serial camera is connected to.
  PathToUART = '/dev/ttyO1';

procedure SaveBufferToDisk(const ABuffer: Pointer; const ABufferSize: Integer);
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create('snapshot.jpg', fmCreate or fmShareExclusive);
  try
    LStream.WriteBuffer(ABuffer^, ABufferSize);
  finally
    LStream.Free;
  end;
end;

procedure RetrievePicture(const APortUART: TCustomPortUART);
var
  LCamera: TCamera = nil;
  LBuffer: Pointer = nil;
  LBufferSize: Integer = 0;
begin
  LCamera := TCamera.Create(APortUART);
  try
    APortUART.BaudRate := LCamera.DefaultBaudRate;

    Write('Resetting Lcamera: ');

    if not LCamera.Reset then
    begin
      WriteLn('ERROR.');
      Exit;
    end;

    WriteLn('OK.');

    WriteLn('Received Lcamera response:');
    WriteLn('................................');
    WriteLn(TCamera(LCamera).BootText);
    WriteLn('................................');

    Sleep(200);

    Write('Setting image size: ');

    if not LCamera.SetImageSize(640, 480) then
    begin
      WriteLn('ERROR.');
      Exit;
    end;

    WriteLn('OK.');

    Sleep(250);

    Write('Taking snapshot: ');

    if not LCamera.TakeSnapshot then
    begin
      WriteLn('ERROR.');
      Exit;
    end;

    WriteLn('OK.');

    Sleep(500);

    Write('Retrieving picture: ');

    if not LCamera.GetPicture(LBuffer, LBufferSize) then
    begin
      WriteLn('ERROR.');
      Exit;
    end;

    WriteLn('OK.');
  finally
    LCamera.Free;
  end;

  try
    SaveBufferToDisk(LBuffer, LBufferSize);
  finally
    FreeMem(LBuffer);
  end;

  WriteLn('Snapshot saved to disk.');
end;

var
  PortUART: TCustomPortUART = nil;

begin
  PortUART := TSysfsUART.Create(nil, PathToUART);
  try
    RetrievePicture(PortUART);
  finally
    PortUART.Free;
  end;
end.
