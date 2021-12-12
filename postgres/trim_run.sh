#!/bin/bash

set -x
export PATH='/usr/local/pgsql/bin/':$PATH

# su - postgres
umask 000

exec_sql() {
    psql -U "$1" -d test -c "$2"
}

init_db () {
    pg_ctl -D /usr/local/pgsql/data -l logfile start
    sleep 1
    exec_sql "postgres" "CREATE DATABASE test;"
    exec_sql "postgres" "CREATE TABLE accounts (
        user_id serial PRIMARY KEY,
        username VARCHAR ( 50 ) UNIQUE NOT NULL); 
        CREATE ROLE test_role LOGIN;"
    sleep 1
    pg_ctl -D /usr/local/pgsql/data -l logfile stop
}

logdir="/acl_test/tracing/data/postgres-"`date +'%F%H%M%S'`
mkdir $logdir
test(){
    name="$1"
    user="$2"
    cmd="$3"
    savelog="$4"
    rm -r /tmp/log-*
    sleep 2
    exec_sql "$user" "$cmd"
    sleep 2
    dirname=$name-`date +'%F%H%M%S'`
    if [ "$savelog" == "true" ]; then
        mv /tmp/log-* $logdir/${name}
    fi
}

pg_ctl -D /usr/local/pgsql/data -l logfile start
sleep 2

init_db

USER='test_role'
SUPERUSER='postgres'

# database
## create on database
## this is VERY confusing!
testcmd="CREATE SCHEMA testschema"
testcase="database_create"
psql -U postgres -d test -c "REVOKE CREATE ON DATABASE test FROM test_role;"
# psql -U test_role -d test -c "CREATE SCHEMA testschema"
test "${testcase}_deny" 'test_role' "$testcmd" 'true'
psql -U postgres -d test -c "GRANT CREATE ON DATABASE test TO test_role;"
#psql -U test_role -d test -c "CREATE SCHEMA testschema"
test "${testcase}_allow" 'test_role' "$testcmd" 'true'

## temporary on database
testcmd="CREATE TEMPORARY TABLE foo(i int);"
testcase="database_temporary"
psql -U postgres -d test -c "REVOKE TEMPORARY ON DATABASE test FROM PUBLIC;"
psql -U postgres -d test -c "REVOKE TEMPORARY ON DATABASE test FROM test_role;"
# psql -U test_role -d test -c "CREATE TEMPORARY TABLE foo(i int);"
test "${testcase}_deny" 'test_role' "$testcmd" 'true'
psql -U postgres -d test -c "GRANT TEMPORARY ON DATABASE test TO test_role;"
# psql -U test_role -d test -c "CREATE TEMPORARY TABLE foo(i int);"
test "${testcase}_allow" 'test_role' "$testcmd" 'true'

## connect on database
testcmd="\dt"
testcase="database_connect"
psql -U postgres -d test -c "REVOKE CONNECT ON DATABASE test FROM test_role;"
psql -U postgres -d test -c "REVOKE CONNECT ON DATABASE test FROM PUBLIC;"
# psql -U test_role -d test -c "\dt"
test "${testcase}_deny" 'test_role' "$testcmd" 'true'
psql -U postgres -d test -c "GRANT CONNECT ON DATABASE test TO test_role;"
# psql -U test_role -d test -c "\dt"
test "${testcase}_allow" 'test_role' "$testcmd" 'true'

# domain 
## usage on domain
testcmd="CREATE TABLE bar ( bar test_domain );"
testcase="domain_usage"
psql -U test_role -d test -c "CREATE DOMAIN test_domain AS TEXT"
psql -U postgres -d test -c "REVOKE USAGE ON DOMAIN test_domain FROM test_role;"
psql -U postgres -d test -c "REVOKE USAGE ON DOMAIN test_domain FROM PUBLIC;"
# psql -U test_role -d test -c "CREATE TABLE bar ( bar test_domain );"
test "${testcase}_deny" 'test_role' "$testcmd" 'true'
psql -U postgres -d test -c "GRANT USAGE ON DOMAIN test_domain TO test_role;"
# psql -U test_role -d test -c "CREATE TABLE bar ( bar test_domain );"
test "${testcase}_allow" 'test_role' "$testcmd" 'true'

# function
## execute on function
## how to limit create function
testcmd="select ADD(1, 1);"
testcase="function_execute"
psql -U test_role -d test -c "CREATE FUNCTION add(integer, integer) RETURNS integer
         AS 'select \$1 + \$2;'
         LANGUAGE SQL
         IMMUTABLE
         RETURNS NULL ON NULL INPUT;"
