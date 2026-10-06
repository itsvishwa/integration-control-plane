// Copyright (c) 2026, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
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

import icp_server.utils;

import ballerina/file;
import ballerina/jballerina.java;
import ballerina/log;
import ballerina/sql;

// Initialized at module load time with resolved (decrypted) credentials.
final sql:Client dbClient = check createDbClient();

// Password of artifactsApiTrustStorePath, resolved (decrypted) at module load. Loading it
// here also opens the truststore, so a mistyped path, a wrong password or a file that isn't
// a truststore stops the server at startup instead of failing every management call with an
// opaque TLS error.
final string resolvedArtifactsApiTrustStorePassword = check loadArtifactsApiTrustStore();

function createDbClient() returns sql:Client|error {
    string resolvedUser = check utils:resolveConfig(dbUser, secrets);
    string resolvedPassword = check utils:resolveConfig(dbPassword, secrets);
    DatabaseConnectionManager dbManager = check new (dbType, dbHost, dbPort, dbName, resolvedUser, resolvedPassword, dbUseTLS);
    return dbManager.getClient();
}

function loadArtifactsApiTrustStore() returns string|error {
    if artifactsApiTrustStorePath.trim() == "" {
        return "";
    }
    if !check file:test(artifactsApiTrustStorePath, file:EXISTS) {
        return error(string `artifactsApiTrustStorePath does not exist: ${artifactsApiTrustStorePath}`);
    }
    string password = check utils:resolveConfig(artifactsApiTrustStorePassword, secrets);
    check validateTrustStore(artifactsApiTrustStorePath, password);
    if artifactsApiAllowInsecureTLS {
        log:printWarn("artifactsApiTrustStorePath is set, but artifactsApiAllowInsecureTLS is true in "
            + "[icp_server.storage]: artifact control and tracing calls skip certificate validation "
            + "and do not use the truststore");
    }
    return password;
}

# Opens a truststore the way the HTTP client will, so a wrong password or a file that isn't a
# JKS/PKCS12 store is reported when it is configured rather than on the first management call.
#
# + path - path of the truststore
# + password - its resolved password
# + return - an error naming the truststore if it cannot be loaded
public isolated function validateTrustStore(string path, string password) returns error? {
    handle|error keyStore = loadKeyStore(newJavaFile(java:fromString(path)), toCharArray(java:fromString(password)));
    if keyStore is error {
        return error(string `artifactsApiTrustStorePath ${path} could not be loaded: ${keyStore.message()}`);
    }
}

// KeyStore.getInstance(File, char[]) detects JKS or PKCS12 and loads the store, failing on a
// wrong password or an unreadable/invalid file.
isolated function loadKeyStore(handle file, handle password) returns handle|error = @java:Method {
    name: "getInstance",
    'class: "java.security.KeyStore",
    paramTypes: ["java.io.File", {'class: "char", dimensions: 1}]
} external;

isolated function newJavaFile(handle path) returns handle = @java:Constructor {
    'class: "java.io.File",
    paramTypes: ["java.lang.String"]
} external;

isolated function toCharArray(handle str) returns handle = @java:Method {
    name: "toCharArray",
    'class: "java.lang.String"
} external;
