''' Adds user to database
'''

from bs4 import BeautifulSoup
import json
import requests

HOST_URL = 'http://localhost/index.php?title=Special:CreateAccount'
PORT = '80'
HTML_PARSER = 'html.parser'
DEFAULT_PASS = 'totoforyou'

USER_FILE = './sorted_out.uniq'


# create user

def create_user(username):
    s = requests.Session()
    res = s.get(HOST_URL)

    # Get the first form tag, and get the name of the last 'input' child from this form.

    createAccountToken = BeautifulSoup(res.text, HTML_PARSER).find('form').find_all('input')[-1]['value']
    #import pdb; pdb.set_trace()

    data = {
        'wpName': username,
        'wpPassword': DEFAULT_PASS,
        'retype': DEFAULT_PASS,
        'email': '',
        'realname': '',
        'wpCreateaccount': 'Create+your+account',
        'wpEditToken': '+\\',
        'title': 'Special:CreateAccount',
        'authAction': 'create',
        'force': '',
        'wpCreateaccountToken': createAccountToken
        }
    ## Set the configuration
    res = s.post(HOST_URL, data=data)
    print('{} -- {}'.format(res.status_code, username))
    #if res.status_code != '200':


if __name__ == '__main__':
    user_file = open(USER_FILE, 'r')
    for line in user_file.readlines():
        l = line.rstrip().split('|')
        username = ''.join(l[1:])
        #print(username)

        create_user(username)