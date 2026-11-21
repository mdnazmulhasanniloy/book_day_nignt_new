import puppeteer from 'puppeteer';
import logger from '@/app/configs/logger.configs';

/** Mobile-pass width in CSS px — fills phone PDF viewers edge-to-edge when scaled. */
const PASS_WIDTH_PX = 420;

export const renderHtmlToPdf = async (
  htmlContent: string
): Promise<Uint8Array> => {
  let browser;
  try {
    // Determine executable path: if in Docker (PUPPETEER_EXECUTABLE_PATH is set), use it.
    // Otherwise fallback to Puppeteer's bundled Chromium or common local paths.
    const executablePath = process.env.PUPPETEER_EXECUTABLE_PATH || undefined;

    browser = await puppeteer.launch({
      executablePath,
      args: [
        '--no-sandbox',
        '--disable-setuid-sandbox',
        '--disable-dev-shm-usage',
        '--disable-gpu',
        '--font-render-hinting=none',
      ],
      headless: true,
    });

    const page = await browser.newPage();
    page.setDefaultNavigationTimeout(45000);
    page.setDefaultTimeout(45000);

    // Viewport matches pass width so layout is measured correctly (no A4 letterboxing).
    await page.setViewport({
      width: PASS_WIDTH_PX,
      height: 900,
      deviceScaleFactor: 2,
    });

    // Wait for fonts/CSS/images (Google Fonts + logo) so the luxury pass does not print plain.
    // Puppeteer typings currently omit networkidle0 for setContent; Chromium still supports it.
    try {
      await page.setContent(htmlContent, {
        waitUntil: 'networkidle0' as 'load',
        timeout: 45000,
      });
    } catch (networkIdleError) {
      logger.warn(
        '[renderHtmlToPdf] networkidle0 timed out; falling back to load + font ready',
        networkIdleError
      );
      await page.setContent(htmlContent, {
        waitUntil: 'load',
        timeout: 45000,
      });
    }

    try {
      await page.evaluate(async () => {
        if (document.fonts?.ready) {
          await document.fonts.ready;
        }
      });
    } catch (fontError) {
      logger.warn(
        '[renderHtmlToPdf] document.fonts.ready unavailable; continuing',
        fontError
      );
    }

    // Brief settle so late font swaps still paint before capture.
    await new Promise((resolve) => setTimeout(resolve, 400));

    // WHY: Chromium often ignores `@page { size: X auto }` and falls back to A4,
    // which centers a small ticket in a huge black page on mobile. Explicit
    // width + measured height makes the PDF page = the pass itself (full-bleed).
    const contentHeight = await page.evaluate(() => {
      const root = document.documentElement;
      const body = document.body;
      const ticket = document.querySelector('.ticket') as HTMLElement | null;
      const heights = [
        root?.scrollHeight ?? 0,
        body?.scrollHeight ?? 0,
        ticket?.scrollHeight ?? 0,
        ticket?.offsetHeight ?? 0,
      ];
      return Math.ceil(Math.max(...heights, 1));
    });

    const pdfUint8Array = await page.pdf({
      width: `${PASS_WIDTH_PX}px`,
      height: `${contentHeight}px`,
      printBackground: true,
      margin: { top: 0, right: 0, bottom: 0, left: 0 },
      preferCSSPageSize: false,
    });

    return pdfUint8Array;
  } catch (error) {
    logger.error('[renderHtmlToPdf] Failed to render HTML to PDF', error);
    throw error;
  } finally {
    if (browser) {
      try {
        await browser.close();
      } catch (closeError) {
        logger.error('[renderHtmlToPdf] Failed to close browser', closeError);
      }
    }
  }
};
