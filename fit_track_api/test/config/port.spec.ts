import { DEFAULT_API_PORT, resolveApiPort } from '../../src/config/port';

describe('resolveApiPort (W9-01)', () => {
  it('usa 3000 como único default documentado', () => {
    expect(DEFAULT_API_PORT).toBe(3000);
  });

  it.each([undefined, '', '   '])(
    'cae al default cuando PORT no está definido (%p)',
    (value) => {
      expect(resolveApiPort(value)).toBe(3000);
    },
  );

  it.each([
    ['3000', 3000],
    ['3001', 3001],
    [' 8080 ', 8080],
  ])('respeta PORT=%p', (value, expected) => {
    expect(resolveApiPort(value)).toBe(expected);
  });

  it.each(['abc', '3000abc', '0', '-1', '65536', '3000.5', '0x0BB8'])(
    'rechaza PORT=%p con un mensaje claro en vez de escuchar en otro puerto',
    (value) => {
      expect(() => resolveApiPort(value)).toThrow(/PORT/);
    },
  );
});
