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

import ballerina/test;
import icp_server.storage;
import icp_server.types;

// The five MI artifact types whose management API accepts a status change.
@test:Config {
    groups: ["artifact-status-support"]
}
function testStatusChangeSupportedTypes() {
    string[] supported = [
        "proxy-service",
        "endpoint",
        "message-processor",
        "task",
        "inbound-endpoint"
    ];
    foreach string artifactType in supported {
        test:assertTrue(storage:supportsStatusChange(artifactType),
                string `'${artifactType}' supports a status change and must be accepted`);
    }
}

// api and sequence expose only trace/statistics, and template exposes neither. Dispatching a
// status change for these reports SUCCESS while MI rejects it, so they must be refused up front.
@test:Config {
    groups: ["artifact-status-support"]
}
function testStatusChangeUnsupportedTypes() {
    string[] unsupported = ["api", "sequence", "template"];
    foreach string artifactType in unsupported {
        test:assertFalse(storage:supportsStatusChange(artifactType),
                string `'${artifactType}' does not support a status change and must be rejected`);
    }
}

// An artifact type that is not a management-API type at all must also be refused, rather than
// falling through to a dispatch that silently does nothing.
@test:Config {
    groups: ["artifact-status-support"]
}
function testStatusChangeRejectsUnknownType() {
    test:assertFalse(storage:supportsStatusChange("not-an-artifact-type"),
            "An unknown artifact type must be rejected");
    test:assertFalse(storage:supportsStatusChange(""),
            "An empty artifact type must be rejected");
}

// getManagementPath lowercases and trims before matching, so the predicate must agree.
@test:Config {
    groups: ["artifact-status-support"]
}
function testStatusChangeSupportIsCaseAndSpaceInsensitive() {
    test:assertTrue(storage:supportsStatusChange("  Proxy-Service  "),
            "Surrounding space and mixed case must not change the verdict for a supported type");
    test:assertFalse(storage:supportsStatusChange("  API  "),
            "Surrounding space and mixed case must not change the verdict for an unsupported type");
}

// Normalization is what the resolver persists and echoes back, so it must reduce a type to the
// exact spelling getManagementPath matches on.
@test:Config {
    groups: ["artifact-status-support"]
}
function testNormalizeArtifactType() {
    test:assertEquals(storage:normalizeArtifactType("  Proxy-Service  "), "proxy-service",
            "Normalization should trim and lowercase");
    test:assertEquals(storage:normalizeArtifactType("API"), "api",
            "Normalization should lowercase");
    test:assertEquals(storage:normalizeArtifactType("proxy-service"), "proxy-service",
            "An already-canonical type should be unchanged");
}

// The rejection message names the types a caller can actually use.
@test:Config {
    groups: ["artifact-status-support"]
}
function testStatusChangeSupportedTypesText() {
    string listed = storage:statusChangeSupportedTypes();
    foreach string artifactType in ["proxy-service", "endpoint", "message-processor", "task",
            "inbound-endpoint"] {
        test:assertTrue(listed.includes(artifactType),
                string `The supported-type list should name '${artifactType}', got: ${listed}`);
    }
    test:assertFalse(listed.includes("template"),
            string `The supported-type list must not name 'template', got: ${listed}`);
}

// The message and the accept/reject decision must not be able to disagree: every type the
// message names must be accepted, and no type it omits may be. This is what stops the listed
// set going stale if the management-path match arms change.
@test:Config {
    groups: ["artifact-status-support"]
}
function testSupportedTypesTextAgreesWithDecision() {
    string listed = storage:statusChangeSupportedTypes();
    string[] namedTypes = re `,\s*`.split(listed);
    foreach string artifactType in namedTypes {
        test:assertTrue(storage:supportsStatusChange(artifactType),
                string `The message names '${artifactType}' but it is not accepted`);
    }
    string[] allKnownTypes = [
        "proxy-service",
        "endpoint",
        "message-processor",
        "task",
        "inbound-endpoint",
        "api",
        "template",
        "sequence"
    ];
    foreach string artifactType in allKnownTypes {
        if storage:supportsStatusChange(artifactType) {
            test:assertTrue(namedTypes.indexOf(artifactType) is int,
                    string `'${artifactType}' is accepted but the message does not name it`);
        }
    }
}

