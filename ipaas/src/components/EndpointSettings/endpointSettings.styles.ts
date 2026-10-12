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

/** Styles for the cloud endpoint settings drawers (visibility, policies, security) and their actions. */

/** Sized and placed like the Build History drawer: below the top nav, full height beneath it. */
export const rightDrawer = {
  '& .MuiDrawer-paper': {
    width: { xs: '100%', sm: 560 },
    top: { xs: '56px', sm: '64px' },
    height: 'auto',
    bottom: 0,
  },
} as const;

export const drawerFrame = {
  display: 'flex',
  flexDirection: 'column',
  height: '100%',
} as const;

export const drawerHeader = {
  display: 'flex',
  alignItems: 'center',
  justifyContent: 'space-between',
  px: 2,
  py: 1.5,
  borderBottom: '1px solid',
  borderColor: 'divider',
  flexShrink: 0,
} as const;

export const drawerBody = {
  flex: 1,
  overflow: 'auto',
  px: 2,
  py: 2,
} as const;

export const drawerFooter = {
  display: 'flex',
  justifyContent: 'flex-end',
  gap: 1,
  px: 3,
  py: 2,
  borderTop: '1px solid',
  borderColor: 'divider',
} as const;

export const tableHeadCell = {
  color: 'text.secondary',
  fontSize: '0.7rem',
  fontWeight: 600,
  letterSpacing: '0.06em',
  textTransform: 'uppercase',
} as const;

export const schemeCell = {
  verticalAlign: 'top',
} as const;

export const schemeDescription = {
  display: 'block',
  mt: 0.75,
} as const;

/** Wrapper that carries a tooltip for a disabled control (which swallows pointer events). */
export const disabledTooltipTarget = {
  display: 'inline-flex',
} as const;

export const endpointSelect = {
  minWidth: 200,
} as const;

export const centredRow = {
  display: 'flex',
  justifyContent: 'center',
  py: 1.5,
} as const;

export const textAction = {
  textTransform: 'none',
} as const;

export const loadingRow = {
  display: 'flex',
  justifyContent: 'center',
  py: 2.5,
} as const;

/** A network-visibility choice: a bordered card that turns primary when ticked. */
export const visibilityOption = (checked: boolean, disabled: boolean) =>
  ({
    display: 'flex',
    alignItems: 'flex-start',
    gap: 1.25,
    p: 1.5,
    border: '1px solid',
    borderColor: checked ? 'primary.main' : 'divider',
    borderRadius: 1,
    cursor: disabled ? 'default' : 'pointer',
    transition: 'border-color 0.15s',
    ...(disabled ? {} : { '&:hover': { borderColor: 'primary.main' } }),
  }) as const;

export const visibilityOptionIcon = {
  display: 'flex',
  color: 'primary.main',
  mt: 0.25,
  flexShrink: 0,
} as const;

export const visibilityOptionText = {
  flex: 1,
  minWidth: 0,
} as const;

export const visibilityOptionCheckbox = {
  p: 0,
  flexShrink: 0,
  mt: 0.25,
} as const;
