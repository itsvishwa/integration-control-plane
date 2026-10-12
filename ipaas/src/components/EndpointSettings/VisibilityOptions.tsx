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

import { Box, Checkbox, Stack, Typography, type SxProps, type Theme } from '@wso2/oxygen-ui';
import type { JSX } from 'react';
import { toggleVisibility } from '../../utils/endpoints';
import { VISIBILITY_OPTS } from '../EndpointCard';
import * as styles from './endpointSettings.styles';

interface VisibilityOptionsProps {
  /** Ticked visibilities, as UI labels ('Public' | 'Organization' | 'Project'). */
  value: string[];
  onChange: (value: string[]) => void;
  disabled?: boolean;
  sx?: SxProps<Theme>;
}

/** The Public / Organization / Project cards an endpoint's network visibility is picked from. */
export default function VisibilityOptions({ value, onChange, disabled = false, sx }: VisibilityOptionsProps): JSX.Element {
  const toggle = (key: string) => {
    if (!disabled) onChange(toggleVisibility(value, key));
  };

  return (
    <Stack gap={1} sx={sx}>
      {VISIBILITY_OPTS.map(({ key, label, Icon, description }) => {
        const checked = value.includes(key);
        return (
          <Box key={key} onClick={() => toggle(key)} sx={styles.visibilityOption(checked, disabled)}>
            <Box sx={styles.visibilityOptionIcon}>
              <Icon size={18} />
            </Box>
            <Box sx={styles.visibilityOptionText}>
              <Typography variant="body2" fontWeight={600}>
                {label}
              </Typography>
              <Typography variant="caption" color="text.secondary">
                {description}
              </Typography>
            </Box>
            <Checkbox checked={checked} size="small" disabled={disabled} sx={styles.visibilityOptionCheckbox} onClick={(e) => e.stopPropagation()} onChange={() => toggle(key)} />
          </Box>
        );
      })}
    </Stack>
  );
}
