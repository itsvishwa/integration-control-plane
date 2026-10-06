// Copyright (c) 2026, WSO2 LLC. (https://www.wso2.com).
//
// WSO2 LLC. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import icp_server.storage;

import ballerina/http;
import ballerina/test;

// A stand-in for an MI management API (or the gateway in front of it) whose certificate is
// issued by an internal CA that the JVM's default truststore does not know. The truststore
// tests/Config.toml points artifactsApiTrustStorePath at holds only that CA.
const int MI_INTERNAL_CA_PORT = 9471;
const string MI_INTERNAL_CA_BASE_URL = "https://localhost:9471";

listener http:Listener miInternalCaListener = new (MI_INTERNAL_CA_PORT, {
    secureSocket: {
        key: {path: "tests/resources/keys/mi_internal_ca_server.p12", password: "changeit"}
    }
});

service /management on miInternalCaListener {
    resource function get apis() returns json => {count: 0, list: []};
}

// Without the setting, the verifying client checks the JVM's default truststore and rejects
// the internal CA — the failure reported in wso2/product-integrator#2121.
@test:Config {
    groups: ["mi-management-tls"]
}
function testManagementCallRejectsInternalCaByDefault() {
    http:Client|error mgmtClient = new (MI_INTERNAL_CA_BASE_URL);
    if mgmtClient is error {
        test:assertFail(string `client creation failed: ${mgmtClient.message()}`);
    }
    json|error result = mgmtClient->get("/management/apis");
    if result !is http:ClientError {
        test:assertFail("a certificate from an unknown internal CA should fail the TLS handshake");
    }
    test:assertTrue(result.message().includes("SSL"), string `expected a TLS failure, got: ${result.message()}`);
}

// With artifactsApiTrustStorePath set and certificate validation on, the management client
// trusts the internal CA.
@test:Config {
    groups: ["mi-management-tls"]
}
function testManagementCallTrustsConfiguredTruststore() returns error? {
    http:ClientSecureSocket? secureSocket = storage:managementSecureSocket(false);
    test:assertTrue(secureSocket is http:ClientSecureSocket && secureSocket.cert !is (),
            "a configured truststore should be passed as secureSocket.cert");

    http:Client mgmtClient = check new (MI_INTERNAL_CA_BASE_URL, {secureSocket});
    json result = check mgmtClient->get("/management/apis");
    test:assertEquals(result, {count: 0, list: []});
}

// artifactsApiAllowInsecureTLS = true keeps its meaning: validation is off, truststore or not.
@test:Config {
    groups: ["mi-management-tls"]
}
function testInsecureTlsStillDisablesValidation() returns error? {
    http:ClientSecureSocket? secureSocket = storage:managementSecureSocket(true);
    test:assertTrue(secureSocket is http:ClientSecureSocket && !secureSocket.enable,
            "artifactsApiAllowInsecureTLS = true should disable certificate validation");

    http:Client mgmtClient = check new (MI_INTERNAL_CA_BASE_URL, {secureSocket});
    json result = check mgmtClient->get("/management/apis");
    test:assertEquals(result, {count: 0, list: []});
}
