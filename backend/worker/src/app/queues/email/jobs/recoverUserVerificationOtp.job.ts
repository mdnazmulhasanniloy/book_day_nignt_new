import { Job } from 'bullmq';
import { IJobHandler } from '@/app/@types/queue.types';
import { IRecoverUserVerificationOtp } from '@/app/queues/email/email.types';
import { companyInformation, QUEUE_JOBS } from '@/const';
import logger from '@/app/configs/logger.configs';
import { compile } from 'handlebars';
import forgotPasswordTemplate from '@/app/templates/forgotPassword.template';
import { mailOption } from '@/app/utils/system.utils';
import mailTransporter from '@/app/configs/nodemailer.config';

const handler: IJobHandler<IRecoverUserVerificationOtp> = {
  name: QUEUE_JOBS.RECOVER_USER_VERIFICATION_OTP,
  handler: async (data: IRecoverUserVerificationOtp, job: Job) => {
    const { email, name, otp, otpExpireAt, traceId } = data;
    try {
      const template = compile(forgotPasswordTemplate);
      const personalizedTemplate = template({ name, email, otp, otpExpireAt });
      const mailOptions = mailOption({
        to: email,
        subject: 'Your BookDiaNight recovery code',
        html: personalizedTemplate,
        replyTo: companyInformation.email,
      });
      const info = await mailTransporter.sendMail(mailOptions);
      logger.info('Recovery OTP email accepted by SMTP', {
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
