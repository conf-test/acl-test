'''
generate request traces by looping through all files and methods
'''

import os, sys, requests, time
from collections import defaultdict

# DEFAULT_REPLAY_OUTPUT = '/tmp/replay_tmp.txt'

def load(permfile):
    '''
    return
    'permissions', 'hardlinks', 'owner', 'group', 
    'size', 'month', 'day', 'time', 'file'
    '''
    perms = []
    dirname=''
    i=0
    for line in open(permfile):
        line = line.strip()
        if line == '':
            continue
        elif line[-1] == ':':
            dirname=line[1:-1]
            if not dirname:
                dirname = '/'
            #print('dir: ', dirname)
            continue

        words = line.split()
        if len(words)==9:
            if words[-1] == '.':
                words[-1] = dirname
            elif words[-1] == '..':
                words[-1] = os.path.join(dirname, '')
            else:
                words[-1] = os.path.join(dirname, words[-1])
            perms.append(words)
        elif len(words)>9:
            words[8:] = [' '.join(words[8:])]
            words[-1] = os.path.join(dirname, words[-1])
            perms.append(words)
        i+=1
    
    return perms

def gen_req(localip, remoteip, files, replay_logfile):
    fout = open(replay_logfile, 'w')
    status = defaultdict(int)
    idx = 0
    start = time.time()
    for row in files:
        if ',' in row[-1]: # skip some weird file name
            continue
        url = row[-1]
        full_url = 'http://'+remoteip + url
        for method in ['GET', 
                    #    'TRACE', 'PUT','PATCH', 'DELETE',
                    #    'POST', 'HEAD', 'OPTIONS',
                      ]:
            try:
                # res = requests.request(method, full_url, allow_redirects=False)
                # length = len(res.content)
                length = 0
                # status[res.status_code] += 1
                status = 0
                log = ','.join(map(str, [idx, method, localip, url, 
                                              status, status, 
                                              length]))
                if idx % 1000 == 0:
                    print('finish {} in {} seconds'.format(idx+1, time.time()-start))
                
            except:
                traceback.print_exc(file=sys.stdout)
                log = ','.join(map(str, [idx, method, localip, row[-1], 
                                              'Except', 'Except', 
                                              length]))
                print(log)
            finally:
                fout.write(log)
                fout.write('\n')
                idx += 1
    print('status: {}'.format(status))
    
if __name__ == '__main__':
    if len(sys.argv) < 5:
        print('usage: python gen_all_http_req_trace.py permfile localip remoteip outputfile')
        exit()
    permfile = sys.argv[1]
    localip = sys.argv[2].strip()
    remoteip = sys.argv[3].strip()
    outfile = sys.argv[4].strip()

    files=load(permfile)
    gen_req(localip, remoteip, files, outfile)