// The storage-level tests above cannot tell where the guard sits. This drives the mutation
// itself, so deleting the guard or moving it below reconciliation fails here: the resolver
// would answer SUCCESS and leave a desired-state row behind.
@test:Config {
    groups: ["artifact-status-support"]
}
function testUpdateArtifactStatusRejectsUnsupportedTypeAtResolver() returns error? {
    string mutation = string `
        mutation {
            updateArtifactStatus(input: {
                componentId: "${COMPONENT_1_ID}",
                artifactType: "api",
                artifactName: "ResolverGuardTestApi",
                status: DISABLED
            }) {
                status
                message
                successCount
                failedCount
            }
        }
    `;

    json response = check executeGraphQL(mutation, orgDevToken);
    test:assertFalse(response.errors is json, "The mutation should answer, not error");

    json result = check response.data.updateArtifactStatus;
    test:assertEquals(check result.status, "FAILED",
            "An unsupported artifact type must be reported as FAILED");
    test:assertEquals(check result.successCount, 0, "No runtime should be counted as updated");
    test:assertEquals(check result.failedCount, 0,
            "Nothing was dispatched, so nothing should be counted as failed");
    string message = check result.message;
    test:assertTrue(message.includes("not supported"),
            string `The message should say the type is unsupported, got: ${message}`);
    test:assertTrue(message.includes("proxy-service"),
            string `The message should name the supported types, got: ${message}`);

    // The guard has to run before anything is persisted, so no desired state may exist.
    types:ReconcileArtifactKey artifact = {
        artifactName: "ResolverGuardTestApi",
        artifactType: "api"
    };
    map<string> desired = check storage:readReconcileDesiredState(COMPONENT_1_ID, DEV_ENV_ID, artifact);
    test:assertEquals(desired.length(), 0,
            "A rejected status change must not write desired state");
}

// A supported type must still reach reconciliation, so the guard cannot be widened into
// rejecting everything.
@test:Config {
    groups: ["artifact-status-support"]
}
function testUpdateArtifactStatusAcceptsSupportedTypeAtResolver() returns error? {
    string mutation = string `
        mutation {
            updateArtifactStatus(input: {
                componentId: "${COMPONENT_1_ID}",
                artifactType: "proxy-service",
                artifactName: "ResolverGuardTestProxy",
                status: DISABLED
            }) {
                status
                message
            }
        }
    `;

    json response = check executeGraphQL(mutation, orgDevToken);
    test:assertFalse(response.errors is json, "The mutation should answer, not error");
    string message = check response.data.updateArtifactStatus.message;
    test:assertFalse(message.includes("not supported"),
            string `A supported type must not be rejected by the guard, got: ${message}`);
}

// Desired state written before artifact types were normalized sits under the literal string the
// caller sent. Writing the canonical key without folding those rows in would leave both, and
// heartbeat replay would keep dispatching the stale one to the same artifact.
@test:Config {
    groups: ["artifact-status-support"]
}
function testMigrateLegacyArtifactTypeKeys() returns error? {
    string artifactName = "LegacyKeyMigrationProxy";
    types:ReconcileArtifactKey legacyKey = {artifactName: artifactName, artifactType: "  Proxy-Service  "};
    types:ReconcileArtifactKey canonicalKey = {artifactName: artifactName, artifactType: "proxy-service"};

    // A legacy row carrying a status the canonical key will also set, and a tracing value it
    // will not, so both the collision and the carry-over are exercised.
    check storage:upsertReconcileDesiredState(COMPONENT_1_ID, DEV_ENV_ID, legacyKey,
            {"status": "enabled", "tracing": "enabled"});
    check storage:upsertReconcileDesiredState(COMPONENT_1_ID, DEV_ENV_ID, canonicalKey,
            {"status": "disabled"});

    check storage:migrateLegacyArtifactTypeKeys(COMPONENT_1_ID, DEV_ENV_ID, artifactName,
            "proxy-service");

    map<string> legacy = check storage:readReconcileDesiredState(COMPONENT_1_ID, DEV_ENV_ID, legacyKey);
    test:assertEquals(legacy.length(), 0, "The legacy key must be removed after migration");

    map<string> canonical = check storage:readReconcileDesiredState(COMPONENT_1_ID, DEV_ENV_ID, canonicalKey);
    test:assertEquals(canonical["status"], "disabled",
            "The value already on the canonical key must win the collision");
    test:assertEquals(canonical["tracing"], "enabled",
            "A state field only the legacy key carried must be preserved");
}

