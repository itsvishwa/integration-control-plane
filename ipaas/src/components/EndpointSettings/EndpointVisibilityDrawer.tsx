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

import { Alert, Box, Button, CircularProgress, Drawer, IconButton, Stack, Typography } from '@wso2/oxygen-ui';
import { X } from '@wso2/oxygen-ui-icons-react';
import { useQueryClient } from '@tanstack/react-query';
import { useMemo, useState, type JSX } from 'react';
import { useUpdateEndpoint } from '../../hooks/useComponents';
import type { EnvEndpoint } from '../../types/component';
import { endpointVisibilities, isSameVisibilities, toEndpointOptions } from '../../utils/endpoints';
import EndpointPicker from './EndpointPicker';
import { useEndpointDrawer } from './useEndpointDrawer';
import VisibilityOptions from './VisibilityOptions';
import * as styles from './endpointSettings.styles';

interface EndpointVisibilityDrawerProps {
  open: boolean;
  onClose: () => void;
  componentId: string;
  /** Project handle — cloud resolves the component's release bindings with it. */
  projectId: string;
  versionId: string;
  /** Environment name — keys the endpoint selection, like the other endpoint drawers. */
  envName: string;
  /** Endpoints of this environment; the drawer configures one at a time. */
  endpoints: EnvEndpoint[];
  /** The endpoint to configure, already picked by the caller (e.g. on the env card). Omit it to let the user pick one. */
  activeEndpointName?: string;
  onSaved: () => void;
}

/** Cloud-only "Configure Visibility" drawer: which networks (Public / Organization / Project) reach an endpoint. */
export default function EndpointVisibilityDrawer({ open, onClose, componentId, projectId, versionId, envName, endpoints, activeEndpointName, onSaved }: EndpointVisibilityDrawerProps): JSX.Element {
  const options = useMemo(() => toEndpointOptions(endpoints), [endpoints]);
  const { selectedIdx, selectEndpoint, selectedEndpoint, canChoose, syncKey } = useEndpointDrawer({ open, componentName: componentId, envName, endpoints: options, activeEndpointName });
  const endpoint = endpoints[selectedIdx] ?? null;
  const saved = useMemo(() => (endpoint ? endpointVisibilities(endpoint) : []), [endpoint]);

  // An edit belongs to one (endpoint, opening): switching endpoints shows that endpoint's saved
  // visibility, and closing drops the edit.
  const [draft, setDraft] = useState<{ key: string; value: string[] } | null>(null);
  const value = draft?.key === syncKey ? draft.value : saved;
  const [error, setError] = useState<string | null>(null);

  const queryClient = useQueryClient();
  const updateEndpoint = useUpdateEndpoint();
  const saving = updateEndpoint.isPending;
  const canApply = !!endpoint && value.length > 0 && !isSameVisibilities(value, saved) && !saving;

  const handleClose = () => {
    setDraft(null);
    setError(null);
    onClose();
  };

  const handleSelect = (idx: number) => {
    setError(null);
    selectEndpoint(idx);
  };

  const handleApply = async () => {
    if (!endpoint || !canApply) return;
    setError(null);
    try {
      await updateEndpoint.mutateAsync({ componentId, projectId, versionId, releaseId: endpoint.releaseId, endpointId: endpoint.id, displayName: endpoint.displayName, networkVisibilities: value });
      // The change goes through the env's release binding, so the card's release (which its endpoints
      // are read from) can move on. Re-read the deployment, as the Configure dialog does after saving.
      void queryClient.invalidateQueries({ queryKey: ['componentDeployment'] });
      onSaved();
      handleClose();
    } catch (err) {
      // The BFF's error message is already written for the user.
      setError(err instanceof Error ? err.message : 'Could not update the visibility.');
    }
  };

  return (
    <Drawer anchor="right" open={open} onClose={handleClose} variant="temporary" sx={styles.rightDrawer}>
      <Box sx={styles.drawerFrame}>
        <Box sx={styles.drawerHeader}>
          <Typography variant="subtitle1" fontWeight={600}>
            Configure Visibility
          </Typography>
          <IconButton size="small" aria-label="close" onClick={handleClose}>
            <X size={16} />
          </IconButton>
        </Box>

        <Box sx={styles.drawerBody}>
          {!endpoint || !selectedEndpoint ? (
            <Alert severity="info">No endpoint associated with this component.</Alert>
          ) : (
            <Stack gap={2.5}>
              {error && <Alert severity="error">{error}</Alert>}

              <EndpointPicker endpoint={selectedEndpoint} choice={canChoose ? { endpoints: options, selectedIdx, onSelect: handleSelect } : undefined} />

              <VisibilityOptions value={value} onChange={(next) => setDraft({ key: syncKey, value: next })} disabled={saving} />

              {/* Visibility lives on the Workload, so the backend rolls a new release out on save. */}
              <Alert severity="info">Applying this change starts a redeployment.</Alert>
            </Stack>
          )}
        </Box>

        <Box sx={styles.drawerFooter}>
          <Button variant="outlined" onClick={handleClose} disabled={saving}>
            Cancel
          </Button>
          <Button variant="contained" onClick={() => void handleApply()} disabled={!canApply}>
            {saving ? <CircularProgress size={16} color="inherit" /> : 'Apply'}
          </Button>
        </Box>
      </Box>
    </Drawer>
  );
}
