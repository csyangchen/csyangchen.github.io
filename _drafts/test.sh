#!/bin/bash
PATHS="a b c"

for PATH in $PATHS; do
  echo $PATH
  ls $PATH
done

for P in $PATHS; do
  echo $P
  ls $P
done