// Migration must be a no-op when nothing legacy exists, so the common path does not disturb
// state the caller is about to set.
@test:Config {
    groups: ["artifact-status-support"]
}
function testMigrateLegacyArtifactTypeKeysIsNoopWhenClean() returns error? {
    string artifactName = "NoLegacyKeyProxy";
    types:ReconcileArtifactKey canonicalKey = {artifactName: artifactName, artifactType: "proxy-service"};
    check storage:upsertReconcileDesiredState(COMPONENT_1_ID, DEV_ENV_ID, canonicalKey,
            {"status": "enabled"});

    check storage:migrateLegacyArtifactTypeKeys(COMPONENT_1_ID, DEV_ENV_ID, artifactName,
            "proxy-service");

    map<string> canonical = check storage:readReconcileDesiredState(COMPONENT_1_ID, DEV_ENV_ID, canonicalKey);
    test:assertEquals(canonical["status"], "enabled",
            "Migration must not disturb the canonical key when there is nothing to migrate");
}

// The console sends kebab-case, but MI and the console display PascalCase names, and direct API
// callers use either. Every spelling of a type must reach the one canonical form, or a mutation
// rejects or silently drops a change for a type it supports.
@test:Config {
    groups: ["artifact-status-support"]
}
function testNormalizeArtifactTypeAcceptsEverySpelling() {
    map<string> expected = {
        "ProxyService": "proxy-service",
        "proxyservice": "proxy-service",
        "PROXY_SERVICE": "proxy-service",
        "InboundEndpoint": "inbound-endpoint",
        "inbound_endpoint": "inbound-endpoint",
        "MessageProcessor": "message-processor",
        "RestApi": "api",
        "rest-api": "api",
        " Sequence ": "sequence",
        "LocalEntry": "local-entry"
    };
    foreach [string, string] [raw, canonical] in expected.entries() {
        test:assertEquals(storage:normalizeArtifactType(raw), canonical,
                string `'${raw}' should normalize to '${canonical}'`);
    }
    test:assertEquals(storage:normalizeArtifactType("  Not-A-Type "), "not-a-type",
            "An unknown type should only be trimmed and lowercased, so it can be rejected by name");
}

// Trace and statistics are accepted for exactly the types MI's management API supports them on.
@test:Config {
    groups: ["artifact-status-support"]
}
function testTraceAndStatisticsSupportedTypes() {
    foreach string artifactType in ["proxy-service", "endpoint", "inbound-endpoint", "api", "sequence",
            "template", "ProxyService", "RestApi"] {
        test:assertTrue(storage:supportsTraceAndStatistics(artifactType),
                string `'${artifactType}' supports trace and statistics and must be accepted`);
    }
    foreach string artifactType in ["message-processor", "task", "local-entry", "not-a-type", ""] {
        test:assertFalse(storage:supportsTraceAndStatistics(artifactType),
                string `'${artifactType}' does not support trace or statistics and must be rejected`);
    }
}

