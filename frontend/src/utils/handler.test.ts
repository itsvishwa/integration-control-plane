import { describe, expect, it } from 'vitest';
import { isValidHandler, toHandler } from './handler';

describe('toHandler', () => {
  it('slugifies display names', () => {
    expect(toHandler('Order Service')).toBe('order-service');
    expect(toHandler('Bad Handler/../x')).toBe('bad-handler-x');
    expect(toHandler('  Weird Handler!! ')).toBe('weird-handler');
  });

  it('always produces a valid handler when non-empty', () => {
    for (const name of ['Bad Comp !! /x', 'P <img src=x>', 'a__b', 'Ünïcode 2']) {
      const handler = toHandler(name);
      expect(handler === '' || isValidHandler(handler)).toBe(true);
    }
  });
});

describe('isValidHandler', () => {
  it.each(['dev', 'order-service', 'a1-b2', '2024'])('accepts %s', (handler) => {
    expect(isValidHandler(handler)).toBe(true);
  });

  it.each(['', 'Weird Handler!!', 'Bad Handler/../x', 'UPPER', 'under_score', '-lead', 'trail-', 'double--hyphen', 'with.dot'])('rejects %s', (handler) => {
    expect(isValidHandler(handler)).toBe(false);
  });
});
