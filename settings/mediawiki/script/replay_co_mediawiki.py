''' Replay traces for cowiki mediawiki
We replay each log

The only optimization we do is persist loggin credentials so users that make sequential revisions
to page will not have to reloggin.

TODO:
- speedup with multithreaded execution.
'''

from bs4 import BeautifulSoup

import argparse
import binascii
import copy
import mwxml
import os
import queue
import requests
import sys
import threading

MAX_NUM_THREADS = 50

DEFAULT_REPLAY_OUTPUT = '/tmp/replay_tmp.txt'
DEFAULT_PASS = 'totoforyou'
HTML_PARSER = 'html.parser'

def parse_args():
    parser = argparse.ArgumentParser()
    # required arguments
    parser.add_argument('-f', '--history_file', help='xml file to replay')
    parser.add_argument('-o', '--output', default=DEFAULT_REPLAY_OUTPUT, help='file to write replay output')
    return parser.parse_args()

def encode_multipart_formdata(fields):
    boundary = binascii.hexlify(os.urandom(16)).decode('ascii')

    body = (
        "".join("--%s\r\n"
                "Content-Disposition: form-data; name=\"%s\"\r\n"
                "\r\n"
                "%s\r\n" % (boundary, field, value)
                for field, value in fields.items()) +
        "--%s--\r\n" % boundary
    )

    content_type = "multipart/form-data; boundary=%s" % boundary

    return body, content_type

class Wiki_replayer:
    def __init__(self, base_url):
        self.base_url = base_url
        self.curr_user = ''
        self.s = None

    def replay_revision(self, revision):
        ''' Returns
            - result (res):
            - error (string): if error occured else None
        '''

        e = self._login(revision.user)
        if e != None: return None, e

        return self._page_edit(revision)

    ## --- hidden class functions ---
    
    def _login(self, user):
        ''' Login if user is not already logged in.
        Returns (string) error IF error ELSE None.
        '''

        # TODO: for now, login as anoynmous users and use current IP. requires modification for IP spoofing.
        if user.id == None:
            self.curr_user = user.text
            self.s = requests.Session()
            return

        # Already logged in.  XXX: maybe session state could be invalid?
        if self.curr_user == user.text:
            #print('no relog', end='')
            return
            
        self.curr_user = user.text
        self.s = requests.Session()

        login_url = self.base_url + '/index.php?title=Special:UserLogin'

        res = self.s.get(login_url)
        if res.status_code != 200:
            self._reset_login_state()
            return 'Error during login get for {}'.format(self.curr_user)

        # extract csrf_token : verify this correct
        login_token = BeautifulSoup(res.text, HTML_PARSER).find('form').find_all('input')[-1]['value']

        data = self._get_login_data(self.curr_user, DEFAULT_PASS, login_token)

        res = self.s.post(login_url, data=data)

        if res.status_code != 200:
            self._reset_login_state()
            return 'Error during login post for {}'.format(self.curr_user)
        
        return None

    def _page_edit(self, revision):
        ''' assumes user is already logged in.
        returns (res, error)
        '''
        # fetch edit page: contains meta data required to make revision POST.
        page_get_edit_url = self.base_url + '/index.php?title={}&action=edit'.format(revision.page.title)
        res = None
        try:
            res = self.s.get(page_get_edit_url)
        except:
            self._reset_login_state()
            return None, 'error with GET unk: {}'.format(sys.exc_info()[0])

        # error checks
        if res.status_code != 200:
            self._reset_login_state()
            return res, 'error with GET page-edit: {}'.format(revision)

        payload = {}
        # If write protection is enabled the get page will fail.

        pg = BeautifulSoup(res.text, HTML_PARSER)
        form = pg.find('form', {'id': 'editform'})

        if form == None:
            return None, 'edit not permitted for "{}" to page: {}'.format(self.curr_user, revision.page.title)

        self._add_metadata_from_form(payload, form)
        self._add_metadata_from_revision(payload, revision)

        # convert payload into 'content-disposition' type
        body, content_type = encode_multipart_formdata(payload)

        page_post_edit_url = self.base_url + '/index.php?title={}&action=submit'.format(revision.page.title)
        try:
            res = self.s.post(page_post_edit_url, headers={'content-Type': content_type}, data=str.encode(body))
        except:
            self._reset_login_state()
            return None, 'error with POST unk: {}'.format(sys.exc_info()[0])


        # error checks
        if res.status_code != 200:
            self._reset_login_state()
            return res, 'error with POST page-edit: {}'.format(revision)
        return res, None

    def _get_login_data(self, username, password, token):
        return {
            'wpName': username,
            'wpPassword': password,
            'wploginattempt': 'Log+in',
            'wpEditToken': '+\\',
            'title': 'Special:UserLogin',
            'authAction': 'login',
            'force': '',
            'wpLoginToken': token
        }

    def _add_metadata_from_form(self, payload, form):
        # TODO cleanup using dictionary mapping for key and default value.
        for f in form.find_all('input', {'type': 'hidden'}):
            name = f.get('name')
            if name == 'wpSection':
                if f.get('value') != None:
                    payload[name] = f.get('value')
                else:
                    payload[name] =  ''
            elif name == 'wpScrolltop':
                if f.get('value') != None:
                    payload[name] = f.get('value')
                else:
                    payload[name] =  0
            else:
                payload[name] = f.get('value')

    def _add_metadata_from_revision(self, payload, revision):
        payload['wpTextbox1'] = revision.text
        payload['wpSummary'] = revision.comment
        payload['wpSave'] = 'Save changes'

        # TODO: may need to update for anti spam checks.
        payload['wpAntispam'] = ''

    def _reset_login_state(self):
        self.curr_user = ''
        self.s = requests.Session()

## --- End Wiki_replayer class ---

def print_outfile(revision, res, e, outfile):
    ''' logfile format
    success:
        revision id, page_title, res.status
    error:
        revision id, page_title, error-msg
    '''

    # XXX: Note multithreaded writes to file take a very long time to propogate.
    # Said another way... if a thread writes to file you may not see it right away. maybe not for
    # another 2mins

    outfile.write('{}, {}'.format(revision.page.title, revision.id))

    if e == None and res != None:
        outfile.write(', {}\n'.format(res.status_code))
    elif e != None:
        outfile.write(', {}\n'.format(e))
    else:
        outfile.write(', {}\n'.format('Default: res and e were None; THIS SHOULD NOT HAPPEN!'))

# stub for holding job details.
class Job: pass

def do_job(job):
    print('Doing work for {}'.format(job.revisions[0].page.title))
    replayer = Wiki_replayer(job.base_url)
    for revision in job.revisions:

        # do replay
        res, e = replayer.replay_revision(revision)
        print_outfile(revision, res, e, job.outfile)


if __name__ == '__main__':
    args = parse_args()
    outfile = open(args.output, 'w')

    dump = mwxml.Dump.from_file(open(args.history_file, 'r'))

    q = queue.Queue()

    def worker():
        while True:
            job = q.get()
            do_job(job)
            q.task_done()

    for _ in range(MAX_NUM_THREADS):
        print('Start thread')
        threading.Thread(target=worker, daemon=True).start()

    for i, page in enumerate(dump):
        revisions = [revision for revision in page]
        job = Job()
        job.revisions = revisions
        job.outfile = outfile
        job.base_url = 'http://localhost'
        q.put(job)

    print("Waiting on join")
    # waiting for jobs to complete
    q.join()

    print('=== success ===')