// What the mutations accept and what dispatch can send must be the same set. A type accepted with
// no request behind it is the "SUCCESS but nothing changed" failure; the reverse is a type that
// dispatch could send but the mutations refuse.
@test:Config {
    groups: ["artifact-status-support"]
}
function testTraceAndStatisticsAcceptanceMatchesDispatch() {
    string[] actions = [types:ARTIFACT_ENABLE_TRACING, types:ARTIFACT_DISABLE_TRACING,
            types:ARTIFACT_ENABLE_STATISTICS, types:ARTIFACT_DISABLE_STATISTICS];
    foreach string artifactType in ["proxy-service", "endpoint", "message-processor", "task",
            "inbound-endpoint", "api", "template", "sequence", "local-entry", "ProxyService", "proxyservice"] {
        boolean accepted = storage:supportsTraceAndStatistics(artifactType);
        foreach string action in actions {
            test:assertEquals(storage:miControlRequest(artifactType, "a1", action) is [string, json], accepted,
                    string `Acceptance and dispatch disagree for '${artifactType}' (${action})`);
        }
    }
    string listed = storage:traceAndStatisticsSupportedTypes();
    foreach string artifactType in re `,\s*`.split(listed) {
        test:assertTrue(storage:supportsTraceAndStatistics(artifactType),
                string `The message names '${artifactType}' but it is not accepted`);
    }
}

// MI refuses a template trace change without the template's type ("Unsupported operation").
@test:Config {
    groups: ["artifact-status-support"]
}
function testTemplateTracingRequestCarriesType() {
    test:assertEquals(storage:miControlRequest("Template", "t1", types:ARTIFACT_ENABLE_TRACING),
            ["/management/templates", {name: "t1", "type": "sequence", trace: "enable"}]);
    test:assertEquals(storage:miControlRequest("ProxyService", "p1", types:ARTIFACT_ENABLE_TRACING),
            ["/management/proxy-services", {name: "p1", trace: "enable"}]);
}

// The tracing mutation used to answer SUCCESS for a type it could not dispatch and keep the
// change as desired state that warned on every reconcile pass. It must now refuse up front.
@test:Config {
    groups: ["artifact-status-support"]
}
function testUpdateArtifactTracingRejectsUnsupportedTypeAtResolver() returns error? {
    string mutation = string `
        mutation {
            updateArtifactTracingStatus(input: {
                componentId: "${COMPONENT_1_ID}",
                environmentId: "${DEV_ENV_ID}",
                artifactType: "task",
                artifactName: "TracingGuardTestTask",
                trace: ENABLED
            }) {
                status
                message
                successCount
                failedCount
            }
        }
    `;

    json response = check executeGraphQL(mutation, orgDevToken);
    test:assertFalse(response.errors is json, "The mutation should answer, not error");
    json result = check response.data.updateArtifactTracingStatus;
    test:assertEquals(check result.status, "FAILED", "An unsupported artifact type must be reported as FAILED");
    test:assertEquals(check result.successCount, 0, "No runtime should be counted as updated");
    string message = check result.message;
    test:assertTrue(message.includes("not supported") && message.includes("proxy-service"),
            string `The message should say the type is unsupported and name the supported ones, got: ${message}`);

    map<string> desired = check storage:readReconcileDesiredState(COMPONENT_1_ID, DEV_ENV_ID,
            {artifactName: "TracingGuardTestTask", artifactType: "task"});
    test:assertEquals(desired.length(), 0, "A rejected tracing change must not write desired state");
}

// The statistics mutation used to normalize "ProxyService" to "proxyservice" and then reject it
// against a list naming "ProxyService". It must accept it, and answer an unsupported type in the
// same FAILED form as the other two mutations rather than as a GraphQL error.
@test:Config {
    groups: ["artifact-status-support"]
}
function testUpdateArtifactStatisticsTypeHandlingAtResolver() returns error? {
    [string, boolean][] cases = [["ProxyService", true], ["message-processor", false]];
    foreach [string, boolean] [artifactType, supported] in cases {
        string mutation = string `
            mutation {
                updateArtifactStatisticsStatus(input: {
                    componentId: "${COMPONENT_1_ID}",
                    environmentId: "${DEV_ENV_ID}",
                    artifactType: "${artifactType}",
                    artifactName: "StatisticsGuardTestArtifact",
                    statistics: ENABLED
                }) {
                    status
                    message
                }
            }
        `;
        json response = check executeGraphQL(mutation, orgDevToken);
        test:assertFalse(response.errors is json,
                string `The mutation should answer, not error, for '${artifactType}'`);
        string message = check response.data.updateArtifactStatisticsStatus.message;
        test:assertEquals(message.includes("not supported"), !supported,
                string `Unexpected verdict for '${artifactType}', got: ${message}`);
    }
}

