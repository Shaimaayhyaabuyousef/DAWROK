export function localMobile(value) {
  const digits = String(value ?? '').replace(/[٠-٩۰-۹]/g, c =>
    String(c.charCodeAt(0) - (c.charCodeAt(0) >= 0x6f0 ? 0x6f0 : 0x660)))
    .replace(/[\s()-]/g, '');
  const match = /^(?:0|\+970|00970|970)?(5[69][0-9]{7})$/.exec(digits);
  if (!match) throw new Error('Expected a Palestinian 059 or 056 mobile number');
  return '0' + match[1];
}

export const loginId = phone => 'p970' + localMobile(phone).slice(1) + '@login.dawrok.invalid';
