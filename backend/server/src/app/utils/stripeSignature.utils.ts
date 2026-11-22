import type Stripe from 'stripe';

export type StripeSignatureError = Error & {
  statusCode: 400;
  errorType: 'INVALID_STRIPE_SIGNATURE';
};

const signatureError = (message: string): StripeSignatureError =>
  Object.assign(new Error(message), {
    statusCode: 400 as const,
    errorType: 'INVALID_STRIPE_SIGNATURE' as const,
  });

/**
 * Verifies a Stripe webhook signature and returns the event.
 * WHY: a missing or bad signature is a client error (400), not a server fault (500).
 * Never logs or returns the secret or the payload.
 */
export const constructStripeEvent = ({
  stripe,
  payload,
  signature,
  secret,
}: {
  stripe: Pick<Stripe, 'webhooks'>;
  payload: string | Buffer;
  signature: string | undefined;
  secret: string;
}): Stripe.Event => {
  if (!signature) throw signatureError('Stripe signature is missing');
  try {
    return stripe.webhooks.constructEvent(payload, signature, secret);
  } catch {
    throw signatureError('Stripe signature is invalid');
  }
};
