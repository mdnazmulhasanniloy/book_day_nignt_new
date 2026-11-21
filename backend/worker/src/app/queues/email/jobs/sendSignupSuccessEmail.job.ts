import { Job } from 'bullmq';
import { compile } from 'handlebars';
import { IJobHandler } from '@/app/@types/queue.types';
import { ISignupSuccessEmailJobData } from '@/app/queues/email/email.types';
import signupTemplate from '@/app/templates/signup.template';
import mailTransporter from '@/app/configs/nodemailer.config';
import { mailOption } from '@/app/utils/system.utils';
import { companyInformation, QUEUE_JOBS } from '@/const';
import logger from '@/app/configs/logger.configs';

/**
 * This job will send a welcome email with otp to the user after successful signup
 * @param data ISignupSuccessEmailJobData
 * @param job Job
 */
const handler: IJobHandler<ISignupSuccessEmailJobData> = {
  name: QUEUE_JOBS.SEND_SIGNUP_SUCCESS_EMAIL,
  handler: async (data: ISignupSuccessEmailJobData, job: Job) => {
    const { email, name, otp, otpExpireAt, traceId } = data;
    try {
      const template = compile(signupTemplate);
      const personalizedTemplate = template({ name, email, otp, otpExpireAt });
      const mail = mailOption({
        to: email,
        subject: 'Verify Your Email Address',
        html: personalizedTemplate,
        replyTo: companyInformation.email,
      });
      const info = await mailTransporter.sendMail(mail);
      logger.info('Signup OTP email accepted by SMTP', {
        email,
        traceId,
        jobId: job.id,
        messageId: info.messageId,
      });
    } catch (error) {
      logger.error('Failed to send signup success email:', {
        email,
        traceId,
        jobId: job.id,
        errorName: error instanceof Error ? error.name : 'Error',
      });
      throw error;
    }
  },
};

export default handler;