// The PascalCase spelling the beta stored as "proxyservice" cannot be matched by lowercasing, so
// migration must group spellings by normalization rather than by LOWER(TRIM(...)).
@test:Config {
    groups: ["artifact-status-support"]
}
function testMigrateLowercasedPascalCaseKey() returns error? {
    string artifactName = "LowercasedPascalCaseProxy";
    types:ReconcileArtifactKey legacyKey = {artifactName: artifactName, artifactType: "proxyservice"};
    types:ReconcileArtifactKey canonicalKey = {artifactName: artifactName, artifactType: "proxy-service"};
    check storage:upsertReconcileDesiredState(COMPONENT_1_ID, DEV_ENV_ID, legacyKey, {"tracing": "enabled"});

    check storage:migrateLegacyArtifactTypeKeys(COMPONENT_1_ID, DEV_ENV_ID, artifactName, "proxy-service");

    map<string> legacy = check storage:readReconcileDesiredState(COMPONENT_1_ID, DEV_ENV_ID, legacyKey);
    test:assertEquals(legacy.length(), 0, "The 'proxyservice' key must be removed after migration");
    map<string> canonical = check storage:readReconcileDesiredState(COMPONENT_1_ID, DEV_ENV_ID, canonicalKey);
    test:assertEquals(canonical["tracing"], "enabled", "The tracing value must move to the canonical key");
}

// Rows an earlier version stored but could never dispatch are repaired at startup: a spelling
// that resolves is folded into the canonical key, and a field no runtime can apply is removed.
// BI desired state is not MI's to normalize and must be left alone.
@test:Config {
    groups: ["artifact-status-support"]
}
function testRepairMIDesiredState() returns error? {
    string miComponentId = check storage:resolveOrCreateComponent(PROJECT_1_ID, "repair-mi-desired-state",
            "MI", SUPER_ADMIN_USER_ID);
    types:ReconcileArtifactKey pascalKey = {artifactName: "RepairProxy", artifactType: "proxyservice"};
    types:ReconcileArtifactKey taskKey = {artifactName: "RepairTask", artifactType: "task"};
    types:ReconcileArtifactKey unknownKey = {artifactName: "RepairUnknown", artifactType: "not-a-type"};
    types:ReconcileArtifactKey biKey = {artifactName: "RepairBiService", artifactType: "Service"};
    check storage:upsertReconcileDesiredState(miComponentId, DEV_ENV_ID, pascalKey, {"tracing": "enabled"});
    check storage:upsertReconcileDesiredState(miComponentId, DEV_ENV_ID, taskKey,
            {"status": "disabled", "tracing": "enabled"});
    check storage:upsertReconcileDesiredState(miComponentId, DEV_ENV_ID, unknownKey, {"statistics": "enabled"});
    check storage:upsertReconcileDesiredState(COMPONENT_1_ID, DEV_ENV_ID, biKey, {"status": "enabled"});

    check storage:repairMIDesiredState();

    map<string> pascal = check storage:readReconcileDesiredState(miComponentId, DEV_ENV_ID, pascalKey);
    test:assertEquals(pascal.length(), 0, "The 'proxyservice' key must be folded away");
    map<string> canonical = check storage:readReconcileDesiredState(miComponentId, DEV_ENV_ID,
            {artifactName: "RepairProxy", artifactType: "proxy-service"});
    test:assertEquals(canonical, {"tracing": "enabled"}, "The tracing change must survive under 'proxy-service'");

    map<string> task = check storage:readReconcileDesiredState(miComponentId, DEV_ENV_ID, taskKey);
    test:assertEquals(task, {"status": "disabled"},
            "A task's status must be kept and its tracing, which MI refuses, removed");
    map<string> unknown = check storage:readReconcileDesiredState(miComponentId, DEV_ENV_ID, unknownKey);
    test:assertEquals(unknown.length(), 0, "An unknown artifact type's desired state must be removed");

    map<string> bi = check storage:readReconcileDesiredState(COMPONENT_1_ID, DEV_ENV_ID, biKey);
    test:assertEquals(bi, {"status": "enabled"}, "BI desired state must not be touched");
}
