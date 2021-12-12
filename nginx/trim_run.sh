
set -x

export PATH='/usr/local/nginx/sbin/':$PATH
logdir="/acl_test/tracing/data/nginx-"`date +'%F%H%M%S'`

function test_run(){
    local name="$1"
    local cmd="$2"
    local conf="$3"
    local savelog="$4"

    nginx -s stop
    sleep 1

    rm -r /tmp/log-*
    cp ${conf} /usr/local/nginx/conf/nginx.conf
    nginx
    sleep 1

    $cmd
    sleep 1

    if [ "$savelog" == "true" ]; then
        mkdir $logdir
        mv /tmp/log-* $logdir/${name}
        chmod -R a+r $logdir/${name}
    fi
}

function test_webserver_allow_deny_file(){
    local name="webserver_allow_deny_file"
    local cmd="wget http://127.0.0.1/"
    local conf="nginx.conf"
    chmod 000 /usr/local/nginx/html/index.html
    test_run "${name}_deny" "$cmd" "$conf" $SAVELOG
    chmod 644 /usr/local/nginx/html/index.html
    test_run "${name}_allow" "$cmd" "$conf" $SAVELOG
}

function test_webserver_allow_deny_ip(){
    local name="auth_basic"
    local cmd="wget http://127.0.0.1/"
    local conf1="nginx-denyip.conf"
    local conf2="nginx.conf"
    test_run "${name}_deny" "$cmd" "$conf1" $SAVELOG
    test_run "${name}_allow" "$cmd" "$conf2" $SAVELOG
}


function test_proxy_allow_deny_ip(){
    local name="auth_basic"
    local cmd="wget http://127.0.0.1/"
    local conf1="nginx-proxy_denyip.conf"
    local conf2="nginx-proxy_allowip.conf"
    test_run "${name}_deny" "$cmd" "$conf1" $SAVELOG
    test_run "${name}_allow" "$cmd" "$conf2" $SAVELOG
}

test_webserver_allow_deny_file
test_webserver_allow_deny_ip
test_proxy_allow_deny_ip