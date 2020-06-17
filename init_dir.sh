#!/bin/bash
dirName=`date +%Y%m`
if [ ! -d  $dirName ]
then
	mkdir $dirName
fi
