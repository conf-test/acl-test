#! /bin/bash

# set -x

export PATH='/usr/local/sbin/':$PATH

logdir="/acl_test/tracing/data/vsftpd-"`date +'%F%H%M%S'`
SAVELOG="true"

function gen_conf(){
    local source="$1"
    local parameter="$2"
    local oldvalue="$3"
    local newvalue="$4"
    local out="${source}.${parameter}_${newvalue}.conf"
    out=$(echo "$out" | sed "s/,/_/g")
    sed "s/#${parameter}=${oldvalue}/${parameter}=${newvalue}/g" <${source} >$out
    eval $5=$out
}

function test_run(){
    local name="$1"
    local cmd="$2"
    local conf="$3"
    local savelog="$4"

    rm -r /tmp/log-*
    cp $conf /etc/vsftpd.conf
    pkill vsftpd
    vsftpd&
    sleep 1
ftp -inv localhost <<EOF
    "$cmd"
EOF
    sleep 1
    dirname=$name-`date +'%F%H%M%S'`
    if [ "$savelog" == "true" ]; then
        mkdir $logdir
        mv /tmp/log-* $logdir/${name}
        chmod -R a+r $logdir/${name}
    fi
}

function test_deny_allow(){
    local conftemp=$1
    local parameter=$2
    local default=$3
    local testcmd=$4
    local file=$5
    local savelog=$6
    gen_conf "${conftemp}" "${parameter}" "$default" "NO" conf
    test_run "${parameter}_NO"  "$testcmd" "$conf" "$savelog"
    gen_conf "${conftemp}" "${parameter}" "$default" "YES" conf
    test_run "${parameter}_YES" "$testcmd" "$conf" "$savelog"
}

function test_deny_allow2(){
    local conftemp=$1
    local parameter=$2
    local default=$3
    local value1=$4
    local value2=$5
    local testcmd=$6
    local file=$7
    local savelog=$8
    local v1=$(echo "$value1" | sed "s/,/_/g")
    local v2=$(echo "$value2" | sed "s/,/_/g")
    gen_conf "${conftemp}" "${parameter}" "$default" "$value1" conf
    test_run "${parameter}_$v1"  "$testcmd" "$conf" "$savelog"
    gen_conf "${conftemp}" "${parameter}" "$default" "$value2" conf
    test_run "${parameter}_$v2" "$testcmd" "$conf" "$savelog"
}

function test_deny_allow_file(){
    local conftemp=$1
    local parameter=$2
    local default=$3
    local testcmd=$4
    local file=$5
    local mode1=$6
    local mode2=$7
    local savelog=$8
    gen_conf "${conftemp}" "${parameter}" "$default" "YES" conf
    chmod $mode1 $file
    test_run "${parameter}_file_deny"  "$testcmd" "$conf" "$savelog"
    chmod $mode2 $file
    test_run "${parameter}_file_allow" "$testcmd" "$conf" "$savelog"
}

parameter="write_enable"
conftemp="conf/vsftpd.temp.conf"
default="YES"
file="/home/test/upload/Dockerfile"
testcmd="
        user test test
        cd upload
        put Dockerfile 
        bye
    "
rm $file
test_deny_allow "$conftemp" "$parameter" "$default" "$testcmd" "$file" "$SAVELOG"

# ## seems a bug here, with --x, file still can be uploaded
rm $file
test_deny_allow_file "$conftemp" "$parameter" "$default" "$testcmd" "/home/test/upload/" "u-w" "u+w" "$SAVELOG"

parameter="anon_upload_enable"
conftemp="conf/vsftpd.temp.conf"
gen_conf "${conftemp}" "write_enable" "YES" "YES" conftemp
default="YES"
file="/var/ftp/upload/Dockerfile"
testcmd="
        user ftp ''
        cd upload
        put Dockerfile 
        bye
    "
rm $file
test_deny_allow "$conftemp" "$parameter" "$default" "$testcmd" "$file" "$SAVELOG"
rm $file
test_deny_allow_file "$conftemp" "$parameter" "$default" "$testcmd" "/var/ftp/upload/" "u-w" "u+w" "$SAVELOG"

parameter="anon_mkdir_write_enable"
conftemp="conf/vsftpd.temp.conf"
gen_conf "${conftemp}" "write_enable" "YES" "YES" conftemp
default="YES"
file="/var/ftp/upload/testdir"
testcmd="
        user ftp ''
        cd upload
        mkdir testdir 
        bye
    "
