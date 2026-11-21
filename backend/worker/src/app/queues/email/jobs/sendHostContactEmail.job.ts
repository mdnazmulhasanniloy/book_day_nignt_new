import { Job } from 'bullmq';
import { compile } from 'handlebars';
import { IJobHandler } from '@/app/@types/queue.types';
import { ISendHostContactEmail } from '@/app/queues/email/email.types';
import hostContactTemplate from '@/app/templates/hostContact.template';
import hostContactConfirmationTemplate from '@/app/templates/hostContactConfirmation.template';
import mailTransporter from '@/app/configs/nodemailer.config';
import { mailOption } from '@/app/utils/system.utils';
import { companyInformation, QUEUE_JOBS } from '@/const';
import logger from '@/app/configs/logger.configs';

const handler: IJobHandler<ISendHostContactEmail> = {
  name: QUEUE_JOBS.SEND_HOST_CONTACT_EMAIL,
  handler: async (data: ISendHostContactEmail, job: Job) => {
    const {
      hostName,
      hostEmail,
      clientName,
      clientEmail,
      clientPhone,
      message,
      traceId,
    } = data;

    try {
      if (hostEmail) {
        const hostHtml = compile(hostContactTemplate)({
          hostName,
          clientName,
          clientEmail,
          clientPhone,
          message,
        });

        await mailTransporter.sendMail(
          mailOption({
            to: hostEmail,
            subject: `New VIP inquiry from ${clientName}`,
            html: hostHtml,
            replyTo: clientEmail || companyInformation.email,
          })
        );

        logger.info(
          `[sendHostContactEmail] Sent host contact email to ${hostEmail}`
        );
      }

      const customerHtml = compile(hostContactConfirmationTemplate)({
        hostName,
        clientName,
        message,
      });

      await mailTransporter.sendMail(
        mailOption({
          to: clientEmail,
          subject: `Your VIP inquiry to ${hostName} was sent`,
          html: customerHtml,
          replyTo: companyInformation.email,
        })
      );

      logger.info(
        `[sendHostContactEmail] Sent customer confirmation email to ${clientEmail}`
      );
    } catch (error) {
      logger.error('[sendHostContactEmail] Failed to send host contact emails:', {
        data,
        jobId: job.id,
        error,
        traceId,
      });
      throw error;
    }
  },
};

export default handler;
