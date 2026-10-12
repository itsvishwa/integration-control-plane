/**
 * Copyright (c) 2026, WSO2 LLC. (https://www.wso2.com).
 *
 * WSO2 LLC. licenses this file to you under the Apache License,
 * Version 2.0 (the "License"); you may not use this file except
 * in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied. See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */

import { Button } from '@wso2/oxygen-ui';
import { Gauge, Globe, ShieldCheck } from '@wso2/oxygen-ui-icons-react';
import { useMemo, useState, type JSX } from 'react';
import type { EnvEndpoint } from '../../types/component';
import type { EnvCardNotification } from '../../types/integration';
import { toEndpointOptions } from '../../utils/endpoints';
import EndpointPoliciesDrawer from './EndpointPoliciesDrawer';
import EndpointSecurityDrawer from './EndpointSecurityDrawer';
import EndpointVisibilityDrawer from './EndpointVisibilityDrawer';
import * as styles from './endpointSettings.styles';

type EndpointSetting = 'visibility' | 'policies' | 'security';

interface EndpointSettingsActionsProps {
  componentId: string;
  projectId: string;
  versionId: string;
  /** Environment name (the RFC 1123 slug) — the BFF's `environmentName` path segment. */
  envName: string;
  /** Endpoints of this environment. */
  endpoints: EnvEndpoint[];
  /** Endpoint the drawers open on — the one selected on the env card. */
  activeEndpointName: string;
  /** Also offer Security. */
  showSecurity?: boolean;
  onNotify: (notification: EnvCardNotification) => void;
  /** Asks the env card to poll its deployment for a while, to follow any rollout a change starts. */
  requestPoll: () => void;
}

/**
 * Cloud per-endpoint gateway settings, side by side: Visibility, Policies and, when asked for,
 * Security. Renders only the buttons — the caller lays them out.
 */
export default function EndpointSettingsActions({ componentId, projectId, versionId, envName, endpoints, activeEndpointName, showSecurity = false, onNotify, requestPoll }: EndpointSettingsActionsProps): JSX.Element {
  const [openSetting, setOpenSetting] = useState<EndpointSetting | null>(null);
  const options = useMemo(() => toEndpointOptions(endpoints), [endpoints]);
  const close = () => setOpenSetting(null);

  return (
    <>
      <Button variant="text" size="small" startIcon={<Globe size={14} />} onClick={() => setOpenSetting('visibility')} sx={styles.textAction}>
        Visibility
      </Button>
      <Button variant="text" size="small" startIcon={<Gauge size={14} />} onClick={() => setOpenSetting('policies')} sx={styles.textAction}>
        Policies
      </Button>
      {showSecurity && (
        <Button variant="text" size="small" startIcon={<ShieldCheck size={14} />} onClick={() => setOpenSetting('security')} sx={styles.textAction}>
          Security
        </Button>
      )}

      <EndpointVisibilityDrawer
        open={openSetting === 'visibility'}
        onClose={close}
        componentId={componentId}
        projectId={projectId}
        versionId={versionId}
        envName={envName}
        endpoints={endpoints}
        activeEndpointName={activeEndpointName}
        onSaved={() => {
          requestPoll();
          onNotify({ text: 'Visibility updated', severity: 'success', detail: 'A redeployment has been initiated so the new visibility takes effect.' });
        }}
      />
      <EndpointPoliciesDrawer open={openSetting === 'policies'} onClose={close} componentName={componentId} envName={envName} endpoints={options} activeEndpointName={activeEndpointName} />
      {showSecurity && <EndpointSecurityDrawer open={openSetting === 'security'} onClose={close} componentName={componentId} envName={envName} endpoints={options} activeEndpointName={activeEndpointName} />}
    </>
  );
}
