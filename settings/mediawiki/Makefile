cnf ?= .env
include  $(cnf)
export $(shell sed 's/=.*//' $(cnf))

default: 
	@echo 'choose a target'

build_base:
	sudo docker build --tag operaimg/ubuntu_base:1.2 ../base

build: build_base
	sudo docker-compose build

run: 
	@test -s ${htdocs} || { echo "${htdocs} does not exist"; exit 1; }
	@test -s ${etc} || { echo "${etc} does not exist"; exit 1; }
	sudo rm -rf ${tmp_mysql}
	cp -r ${mysql} ${tmp_mysql}
	sudo docker-compose up

.PHONY: all test clean run
