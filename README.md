# Micro Platform eXtended Library (MicroPXL)
A library for *Delphi* and *FreePascal/Lazarus* that enables working with peripheral devices and I/O. It supports both desktop and single-board computers such as Raspberry PI, providing access to Serial Port / UART, I²C, SPI and GPIO.

The following devices are supported:
* *Raspberry PI* (all versions), both 32-bit and 64-bit
* Linux-based SBCs such as *Beagle Bone Black*, *Odroid*, *Olimexino*, etc.
* *Intel Galileo* and *Edison*
* Windows and Linux-based desktop PCs

The following peripherals are supported:
* GPIO with ADC and PWM
* Serial Port (UART)
* I²C
* SPI
* Software-based serial port using GPIO "bit-banging"

For desktop computers running *Windows* or *Linux*, the library supports **serial port** and **UDP networking**.

The library contains a comprehensive software-based renderer with text and custom fonts, which can be drawn directly on the form, saved to disk, or shown on one of the following displays connected by SPI or I²C:
* HD44780 standard 16x2 LCD
* HX8357 graphics 320x480 TFT LCD display
* ILI9340 graphics 18-bit color TFT LCD display
* PCB8544 graphics LCD from Nokia 5110
* SSD1306 graphics 128x64 OLED display
* SSD1351 graphics 128x128 OLED display

The following sensors are directly supported by the library:
* BMP180 barometric pressure
* DHT22 temperature and humidity
* L3GD20 triple-axis gyroscope
* LSM303 accelerometer and compass
* SHT10 temperature and humidity
* DS1307 RTC clock
* SC16S7x0 external UART

The library can access the following cameras:
* LSY201 serial JPEG color / infrared camera by LinkSprite
* VC0706 serial camera
* V4L2-based cameras, including those connected through USB and Raspberry PI cameras

For **Raspberry PI** up until version 4, the library uses direct register access for extremely high real-time I/O performance in GPIO, I²C and SPI.
Currently, for Raspberry PI 5, only generic sysfs-based peripheral access is available; register-based access is under investigation, but I don't have a physical device to do the actual tests.

On **Intel Galileo** and **Edison** boards, the library does automatic multiplexing and supports fast GPIO on specific pins that have such feature.

Note: when using fast I/O on Raspberry PI (PXL.Boards.RPi.pas), you need to manually compile "WriteMemSafe.c" file, which contains two trivial memory-barrier functions required by the unit, until support for memory barriers is introduced in FreePascal. You can use an existing "WriteMemSafe.sh" shell script for that, which is automatically executed by the accompanying examples, just make sure to change its permissions to make it executable.

***If your device is not listed, please consider sending it to me and preferably sponsoring the work on this library.***
