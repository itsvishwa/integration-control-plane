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
import ballerina/log;
import ballerina/sql;

// Initialized at module load time with resolved (decrypted) credentials.
final sql:Client dbClient = check createDbClient();

// Password of artifactsApiTrustStorePath, resolved (decrypted) at module load. Loading it
// here also checks that the truststore exists, so a mistyped path stops the server at
// startup instead of failing every management call with an opaque TLS error.
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
    if artifactsApiAllowInsecureTLS {
        log:printWarn("artifactsApiTrustStorePath is set, but artifactsApiAllowInsecureTLS is true in "
            + "[icp_server.storage]: artifact control and tracing calls skip certificate validation "
            + "and do not use the truststore");
    }
    return utils:resolveConfig(artifactsApiTrustStorePassword, secrets);
}
