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

import { MenuItem, Select, Stack, Typography } from '@wso2/oxygen-ui';
import type { JSX } from 'react';
import type { EndpointOption } from '../../types/consumers';
import * as styles from './endpointSettings.styles';

interface EndpointPickerProps {
  /** The endpoint being configured. */
  endpoint: EndpointOption;
  /** Lets the user switch endpoints. Without it the endpoint shows read-only — the caller already picked it. */
  choice?: { endpoints: EndpointOption[]; selectedIdx: number; onSelect: (idx: number) => void };
}

/** The endpoint an endpoint-settings drawer configures. */
export default function EndpointPicker({ endpoint, choice }: EndpointPickerProps): JSX.Element {
  return (
    <Stack direction="row" alignItems="center" gap={2}>
      <Typography variant="body2" fontWeight={500}>
        Endpoint:
      </Typography>
      {choice ? (
        <Select size="small" value={choice.selectedIdx} onChange={(e) => choice.onSelect(Number(e.target.value))} disabled={choice.endpoints.length <= 1} sx={styles.endpointSelect}>
          {choice.endpoints.map((ep, i) => (
            <MenuItem key={ep.name} value={i}>
              {ep.displayName}
            </MenuItem>
          ))}
        </Select>
      ) : (
        <Typography variant="body2">{endpoint.displayName}</Typography>
      )}
    </Stack>
  );
}
