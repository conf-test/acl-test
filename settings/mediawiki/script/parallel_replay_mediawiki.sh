#
## usage: ./parallel_replay_mediawiki.sh [data_dir] [outfile]
##                                       ${2}       ${3}
#
#run_mediawiki_workload(){
##    python3 /acl_test/replay/replay_co_mediawiki.py \
##        -f /acl_test/data/mediawiki/segment_data/seg_${1}.xml \
##        -o /acl_test/results/cowiki/randomized_protection_changes.csv
#    python3 /acl_test/replay/replay_co_mediawiki.py \
#        -f ${1} \
#        -o ${2}
#}
#
#for i in ${2}
#do
#    # make sure to run this in the background.
#    echo "=== start job: ${i} ==="
#    run_mediawiki_workload ${i} ${3} &
#    echo "=== complete job: ${i} ==="
#done
#
## wait for all background processes to complete before returning
#wait
#echo "=== Completed replay ==="

DATA_FILES="../../../data/mediawiki/segment_data2/*"
#DATA_FILES="../../../data/mediawiki/segment_data3/*"
SAVE_FILE="../../../results/cowiki/replay_naive_trim_930.csv"
#SAVE_FILE="../../../results/cowiki/manual_trim_replay.csv"

# Run multiple jobs in parallel.
for file in $DATA_FILES
do
	echo "=== start job: $file ==="
	#nohup python3 ../../../replay/replay_co_mediawiki_hc.py \
	nohup python3 ../../../replay/replay_co_mediawiki_hc_nol.py \
		-f $file \
		-o $SAVE_FILE \
		&
done

