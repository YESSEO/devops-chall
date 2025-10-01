""" Selenium Script used for verifying Wazuh Dashboard & Wazuh API health Check"""

from os import getenv, path
from time import sleep

import sys
import json
import requests
import urllib3

from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.common.exceptions import TimeoutException

# Logging proccess
try :

    sys.path.append(path.join(path.dirname(__file__), "logger"))
    from loggerer import SimpleLogger

except (ModuleNotFoundError, NameError) as e:
    print("[ERROR] module is not found or failed to import")
    sys.exit(1)

debug = getenv("DEBUG")


class SeleniumTest:
    """Selenium & API some Test for Wazuh Dashboard, API health Check"""

    def __init__(self, driver_path):
        # Dashboard
        self.wazuh_url  =  getenv("WAZUH_URL")
        self.wazuh_user = getenv("WAZUH_USER")
        self.wazuh_pass = getenv("WAZUH_PASS")
        # Incase there's already a token generated
        self.auth_token = getenv("API_TOKEN")

        # API
        self.api_url  =  getenv("API_URL")
        self.api_user = getenv("API_USER")
        self.api_pass = getenv("API_PASS")

        # Log
        log_file = path.join(path.dirname(__file__), "heath_check.log")
        self.log = SimpleLogger(log_file, __file__)

        # Init Drivers
        options = Options()
        options.add_argument("--headless")       # run without GUI
        options.add_argument("--no-sandbox")     # raw CPU run
        options.add_argument("--disable-dev-shm-usage")
        options.add_argument("--ignore-certificate-errors")

        self.driver = webdriver.Chrome(service=Service(driver_path), options=options)

    def test_login_form_present(self, timeout=10) -> bool:
        """Verify the login form exists and page title is correct"""

        if not self.wazuh_url:
            print("[ERROR] url invalid or not suplied")
            self.log.write_log("CRITICAL", "Invalid url suplied")
            return False

        self.driver.get(self.wazuh_url)

        # Check Title
        title = self.driver.title
        if "Wazuh" not in title:
            self.log.write_log("ERROR", "Title not found")
            print("Wazuh title not detected")
            return False
    
        # Dashboard is initilising
        if title == ''  and self.driver.page_source == 'Wazuh dashboard server is not ready yet':
            res = requests.get(self.wazuh_url, timeout=100, verify=False)
            if res == 'Wazuh dashboard server is not ready yet':
                self.log.write_log("ERROR", "Seomthing went wrong in the Dashboard deployment proccess")

        # Wait till the form is available
        try:
            dashboardform = WebDriverWait(self.driver, timeout=100).until(
                EC.element_to_be_clickable((By.CSS_SELECTOR,
                                            "[class='euiForm']"))
            )
        except TimeoutException as e :
            if debug:
                print(e)
            print("couldnt not find login")
            return False

        if title and dashboardform:
            self.log.write_log("INFO", "Dashboard, Title Found")
            print("[SUCCESS] Title, Dashboard found")
        return True


    def test_programamtic_login(self, timeout=10) -> bool:
        """User credentials to login and verify Dashboard"""

        if not all([self.wazuh_url, self.wazuh_user, self.wazuh_pass]):
            print("[ERROR] Missing WAZUH env variables ..")
            self.log.write_log("CRITICAL", "Missing Wazuh Env Variables")
            sys.exit(1)

        try:
            # Username
            username_field = WebDriverWait(self.driver, timeout).until(
                EC.visibility_of_element_located((By.CSS_SELECTOR,
                                                  "[aria-label='username_input']"))
            )
            # Password
            password_field = WebDriverWait(self.driver, timeout).until(
                EC.visibility_of_element_located((By.CSS_SELECTOR,"[aria-label='password_input']"))
            )
            # Log in
            login_button = WebDriverWait(self.driver, timeout).until(
                EC.element_to_be_clickable((By.CSS_SELECTOR, "[class='euiButton__text']"))
            )

            username_field.send_keys(self.wazuh_user)
            password_field.send_keys(self.wazuh_pass)

            # Wazuh blocks automated Dashboard submition, we used a click instead
            login_button.click()

            # Dashboard burger menu
            burger_button = WebDriverWait(self.driver, timeout).until(
                EC.visibility_of_element_located((By.CSS_SELECTOR,
                                                   "[data-test-subj='toggleNavButton']")))
            
            self.log.write_log("INFO", "Form Elements Found")

            # if the burger menu is visible it means we succusfully logged in
            if burger_button :
                self.log.write_log("INFO", "Dashboard Drop Down Menu Found")
                return True

        except TimeoutException as e:
            if debug:
                print(e)
            self.log.write_log("ERROR", "From Elements not found")
            return False
        return True


    def test_api_health(self):
        """Verify Wazuh api health check"""

        if not all([self.api_url, self.api_user, self.api_url]):
            print("[ERROR] Missing WAZUH API env variables ..")
            self.log.write_log("CRITICAL", "Missing WAzuh API Env Variables")
            sys.exit(1)

        # Disable SSL warning
        urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

        # request AUTH_TOKEN
        payload = (self.api_user, self.api_pass)
        res = requests.post(self.api_url + "/security/user/authenticate",
                            auth=payload, params={"raw": True}, verify=False, timeout=50)
        if res.status_code != 200:
            data = json.loads(res.text)
            if debug:
                self.log.write_log("DEBUG", f"TOKEN REQUEST: title {data['title']}, reason: {data['detail']}")
                print(f"\t[DEBUG], title {data['title']}, reason: {data['detail']}")
            return False

        if res.status_code == 200:
            self.auth_token = res.text
            print("\t[SUCCESS] Wazuh API AUTH_TOKEN obtained")
            self.log.write_log("INFO", " API TOKEN Found")
        return True


    def test_api_version(self):
        """Grabe api version"""

        if not self.auth_token:
            self.log.write_log("ERROR", "Missing Wazuh TOKEN")
            print("[ERROR] Missing AUTH_TOKEN")
            return False

        headers = {
            "Authorization": f"Bearer {self.auth_token}"
        }

        res = requests.get(self.api_url, headers=headers, verify=False, timeout=50)
        data = json.loads(res.text)
        if res.status_code != 200:
            if debug:
                print(f"\t[DEBUG] title {data['title']}, reason: {data['detail']}")
                self.log.write_log("ERROR", f"API_VERSION_REQUEST: title {data['title']}, reason: {data['detail']}")
            return False

        if res.status_code == 200:
            res_log = f"""\t[DEBUG] title : {data["data"]["title"]},
                API_VERSION: {data["data"]["api_version"]} Hostname: {data["data"]["hostname"]}
                License: {data["data"]["license_url"]}"""
            self.log.write_log("INFO", f"api_version_request: version: {data["data"]["api_version"]} hostname: {data["data"]["hostname"]} ")
            print(res_log)

        return True


def main():
    """ This global function to init the Test"""

    # TODO: Add a logs file
    # TODO: Check if Dashboard is in the Init proccess from ansible

    test = SeleniumTest("/usr/bin/chromedriver")

    checks = [
        ("Dashboard test", test.test_login_form_present),
        ("Loggin test", test.test_programamtic_login),
        ("api health, test", test.test_api_health),
        ("api version, test", test.test_api_version)
    ]

    for description, check in checks:
        if check():
            print(f"[SUCCESS] {description}")
        else:
            print(f"[FAIL] {description}")
            sys.exit(1)
    test.log.write_log("INFO", "Selenium Test Gracefulyl PASSED")
    test.log.write_log("", "-----------------------")
    print("[INFO] all checks pass")
if __name__ == '__main__':
    main()
