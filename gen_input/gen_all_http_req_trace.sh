#! /bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

if [ "$#" -le 1 ]; then
    echo "Usage: ./gen_all_http_req_trace.sh htmldir outputfile"
    exit 1
fi

htmldir=$1
outputfile=$2

WORK_PATH=`pwd`
cd ${htmldir} && ls -lLaR > "/tmp/allfiles.txt"
cd ${WORK_PATH}

localip=`hostname -I`
python3 ${DIR}/gen_all_http_req_trace.py '/tmp/allfiles.txt' $localip $localip $outputfile