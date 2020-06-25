# coding: utf-8

import sys
import os
import mechanize
import time


def tryFollowLink(browser, link):
  try:
    response = browser.follow_link(link)
    assert response.code == 200, "response for " + link.url + " was " + response.code
    return response
  except:
    assert False, "Fail to follow link to : " + link.url

def setFormInput(form, input, val):
  form.find_control(input).value = val

APP_TEST_PORT = "80"

assert len(sys.argv) > 1, "no arguments"

APP_TEST_URL = sys.argv[1]

print("TEST_ULR=" + APP_TEST_URL)

br = mechanize.Browser()
br.set_handle_robots(False)
response = None
for _ in range(10):
  try:
    response = br.open(APP_TEST_URL)
    assert response.code == 200, "response code is not 200"
    assert br.title() == u'Welcome to wallabag! – wallabag', "title doesn't match"
  except:
    print("wating for 60 seconds before retrying again")
    time.sleep(60)

assert response != None, "fail to connect to the server"

tryFollowLink(br, br.find_link(text="Register"))

forms = list(br.forms())
assert len(forms) == 1, "registration form not found"
br.form = forms[0]
assert br.form.name == "fos_user_registration_form", "form fos_user_registration_form not found"

setFormInput(br.form, "fos_user_registration_form[email]", "user@localhost.lan")
setFormInput(br.form, "fos_user_registration_form[username]", "username")
setFormInput(br.form, "fos_user_registration_form[plainPassword][first]", "password")
setFormInput(br.form, "fos_user_registration_form[plainPassword][second]", "password")

response = br.submit()
assert response.code == 200, "response code is not 200"

tryFollowLink(br, br.find_link(text="Go to your account"))

assert response.code == 200, "response code is not 200"
assert br.title() == u'Quickstart – wallabag', "title doesn't match"
