#!/bin/bash  
# Loop over a list of systems looking for specifically named/dated files, call external scripts
# to break up and compare files, leaving a list of named files to review. 
# external custom scripts: fixHL7, compareOut
# external system scripts: iconv

egData=""
clData=""

month=$1
clDate=$2
egDate=$3

if [[ ($1 == "") || ($2 == "") ]]; then #Need to fix this so it's less of a garbage check, outdated. 
  echo "Please correct the date."
  echo "  . ./multiCompare <month> <Cloverleaf day run> <eGate day run>"
else
  dirs="$HCIROOT/journal/sfp"
  sortSites="epic2ps eADT2mmf epic2cdr"

  while read system; do #loop over a list of system names (bad var?) to compare stored in a text file thd_list.txt
    
    if [[ ${system} == "epic2nchess" ]]; then
       egFile="${dirs}/eGate/2023${month}${egDate}-ew_epic2nchesx_out"
    else
       egFile="${dirs}/eGate/2023${month}${egDate}-ew_${system}_out"
    fi

    if [[ ${system} == "epic2cdr" ]]; then
      clFile="${dirs}/2023${month}${clDate}-xlatort-mrh-t_eADT2cdr_o"
    else
      clFile="${dirs}/2023${month}${clDate}-xlatort-mrh-t_${system}_o"
    fi

    chkFil=0
    if [ ! -f "${egFile}" ]; then
      echo "No file for eGate: ${egFile}"
      ((chkFil+=1))
    fi

    if [ ! -f "${clFile}" ]; then
      echo "No file for Cloverleaf: ${clFile}"
      ((chkFil+=10))
    fi

    if (( ($chkFil == 11)  )); then
      truncate -s 0 ${dirs}/comps/diff.break.${system}
      truncate -s 0 ${dirs}/comps/diff.print.${system}
      continue
    elif (( $chkFil == 1 )); then
      echo "No file for eGate: ${egFile}" > ${dirs}/comps/diff.break.${system}
      echo "No file for eGate: ${egFile}" > ${dirs}/comps/diff.print.${system}
    elif (( $chkFil == 10 )); then
      echo "No file for Cloverleaf: ${clFile}" > ${dirs}/comps/diff.break.${system}
      echo "No file for Cloverleaf: ${clFile}" > ${dirs}/comps/diff.print.${system}
    fi
   
    clData=$( cat ${clFile} )
    egData=$( cat ${egFile} )

    if [[ "${system}" != "eADT2pmc" ]]; then # Only add specific types of data on each line
      egData=$(grep -a "|ADT^" <<< "${egData}")
    fi

    if grep -q "${system}" <<< "${sortSites}"; then # Sort specific sites that need sorting. 
      if [[ ${system} == "epic2ps" ]]; then # Exclude data that shouldn't be in these compares. 
        egData=$(grep -av "PMC01|Z|IM|Z" <<< "${egData}")
        #mv ${egFile}.ADT1 ${egFile}.ADT
      fi

      egData=$(echo "${egData}" | sort -u )
      #echo "${egData}" > ${egFile}.sort
      #mv ${egFile}.ADT1 ${egFile}.ADT

      clData=$(echo "${clData}" | sort -u )
      #echo "${clData}" > ${clFile}.sort
      #mv ${clFile}.ADT1 ${clFile}
    fi
  
    if [[ "${system}" == "epic2aei" ]]; then
      egData=$(grep -av "|IMG_" <<< "${egData}")
      #mv ${egFile}.ADT1 ${egFile}.ADT
    fi

    echo "${egData}" > ${egFile}.ADT
    echo "${clData}" > ${clFile}.ADT

    fixHL7 ${egFile}.ADT > /dev/null 2>&1
    iconv -f Windows-1252 -t UTF-8 ${egFile}.ADT.fix > ${egFile}.ADT.fix.c
   
    compareOut ${egFile}.ADT.fix.c ${clFile}.ADT > /dev/null 2>&1
    mv "${dirs}/diff.break" "${dirs}/comps/diff.break.${system}"
    mv "${dirs}/diff.print" "${dirs}/comps/diff.print.${system}"

    rm ${clFile}.ADT ${egFile}.ADT ${egFile}.ADT.fix
  
  done < "/home/hci/bin/thd_list.txt"
fi
