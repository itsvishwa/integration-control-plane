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

import ballerina/ldap;
import ballerina/test;

// Test: entryDN (OpenLDAP, ApacheDS, 389 DS) is used as the user DN
@test:Config {}
function testGetDNFromEntryUsesEntryDN() {
    ldap:Entry entry = {"entryDN": "cn=ldapadmin,ou=users,dc=wso2,dc=org"};
    test:assertEquals(getDNFromEntry(entry), "cn=ldapadmin,ou=users,dc=wso2,dc=org");
}

// Test: distinguishedName (Active Directory) is used as the user DN
@test:Config {}
function testGetDNFromEntryUsesDistinguishedName() {
    ldap:Entry entry = {"distinguishedName": "CN=John Doe,OU=Users,DC=corp,DC=example,DC=com"};
    test:assertEquals(getDNFromEntry(entry), "CN=John Doe,OU=Users,DC=corp,DC=example,DC=com");
}

// Test: attribute names are matched case-insensitively
@test:Config {}
function testGetDNFromEntryIsCaseInsensitive() {
    ldap:Entry entry = {"entrydn": "uid=jdoe,ou=people,ou=eng,dc=example,dc=com"};
    test:assertEquals(getDNFromEntry(entry), "uid=jdoe,ou=people,ou=eng,dc=example,dc=com");
}

// Test: a multi-valued DN attribute uses its first value
@test:Config {}
function testGetDNFromEntryMultiValued() {
    ldap:Entry entry = {"entryDN": ["cn=first,dc=example,dc=com", "cn=second,dc=example,dc=com"]};
    test:assertEquals(getDNFromEntry(entry), "cn=first,dc=example,dc=com");
}

// Test: the DN is returned unchanged, keeping an escaped trailing space (RFC 4514)
@test:Config {}
function testGetDNFromEntryKeepsEscapedTrailingSpace() {
    ldap:Entry entry = {"entryDN": "cn=jdoe,ou=users,o=Example\\ "};
    test:assertEquals(getDNFromEntry(entry), "cn=jdoe,ou=users,o=Example\\ ");
}

// Test: no DN attribute (or a blank one) returns nil so the caller falls back
@test:Config {}
function testGetDNFromEntryMissingOrBlank() {
    test:assertEquals(getDNFromEntry({}), ());
    test:assertEquals(getDNFromEntry({"uid": "jdoe"}), ());
    test:assertEquals(getDNFromEntry({"entryDN": "  "}), ());
}
