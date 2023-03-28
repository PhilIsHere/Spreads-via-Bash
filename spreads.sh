#!/bin/bash
#
# Script for extracting security spreads at different trading places from ANONYM (ANONYM.de).
#
# Args: [isinList=isins.txt] [tradingPlaceList=tps.txt]
 
# Define constants
SCRIPTPATH=$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )
HUMANNOW=$(date '+%d.%m.%Y %H:%M:%S')
FILENOW=$(date '+%Y%m%d-%H%M%S')
USERAGT="Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/111.0"
 
# Define dirs / file names
SOURCES=$SCRIPTPATH/sources
RESFILE=$SCRIPTPATH/spreads.csv
 
# Define input files
ISINFILE=$SCRIPTPATH"/"${1:-isins.txt}
TRPLFILE=$SCRIPTPATH"/"${2:-tps.txt}
 
# Make dirs
mkdir -p $SOURCES
 
# Read security IDs (WKN or ISIN)
readarray -t stockIds < $ISINFILE
# ...and trading places of interest
readarray -t trPlaces < $TRPLFILE
 
# Iterate security IDs
for id in "${stockIds[@]}"
do
 
    # Define temp files
    HTMLFILE=$SOURCES/$id-$FILENOW.html
    TEXTFILE=$SOURCES/$id-$FILENOW.txt
    
    # Get source data and simlify to plain text - Add Source URL
    curl -s -L -A "$USERAGT" -o $HTMLFILE https://www.ANONYM.de/$id/kurs
    text=$(lynx -dump $HTMLFILE | tr -cd '\40-\176' | sed 's/ \{1,\}/ /g')
 
    # Iterate trading places
    for tp in "${trPlaces[@]}"
    do
        # Match bid/ask pattern
        # TradingPlace BidSize BidPrice[opt%] AskPrice[opt%] AskSize Spread Time
        # [opt%] denotes an optional, space-separated percentage size in the case of bonds
        match=$(echo $text | grep -Eo "${tp} ([0-9.]+) ([0-9,.]+[ %]*) ([0-9,.]+[ %]*) ([0-9.]+) ([0-9,]+)% ([0-9:]{8})" | sed "s/${tp}//g")
        match=$(echo $match | sed "s/ \%//g")
        
        # ...and extract data
        bidSize=$(echo $match | cut -d" " -f1)
        bid=$(echo $match | cut -d" " -f2)
        ask=$(echo $match | cut -d" " -f3)
        askSize=$(echo $match | cut -d" " -f4)
        spread=$(echo $match | cut -d" " -f5)
        time=$(echo $match | cut -d" " -f6)
        
        # Append data to result file
        echo "$HUMANNOW;$id;$tp;$bid;$ask;$spread;$bidSize;$askSize;$time" >> $RESFILE
    done
    
    # Save temp text file and add to zipped sources
    echo $text >> $TEXTFILE
    zip -q -m -9 -j $SOURCES/$id.zip $TEXTFILE
    
    # Sleep briefly
    sleep .5
 
done
