module.exports = ({ env }) => ({
  email: {
    config: {
      // sendmail (default provider ในตัว) รองรับ devHost/devPort อยู่แล้ว —
      // ใช้ต่อ SMTP ตรงไปที่ Mailpit แทนการหา MX record จริงของโลกภายนอก
      // https://github.com/guileen/node-sendmail#readme
      provider: 'sendmail',
      providerOptions: {
        devHost: env('MAILPIT_HOST', 'mailpit'),
        devPort: env.int('MAILPIT_SMTP_PORT', 1025),
      },
      settings: {
        defaultFrom: 'no-reply@localhost',
        defaultReplyTo: 'no-reply@localhost',
      },
    },
  },
});
