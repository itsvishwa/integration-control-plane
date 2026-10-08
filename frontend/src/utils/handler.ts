// Handlers (project, environment and integration names) are URL path segments, so the
// server only accepts this slug; keep it in sync with validateHandler in icp_server.
const HANDLER_PATTERN = /^[a-z0-9]+(-[a-z0-9]+)*$/;

export const HANDLER_RULE = 'Use only lowercase letters, numbers and single hyphens, for example order-service.';

export function toHandler(name: string): string {
  return name
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '');
}

export function isValidHandler(handler: string): boolean {
  return HANDLER_PATTERN.test(handler);
}