psql -U postgres -d test -c "REVOKE EXECUTE ON FUNCTION add(integer, integer) FROM PUBLIC;"
psql -U postgres -d test -c "REVOKE EXECUTE ON FUNCTION add(integer, integer) FROM test_role;"
# psql -U test_role -d test -c "select ADD(1, 1)"
test "${testcase}_deny" 'test_role' "$testcmd" 'true'
psql -U postgres -d test -c "GRANT EXECUTE ON FUNCTION add(integer, integer) TO test_role;"
# psql -U test_role -d test -c "select ADD(1, 1)"
test "${testcase}_allow" 'test_role' "$testcmd" 'true'

# foreign data wrapper
# usage on foreign data wrapper
testcmd="CREATE SERVER myserver FOREIGN DATA WRAPPER dummy;"
testcase="foreign_data_wrapper_usage"
psql -U postgres -d test -c "CREATE FOREIGN DATA WRAPPER dummy;"
psql -U postgres -d test -c "REVOKE USAGE ON FOREIGN DATA WRAPPER dummy FROM test_role;"
# psql -U test_role -d test -c "CREATE SERVER myserver FOREIGN DATA WRAPPER dummy;"
test "${testcase}_deny" 'test_role' "$testcmd" 'true'
psql -U postgres -d test -c "GRANT USAGE ON FOREIGN DATA WRAPPER dummy TO test_role;"
# psql -U test_role -d test -c "CREATE SERVER myserver FOREIGN DATA WRAPPER dummy;"
test "${testcase}_allow" 'test_role' "$testcmd" 'true'

# foreign server TODO

# language TODO

# large object
## select large object
testcmd="SELECT lo_get(16395)"
testcase="large_object_select"
psql -U test_role -d test -c 'SELECT lo_create(16395)'
psql -U postgres -d test -c "REVOKE SELECT ON LARGE OBJECT 16395 FROM test_role;"
# psql -U test_role -d test -c "SELECT lo_get(16395)"
test "${testcase}_deny" 'test_role' "$testcmd" 'true'
psql -U postgres -d test -c "GRANT SELECT ON LARGE OBJECT 16395 TO test_role;"
# psql -U test_role -d test -c "SELECT lo_get(16395)"
test "${testcase}_allow" 'test_role' "$testcmd" 'true'

## update large object
testcmd="SELECT lo_put(16395, 1, '\xaa')"
testcase="large_object_update"
psql -U postgres -d test -c "REVOKE UPDATE ON LARGE OBJECT 16395 FROM test_role;"
# psql -U test_role -d test -c "SELECT lo_put(16395, 1, '\xaa')"
test "${testcase}_deny" 'test_role' "$testcmd" 'true'
psql -U postgres -d test -c "GRANT UPDATE ON LARGE OBJECT 16395 TO test_role;"
# psql -U test_role -d test -c "SELECT lo_put(16395, 1, '\xaa')"
test "${testcase}_allow" 'test_role' "$testcmd" 'true'

# schema
## create on schema
testcmd="CREATE TABLE testschema.foo(i int);"
testcase="schema_create"
psql -U test_role -d test -c "CREATE SCHEMA testschema"
psql -U postgres -d test -c "REVOKE CREATE ON SCHEMA testschema FROM test_role;"
# psql -U test_role -d test -c "CREATE TABLE testschema.foo(i int);"
test "${testcase}_deny" 'test_role' "$testcmd" 'true'
psql -U postgres -d test -c "GRANT CREATE ON SCHEMA testschema TO test_role;"
# psql -U test_role -d test -c "CREATE TABLE testschema.foo(i int);"
test "${testcase}_allow" 'test_role' "$testcmd" 'true'

# usage on schema
testcmd="select * from testschema.foo;"
testcase="schema_usage"
psql -U postgres -d test -c "REVOKE USAGE ON SCHEMA testschema FROM test_role;"
psql -U postgres -d test -c "REVOKE USAGE ON SCHEMA testschema FROM PUBLIC;"
# psql -U test_role -d test -c "select * from  testschema.foo;"
test "${testcase}_deny" 'test_role' "$testcmd" 'true'
psql -U postgres -d test -c "GRANT USAGE ON SCHEMA testschema TO test_role;"
# psql -U test_role -d test -c "select * from  testschema.foo;"
test "${testcase}_allow" 'test_role' "$testcmd" 'true'

# sequence
## select seq
testcmd="SELECT * from test_seq"
testcase="sequence_select"
psql -U postgres -d test -c "CREATE SEQUENCE test_seq"
# psql -U test_role -d test -c "SELECT nextval('test_seq')"
psql -U postgres -d test -c "REVOKE SELECT ON SEQUENCE test_seq from test_role"
# psql -U test_role -d test -c "SELECT * from test_seq"
test "${testcase}_deny" 'test_role' "$testcmd" 'true'
psql -U postgres -d test -c "GRANT SELECT ON SEQUENCE test_seq to test_role"
# psql -U test_role -d test -c "SELECT * from test_seq"
test "${testcase}_allow" 'test_role' "$testcmd" 'true'

