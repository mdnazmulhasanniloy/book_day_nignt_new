import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import Stripe from 'stripe';
import { constructStripeEvent } from '@/app/utils/stripeSignature.utils';

const stripe = new Stripe('sk_test_dummy');
const secret = 'whsec_test_secret';
const payload = JSON.stringify({
  id: 'evt_1',
  object: 'event',
  type: 'account.updated',
});

describe('constructStripeEvent (BUG-B16)', () => {
  it('missing signature -> 400 INVALID_STRIPE_SIGNATURE', () => {
    assert.throws(
      () => constructStripeEvent({ stripe, payload, signature: undefined, secret }),
      { statusCode: 400, errorType: 'INVALID_STRIPE_SIGNATURE' }
    );
  });

  it('wrong signature -> 400 INVALID_STRIPE_SIGNATURE', () => {
    assert.throws(
      () => constructStripeEvent({ stripe, payload, signature: 't=1,v1=bad', secret }),
      { statusCode: 400, errorType: 'INVALID_STRIPE_SIGNATURE' }
    );
  });

  it('valid signature -> returns the event', () => {
    const signature = stripe.webhooks.generateTestHeaderString({ payload, secret });
    const event = constructStripeEvent({ stripe, payload, signature, secret });
    assert.equal(event.id, 'evt_1');
  });

  it('error message never contains the secret or payload', () => {
    try {
      constructStripeEvent({ stripe, payload, signature: 't=1,v1=bad', secret });
    } catch (e) {
      const msg = (e as Error).message;
      assert.equal(msg.includes(secret), false);
      assert.equal(msg.includes('evt_1'), false);
    }
  });
});
