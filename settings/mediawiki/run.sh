#!/bin/bash

# exit on error
set -e

### This scripts installs mediawiki and run our tests.
# we assume mediawiki exists in /acl_test/app/mediawiki/mediawiki

# mount_overlay source overlay target
mount_overlay () {
	mkdir -p $2 && \
	mount -t tmpfs tmpfs $2 && \
	mkdir -p $2/{upper,work} && \
	mount -t overlay overlay -o lowerdir=$1,upperdir=$2/upper,workdir=$2/work $3
}

# compile. This is our webserver we use.
cd "/acl_test/app/httpd-2.4.46"

prefix=/usr/local/apache2

#CC="gcc -pg" CFLAGS="-O0" ./configure --with-included-apr --with-mpm=prefork
#make
make install

## install mediawiki
mkdir -p /usr/local/apache2/htdocs
mount_overlay /tmp/htdocs /tmp/overlay_htdocs /usr/local/apache2/htdocs

# copy over configs and modules
cp -r /tmp/conf/ /usr/local/apache2/config
cp /tmp/modules/* /usr/local/apache2/modules

## start server using our config
${prefix}/bin/apachectl -f /usr/local/apache2/config/httpd.conf

echo "--------- do your workload here -------------"

## do protection changes here.
python3 /acl_test/randomizer/mediawiki_randomizer.py \
	-d /acl_test/data/mediawiki/cowiki-20210401-pages-meta-history.xml \
	-o /acl_test/results/cowiki/protection_changes.txt

DATA_FILES="/acl_test/data/mediawiki/segment_data/*"
SAVE_FILE="/acl_test/results/cowiki/randomized_protection_changes.csv"

start=`date +%s`
# Run multiple jobs in parallel.
#for file in $DATA_FILES
#do
#    echo "=== start job: $file ==="
#	python3 /acl_test/replay/replay_co_mediawiki_hc.py \
#		-f $file \
#		-o $SAVE_FILE \
#		&
#    echo "=== complete job: $file ==="
#done
end=`date +%s`

runtime=$((end-start))

echo "Start time: ${start}"
echo "End time: ${end}"
echo "Total replay runtime: ${runtime}"

# keep the container running, so we can attach to it
echo "run 'sudo docker exec -it container_name zsh' to obtain a shell into the container"
tail -f /dev/null
#/bin/bash
