#!/bin/bash
WORKDIR=$(dirname "$0")
gcc -c -Os -o $WORKDIR/WriteMemSafe.o $WORKDIR/WriteMemSafe.c
ar r $WORKDIR/WriteMemSafe.a $WORKDIR/WriteMemSafe.o
rm $WORKDIR/WriteMemSafe.o 