## update seq failed
# psql -U postgres -d test -c "REVOKE UPDATE ON test_seq FROM test_role;"
# psql -U postgres -d test -c "GRANT UPDATE ON test_seq TO test_role;"
# psql -U test_role -d test -c "UPDATE test_seq SET log_cnt=8"
# psql -U test_role -d test -c "ALTER SEQUENCE test_seq RESTART WITH 1"

## usage on seq: failed
# psql -U postgres -d test -c "REVOKE USAGE ON SEQUENCE test_seq FROM test_role;"
# psql -U postgres -d test -c "REVOKE USAGE ON SEQUENCE test_seq FROM PUBLIC;"
# psql -U test_role -d test -c "SELECT nextval('test_seq')"

# table
psql -U postgres -d test -c "CREATE TABLE accounts (
                                user_id serial PRIMARY KEY,
                                username VARCHAR ( 50 ) UNIQUE NOT NULL); "
psql -U postgres -d test -c "ALTER TABLE accounts ADD age int"

## insert table
testcmd="INSERT INTO accounts (username) VALUES('testuser2')"
testcase="table_insert"
psql -U postgres -d test -c "REVOKE INSERT ON accounts FROM test_role;"
# psql -U test_role -d test -c "INSERT INTO accounts (username) VALUES('testuser2')"
test "${testcase}_deny" 'test_role' "$testcmd" 'true'
psql -U postgres -d test -c "GRANT INSERT ON accounts TO test_role;"
psql -U postgres -d test -c "GRANT USAGE, SELECT ON SEQUENCE accounts_user_id_seq TO test_role;"
# psql -U test_role -d test -c "INSERT INTO accounts (username) VALUES('testuser2')"
test "${testcase}_allow" 'test_role' "$testcmd" 'true'

## select table
testcmd="SELECT * FROM accounts;"
testcase="table_select"
psql -U postgres -d test -c "REVOKE SELECT ON accounts FROM test_role;"
# psql -U test_role -d test -c "SELECT * FROM accounts;"
test "${testcase}_deny" 'test_role' "$testcmd" 'true'
psql -U postgres -d test -c "GRANT SELECT ON accounts TO test_role;"
# psql -U test_role -d test -c "SELECT * FROM accounts;"
test "${testcase}_allow" 'test_role' "$testcmd" 'true'

## update table
testcmd="UPDATE accounts SET username='testuser2' where username='testuser2u'"
testcase="table_update"
psql -U postgres -d test -c "REVOKE UPDATE ON accounts FROM test_role;"
# psql -U test_role -d test -c "UPDATE accounts SET username='testuser2' where username='testuser2u'"
test "${testcase}_deny" 'test_role' "$testcmd" 'true'
psql -U postgres -d test -c "GRANT UPDATE ON accounts TO test_role;"
# psql -U test_role -d test -c "UPDATE accounts SET username='testuser2' where username='testuser2u'"
test "${testcase}_allow" 'test_role' "$testcmd" 'true'

## delete table
testcmd="DELETE FROM accounts where username='testuser2u'"
testcase="table_delete"
psql -U postgres -d test -c "REVOKE DELETE ON accounts FROM test_role;"
# psql -U test_role -d test -c "DELETE FROM accounts where username='testuser2u'"
test "${testcase}_deny" 'test_role' "$testcmd" 'true'
psql -U postgres -d test -c "GRANT DELETE ON accounts TO test_role;"
# psql -U test_role -d test -c "DELETE FROM accounts where username='testuser2u'"
test "${testcase}_allow" 'test_role' "$testcmd" 'true'

## truncate table
testcmd="TRUNCATE accounts;"
testcase="table_truncate"
psql -U postgres -d test -c "REVOKE TRUNCATE ON accounts FROM test_role;"
# psql -U test_role -d test -c "TRUNCATE accounts;"
test "${testcase}_deny" 'test_role' "$testcmd" 'true'
psql -U postgres -d test -c "GRANT TRUNCATE ON accounts TO test_role;"
# psql -U test_role -d test -c "TRUNCATE accounts;"
test "${testcase}_allow" 'test_role' "$testcmd" 'true'

## reference table
testcmd="CREATE TABLE contacts (
                                contact_id serial PRIMARY KEY,
                                user_id INT,
                                CONSTRAINT fk_account
                                    FOREIGN KEY(user_id) 
	                                REFERENCES accounts(user_id)
                                ); "
