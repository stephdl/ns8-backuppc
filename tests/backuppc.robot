*** Settings ***
Documentation    BackupPC is published behind Traefik and protected by the web
...              server. The suite uses the basic authentication mode, so no
...              account provider is needed.
Library    SSHLibrary
Resource    api.resource

*** Variables ***
${CLUSTER_USER}     admin
${CLUSTER_PASSWORD}    Nethesis,1234
${TEST_HOST}        backuppc.ns8-ci.test
${AUTH_USER}        backupadmin
${AUTH_PASS}        Nethesis,1234

*** Keywords ***
Login to cluster-admin
    New Page    https://${NODE_ADDR}/cluster-admin/
    Fill Text    text="Username"    ${CLUSTER_USER}
    Click    button >> text="Continue"
    Fill Text    text="Password"    ${CLUSTER_PASSWORD}
    Click    button >> text="Log in"
    Wait For Elements State    css=#main-content    visible    timeout=10s

Fetch page
    [Documentation]    Fetch a page through Traefik with the basic credentials
    [Arguments]    ${path}    ${credentials}=${AUTH_USER}:${AUTH_PASS}    ${expected_rc}=0
    ${output}  ${rc} =    Execute Command
    ...    curl -fkL -u '${credentials}' -H "Host: ${TEST_HOST}" https://127.0.0.1${path}
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  ${expected_rc}
    RETURN    ${output}

*** Test Cases ***
Check if backuppc is installed correctly
    ${output}  ${rc} =    Execute Command    add-module ${IMAGE_URL} 1
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    &{output} =    Evaluate    ${output}
    Set Suite Variable    ${module_id}    ${output.module_id}

Check if backuppc can be configured
    # ldap_domain basic selects the web server's own authentication, so the
    # suite needs no user domain
    Run task    module/${module_id}/configure-module
    ...    {"host":"${TEST_HOST}","http2https":true,"lets_encrypt":false,"ldap_domain":"basic","auth_user":"${AUTH_USER}","auth_pass":"${AUTH_PASS}"}
    ...    decode_json=${FALSE}

Check if backuppc configuration reads back
    ${config} =    Run task    module/${module_id}/get-configuration    {}
    Should Be Equal    ${config}[host]    ${TEST_HOST}
    Should Be Equal    ${config}[ldap_domain]    basic

Check if the interface is served through Traefik
    ${page} =    Wait Until Keyword Succeeds    60s    5s    Fetch page    /
    Should Contain    ${page}    BackupPC

Check if the interface refuses a wrong password
    # curl exits 22 on the 401 that -f turns into a failure
    Fetch page    /    ${AUTH_USER}:wrong-password    22

Take screenshots of the module pages
    [Documentation]    Capture what cluster-admin shows, for the software center
    ...                entry. Tagged ui: the shared runner skips it unless
    ...                RUN_UI_TESTS is true, since it needs a browser.
    [Tags]    ui
    Import Library    Browser
    New Browser    chromium    headless=True
    New Context    ignoreHTTPSErrors=True    viewport={'width': 1280, 'height': 900}
    Login to cluster-admin
    Go To    https://${NODE_ADDR}/cluster-admin/#/apps/${module_id}
    Wait For Elements State    iframe >>> h2 >> text="Status"    visible    timeout=10s
    # The page fills itself from several tasks: let them land
    Sleep    5s
    Take Screenshot    filename=${OUTPUT DIR}/browser/screenshot/1._Status.png
    Go To    https://${NODE_ADDR}/cluster-admin/#/apps/${module_id}?page=settings
    Wait For Elements State    iframe >>> h2 >> text="Settings"    visible    timeout=10s
    Sleep    5s
    Take Screenshot    filename=${OUTPUT DIR}/browser/screenshot/2._Settings.png
    Go To    https://${NODE_ADDR}/cluster-admin/#/apps/${module_id}?page=about
    Wait For Elements State    iframe >>> h2 >> text="About"    visible    timeout=10s
    Sleep    5s
    Take Screenshot    filename=${OUTPUT DIR}/browser/screenshot/3._About.png
    Close Browser

Check if backuppc is removed correctly
    ${rc} =    Execute Command    remove-module --no-preserve ${module_id}
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0
