import { Job } from 'bullmq';
import { IJobHandler } from '@/app/@types/queue.types';
import { IRecoverUserVerificationOtpResend } from '@/app/queues/email/email.types';
import { companyInformation, QUEUE_JOBS } from '@/const';
import logger from '@/app/configs/logger.configs';
import { compile } from 'handlebars';
import resendOtpTemplate from '@/app/templates/resendOtp.template';
import { mailOption } from '@/app/utils/system.utils';
import mailTransporter from '@/app/configs/nodemailer.config';

const handler: IJobHandler<IRecoverUserVerificationOtpResend> = {
  name: QUEUE_JOBS.RECOVER_USER_VERIFICATION_OTP_RESEND,
  handler: async (data: IRecoverUserVerificationOtpResend, job: Job) => {
    const { email, name, otp, otpExpireAt, traceId } = data;
    try {
      const template = compile(resendOtpTemplate);
      const personalizedTemplate = template({ name, email, otp, otpExpireAt });
      const mailOptions = mailOption({
        to: email,
        subject: 'Your BookDiaNight recovery code',
        html: personalizedTemplate,
        replyTo: companyInformation.email,
      });
      const info = await mailTransporter.sendMail(mailOptions);
      logger.info('Recovery OTP resend accepted by SMTP', {
        email,
        traceId,
        jobId: job.id,
        messageId: info.messageId,
      });
    } catch (error) {
      logger.error('Failed to send Account recover verification otp email:', {
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
