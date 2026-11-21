import { Job } from 'bullmq';
import { IJobHandler } from '@/app/@types/queue.types';
import { IResendVerificationOtp } from '@/app/queues/email/email.types';
import { companyInformation, QUEUE_JOBS } from '@/const';
import logger from '@/app/configs/logger.configs';
import resendOtpTemplate from '@/app/templates/resendOtp.template';
import { compile } from 'handlebars';
import { mailOption } from '@/app/utils/system.utils';
import mailTransporter from '@/app/configs/nodemailer.config';

/**
 * This job will send a verification OTP to the user after successful signup
 * @param data IResendVerificationOtp
 * @param job Job
 */
const handler: IJobHandler<IResendVerificationOtp> = {
  name: QUEUE_JOBS.RESEND_VERIFICATION_OTP,
  handler: async (data: IResendVerificationOtp, job: Job) => {
    const { email, name, otp, otpExpireAt, traceId } = data;
    try {
      const template = compile(resendOtpTemplate);
      const personalizedTemplate = template({ name, email, otp, otpExpireAt });
      const mailOptions = mailOption({
        to: email,
        subject: 'Your BookDiaNight verification code',
        html: personalizedTemplate,
        replyTo: companyInformation.email,
      });
      const info = await mailTransporter.sendMail(mailOptions);
      logger.info('Resend OTP email accepted by SMTP', {
        email,
        traceId,
        jobId: job.id,
        messageId: info.messageId,
      });
    } catch (error) {
      logger.error('Failed to send Resend verification otp email:', {
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
