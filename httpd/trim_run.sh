
set -x

export PATH='/usr/local/apache2/bin/':$PATH
SAVELOG=""
logdir="/acl_test/tracing/data/httpd-"`date +'%F%H%M%S'`
umask 000

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

    apachectl -k stop
    sleep 1

    rm -r /tmp/log-*
    cp ${conf} /usr/local/apache2/conf/httpd.conf
    apachectl -k start -X&
    sleep 1

    $cmd
    sleep 1

    if [ "$savelog" == "true" ]; then
        mkdir $logdir
        mv /tmp/log-* $logdir/${name}
        chmod -R a+r $logdir/${name}
    fi
}

function test_file(){
    local name="file"
    local cmd="wget 127.0.0.1"
    local conf="conf/httpd.conf"
    local perm1=000
    local perm2=644
    chmod $perm1 /usr/local/apache2/htdocs/index.html
    test_run "${name}_deny" "$cmd" "$conf" $SAVELOG
    chmod $perm2 /usr/local/apache2/htdocs/index.html
    test_run "${name}_allow" "$cmd" "$conf" $SAVELOG
}

function test_require(){
    local name="require"
    local cmd="wget 127.0.0.1"
    local conf1="conf/httpd-deny.conf"
    local conf2="conf/httpd.conf"
    test_run "${name}_deny" "$cmd" "$conf1" $SAVELOG
    test_run "${name}_allow" "$cmd" "$conf2" $SAVELOG
}

function test_asis(){
    local name="asis"
    local cmd="wget 127.0.0.1/asis/index.asis"
    local conf="conf/httpd.conf"
    local perm1=000
    local perm2=644
    local file=/usr/local/apache2/htdocs/asis/index.asis
    cp -r htdocs /usr/local/apache2/htdocs/
    chmod $perm1 $file
    test_run "${name}_deny" "$cmd" "$conf" $SAVELOG
    chmod $perm2 $file
    test_run "${name}_allow" "$cmd" "$conf" $SAVELOG
}

#bad log?
function test_cgi(){
    local name="cgi"
    local cmd="wget 127.0.0.1/cgi-bin/test-cgi"
    local conf="conf/httpd.conf"
    local perm1=000
    local perm2=755
    local file=/usr/local/apache2/cgi-bin/test-cgi
    cp -r cgi-bin /usr/local/apache2/cgi-bin
    chmod $perm1 $file
    test_run "${name}_deny" "$cmd" "$conf" $SAVELOG
    chmod $perm2 $file
    test_run "${name}_allow" "$cmd" "$conf" $SAVELOG
}

function test_action(){
    local name="action"
    local cmd="wget 127.0.0.1/action"
    local conf="conf/httpd.conf"
    local perm1=000
    local perm2=755
    local file=/usr/local/apache2/cgi-bin/test-cgi
    cp -r cgi-bin /usr/local/apache2/cgi-bin
    chmod $perm1 $file
    test_run "${name}_deny" "$cmd" "$conf" $SAVELOG
    chmod $perm2 $file
    test_run "${name}_allow" "$cmd" "$conf" $SAVELOG
}

# need to enable the module
function test_imagemap(){
    local name="imagemap"
    local cmd="wget 127.0.0.1/maps/imagemap1.map"
    local conf="conf/httpd.conf"
    local perm1=000
    local perm2=755
    local file=/usr/local/apache2/htdocs/maps/imagemap1.map
    cp -r htdocs /usr/local/apache2/
    chmod $perm1 $file
    test_run "${name}_deny" "$cmd" "$conf" $SAVELOG
    chmod $perm2 $file
    test_run "${name}_allow" "$cmd" "$conf" $SAVELOG
    rm imagemap.*
}

function test_info(){
    local name="info"
    local cmd="wget 127.0.0.1/server-info"
    local conf1="conf/httpd-info-deny.conf"
    local conf2="conf/httpd.conf"
    test_run "${name}_deny" "$cmd" "$conf1" $SAVELOG
    test_run "${name}_allow" "$cmd" "$conf2" $SAVELOG
    rm server-info.*
}

#TODO mime

function test_status(){
    local name="status"
    local cmd="wget 127.0.0.1/server-status"
    local conf1="conf/httpd-status-deny.conf"
    local conf2="conf/httpd.conf"
    test_run "${name}_deny" "$cmd" "$conf1" $SAVELOG
    test_run "${name}_allow" "$cmd" "$conf2" $SAVELOG
    rm server-status.*
}

# TODO not work yet
function test_method(){
    local name="method"
    local cmd="curl -s -i -X POST http://127.0.0.1/"
    local conf1="conf/httpd.conf"
    local conf2="conf/httpd-method.conf"
    test_run "${name}_deny" "$cmd" "$conf1" $SAVELOG
    test_run "${name}_allow" "$cmd" "$conf2" $SAVELOG
    rm index.html*
}

function test_dav(){
    local name="dav"
    local cmd="curl -s -i -T Dockerfile http://127.0.0.1/upload/Dockerfile"
    local conf="conf/httpd.conf"
    rm -rf /usr/local/apache2/htdocs/upload/
    mkdir /usr/local/apache2/htdocs/upload/
    mkdir /usr/local/apache2/var/
    chmod 777 /usr/local/apache2/var/

    chmod 000 /usr/local/apache2/htdocs/upload/
    test_run "${name}_deny" "$cmd" "$conf" $SAVELOG
    chmod 777 /usr/local/apache2/htdocs/upload/
    test_run "${name}_allow" "$cmd" "$conf" $SAVELOG
}

function test_proxy(){
    local name="proxy"
    local cmd="wget http://127.0.0.1/proxy"
    local conf1="conf/httpd-proxy-deny.conf"
    local conf2="conf/httpd.conf"
    test_run "${name}_deny" "$cmd" "$conf1" $SAVELOG
    test_run "${name}_allow" "$cmd" "$conf2" $SAVELOG
}

test_file
test_require
test_asis
test_cgi
test_action
test_info
test_status
test_dav
test_proxy