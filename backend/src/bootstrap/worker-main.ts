import { loadConfiguration, ConfigurationError } from './configuration.js';
import { createContainer } from './container.js';

async function bootstrapWorker(): Promise<void> {
  let config;
  try {
    config = loadConfiguration();
  } catch (error) {
    if (error instanceof ConfigurationError) {
      console.error('\x1b[31m%s\x1b[0m', error.message);
      process.exit(1);
    }
    throw error;
  }

  const container = createContainer(config);
  const logger = container.logger.child({ process: 'worker' });

  logger.info('Starting App Rotina Familiar Worker process...', {
    env: config.NODE_ENV,
  });

  // Ready for background job processors (BA-06, backend-architecture.md §14):
  // - MaterializeRoutineOccurrences
  // - AdvanceFamilyCalendar
  // - FinalizeWeeklyHighlight
  // - DeliverRecognitionNotification
  // - CleanOrphanMedia
  // - CleanExpiredAccessArtifacts

  let isRunning = true;

  const handleShutdown = async (signal: string) => {
    if (!isRunning) {
      return;
    }
    isRunning = false;
    logger.info(`Received ${signal}. Shutting down worker process...`);

    try {
      await container.dispose();
      logger.info('Worker shutdown completed successfully.');
      process.exit(0);
    } catch (err) {
      logger.error('Error during worker shutdown', err);
      process.exit(1);
    }
  };

  process.on('SIGTERM', () => handleShutdown('SIGTERM'));
  process.on('SIGINT', () => handleShutdown('SIGINT'));

  process.on('unhandledRejection', (reason) => {
    logger.fatal('Unhandled promise rejection in worker process', reason);
  });

  process.on('uncaughtException', (error) => {
    logger.fatal('Uncaught exception in worker process', error);
    process.exit(1);
  });

  logger.info('Worker process initialized and standing by.');
}

bootstrapWorker().catch((err) => {
  console.error('Fatal worker bootstrap failure:', err);
  process.exit(1);
});