testcase="table_reference"
psql -U postgres -d test -c "REVOKE REFERENCES ON accounts FROM test_role;"
# psql -U test_role -d test -c "CREATE TABLE contacts (
#                                 contact_id serial PRIMARY KEY,
#                                 user_id INT,
#                                 CONSTRAINT fk_account
#                                     FOREIGN KEY(user_id) 
# 	                                REFERENCES accounts(user_id)
#                                 ); "
test "${testcase}_deny" 'test_role' "$testcmd" 'true'
psql -U postgres -d test -c "GRANT REFERENCES ON accounts TO test_role;"
# psql -U test_role -d test -c "CREATE TABLE contacts (
#                                 contact_id serial PRIMARY KEY,
#                                 user_id INT,
#                                 CONSTRAINT fk_account
#                                     FOREIGN KEY(user_id) 
# 	                                REFERENCES accounts(user_id)
#                                 ); "
test "${testcase}_allow" 'test_role' "$testcmd" 'true'

## trigger on table
testcmd="CREATE OR REPLACE TRIGGER check_update
    BEFORE UPDATE ON accounts
    FOR EACH ROW
    EXECUTE FUNCTION check_account();"
testcase="table_trigger"
psql -U test_role -d test -c "
    CREATE OR REPLACE FUNCTION check_account() 
    RETURNS TRIGGER 
    LANGUAGE PLPGSQL
    AS
    \$\$
    BEGIN
        RETURN NEW;
    END;
    \$\$"
psql -U postgres -d test -c "REVOKE TRIGGER ON accounts FROM test_role;"
# psql -U test_role -d test -c "CREATE OR REPLACE TRIGGER check_update
#     BEFORE UPDATE ON accounts
#     FOR EACH ROW
#     EXECUTE FUNCTION check_account();"
test "${testcase}_deny" 'test_role' "$testcmd" 'true'
psql -U postgres -d test -c "GRANT TRIGGER ON accounts TO test_role;"
# psql -U test_role -d test -c "CREATE OR REPLACE TRIGGER check_update
#     BEFORE UPDATE ON accounts
#     FOR EACH ROW
#     EXECUTE FUNCTION check_account();"
test "${testcase}_allow" 'test_role' "$testcmd" 'true'


# table column
## insert table column
testcmd="INSERT INTO accounts (username, age) VALUES('testuser4', 20)"
testcase="table_column_insert"
psql -U postgres -d test -c "REVOKE INSERT(user_id) ON accounts FROM test_role;"
# psql -U test_role -d test -c "INSERT INTO accounts (username, age) VALUES('testuser4', 20)"
test "${testcase}_deny" 'test_role' "$testcmd" 'true'
psql -U postgres -d test -c "GRANT INSERT(user_id) ON accounts TO test_role;"
# psql -U test_role -d test -c "INSERT INTO accounts (username, age) VALUES('testuser4', 20)"
test "${testcase}_allow" 'test_role' "$testcmd" 'true'

## select column
testcmd="SELECT username from accounts"
testcase="table_column_select"
psql -U postgres -d test -c "REVOKE SELECT(username) ON accounts FROM test_role;"
# psql -U test_role -d test -c "SELECT username from accounts"
test "${testcase}_deny" 'test_role' "$testcmd" 'true'
psql -U postgres -d test -c "GRANT SELECT(username) ON accounts TO test_role;"
# psql -U test_role -d test -c "SELECT username from accounts"
test "${testcase}_allow" 'test_role' "$testcmd" 'true'

## update table column
testcmd="UPDATE accounts SET age=20 where username='testuser4'"
testcase="table_column_update"
psql -U postgres -d test -c "REVOKE UPDATE(age) ON accounts FROM test_role;"
# psql -U test_role -d test -c "UPDATE accounts SET age=20 where username='testuser4'"
test "${testcase}_deny" 'test_role' "$testcmd" 'true'
psql -U postgres -d test -c "GRANT UPDATE(age) ON accounts TO test_role;"
# psql -U test_role -d test -c "UPDATE accounts SET age=20 where username='testuser4'"
test "${testcase}_allow" 'test_role' "$testcmd" 'true'

## reference table column TODO

# tablespace
## create on tablespace
testcmd="CREATE TABLE foo(i int) TABLESPACE fastspace;"
testcase="tablespace_create"
psql -U postgres -d test -c "CREATE TABLESPACE fastspace LOCATION '/home/postgres/';"
psql -U postgres -d test -c "REVOKE CREATE ON TABLESPACE fastspace FROM test_role;"
# psql -U test_role -d test -c "CREATE TABLE foo(i int) TABLESPACE fastspace;"
test "${testcase}_deny" 'test_role' "$testcmd" 'true'
psql -U postgres -d test -c "GRANT CREATE ON TABLESPACE fastspace TO test_role;"
# psql -U test_role -d test -c "CREATE TABLE foo(i int) TABLESPACE fastspace;"
test "${testcase}_allow" 'test_role' "$testcmd" 'true'

# type TODO

pg_ctl -D /usr/local/pgsql/data -l logfile stop
sleep 2