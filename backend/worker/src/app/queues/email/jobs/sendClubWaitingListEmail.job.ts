import { Job } from 'bullmq';
import { compile } from 'handlebars';
import { IJobHandler } from '@/app/@types/queue.types';
import { ISendClubWaitingListEmail } from '@/app/queues/email/email.types';
import clubWaitingListSeatAvailableTemplate from '@/app/templates/clubWaitingListSeatAvailable.template';
import mailTransporter from '@/app/configs/nodemailer.config';
import { mailOption } from '@/app/utils/system.utils';
import { companyInformation, QUEUE_JOBS } from '@/const';
import { env } from '@/env';
import logger from '@/app/configs/logger.configs';

const handler: IJobHandler<ISendClubWaitingListEmail> = {
  name: QUEUE_JOBS.SEND_CLUB_WAITING_LIST_EMAIL,
  handler: async (data: ISendClubWaitingListEmail, job: Job) => {
    const {
      userName,
      userEmail,
      clubId,
      clubName,
      clubLocation,
      clubThumbnail,
      traceId,
    } = data;

    try {
      const template = compile(clubWaitingListSeatAvailableTemplate);
      const personalizedTemplate = template({
        userName,
        clubId,
        clubName,
        clubLocation,
        clubThumbnail,
        serverUrl: env.SERVER_URL.replace(/\/+$/, ''),
      });

      const mail = mailOption({
        to: userEmail,
        subject: `Spots Available at ${clubName}! - Book Now`,
        html: personalizedTemplate,
        replyTo: companyInformation.email,
      });

      await mailTransporter.sendMail(mail);

      logger.info(
        `[sendClubWaitingListEmail] Successfully sent waiting list email to ${userEmail} for club ${clubName}`
      );
    } catch (error) {
      logger.error(
        '[sendClubWaitingListEmail] Failed to send waiting list email:',
        {
          data,
          jobId: job.id,
          error,
          traceId,
        }
      );
      throw error;
    }
  },
};

export default handler;