rm -r $file
test_deny_allow "$conftemp" "$parameter" "$default" "$testcmd" "$file" "$SAVELOG"
rm -r $file
test_deny_allow_file "$conftemp" "$parameter" "$default" "$testcmd" "/var/ftp/upload/" "u-w" "u+w" "$SAVELOG"

parameter="anon_other_write_enable"
conftemp="conf/vsftpd.temp.conf"
gen_conf "${conftemp}" "write_enable" "YES" "YES" conftemp
default="YES"
file="/var/ftp/upload/Dockerfile"
testcmd="
        user ftp ''
        cd upload
        delete Dockerfile 
        bye
    "
touch $file
test_deny_allow "$conftemp" "$parameter" "$default" "$testcmd" "$file" "$SAVELOG"
touch $file
test_deny_allow_file "$conftemp" "$parameter" "$default" "$testcmd" "/var/ftp/upload/" "u-w" "u+w" "$SAVELOG"

testcmd="
        user ftp ''
        cd upload
        rename Dockerfile Dockerfile2
        bye
    "
touch $file
test_deny_allow "$conftemp" "$parameter" "$default" "$testcmd" "$file" "$SAVELOG"
touch $file
test_deny_allow_file "$conftemp" "$parameter" "$default" "$testcmd" "/var/ftp/upload/" "u-w" "u+w" "$SAVELOG"

parameter="anon_world_readable_only"
conftemp="conf/vsftpd.temp.conf"
default="YES"
file="/var/ftp/upload/Dockerfile"
testcmd="
        user ftp ''
        cd upload
        get Dockerfile 
        bye
    "
touch $file
test_deny_allow_file "$conftemp" "$parameter" "$default" "$testcmd" "$file" "o-r" "a+r" "$SAVELOG"


# bad log at postlogin.c:1505-1529
# bug?: chmod 666 upload/Dockerfile failed
parameter="chmod_enable"
conftemp="conf/vsftpd.temp.conf"
default="YES"
file="/home/test/Dockerfile"
testcmd="
        user test test
        chmod 777 Dockerfile 
        bye
    "
touch $file
gen_conf "${conftemp}" "write_enable" "YES" "YES" conftemp
test_deny_allow "$conftemp" "$parameter" "$default" "$testcmd" "$file" "$SAVELOG"

parameter="dirlist_enable"
conftemp="conf/vsftpd.temp.conf"
default="YES"
file="/home/test/Dockerfile"
testcmd="
        user test test
        ls
        bye
    "
touch $file
test_deny_allow "$conftemp" "$parameter" "$default" "$testcmd" "$file" "$SAVELOG"
touch $file
test_deny_allow_file "$conftemp" "$parameter" "$default" "$testcmd" "/home/test/" "u-x" "u+x" "$SAVELOG"

parameter="download_enable"
conftemp="conf/vsftpd.temp.conf"
default="YES"
file="/home/test/Dockerfile"
testcmd="
        user test test
        get Dockerfile
        bye
    "
touch $file
test_deny_allow "$conftemp" "$parameter" "$default" "$testcmd" "$file" "$SAVELOG"
touch $file
test_deny_allow_file "$conftemp" "$parameter" "$default" "$testcmd" "$file" "u-r" "u+r" "$SAVELOG"

#mdtm_write TODO

# very confusing userlist_deny relies on userlist_enable
# 500 OOPS: child died
parameter="userlist_deny"
conftemp="conf/vsftpd.temp.conf"
default="YES"
file="/home/test/Dockerfile"
testcmd="
        user test test
        bye
    "
echo "test" > /etc/vsftpd.user_list
gen_conf "${conftemp}" "userlist_file" "" "" conftemp
gen_conf "${conftemp}" "userlist_enable" "YES" "YES" conftemp
test_deny_allow "$conftemp" "$parameter" "$default" "$testcmd" "$file" "$SAVELOG"

# werid behavior
parameter="cmds_allowed"
conftemp="conf/vsftpd.temp.conf"
default="PASV,RETR,QUIT"
value1="RETR"
value2="PASV,RETR,QUIT"
file="/home/test/Dockerfile"
testcmd="
        user test test
        pass
        bye
    "
touch $file
test_deny_allow2 "$conftemp" "$parameter" "$default" "$value1" "$value2" "$testcmd" "$file" "$SAVELOG"


parameter="cmds_denied"
conftemp="conf/vsftpd.temp.conf"
default="PASV,RETR,QUIT"
value1="PASV,RETR,QUIT"
value2=""
file="/home/test/Dockerfile"
testcmd="
        user test test
        pass
        bye
    "
touch $file
test_deny_allow2 "$conftemp" "$parameter" "$default" "$value1" "$value2" "$testcmd" "$file" "$SAVELOG"

# deny_file todo