import { loadConfiguration, ConfigurationError } from './configuration.js';
import { createContainer } from './container.js';
import { buildHttpApp } from '../presentation/http/app.js';

async function bootstrap(): Promise<void> {
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
  const logger = container.logger.child({ process: 'api' });

  logger.info('Starting App Rotina Familiar API process...', {
    env: config.NODE_ENV,
    port: config.PORT,
    host: config.HOST,
  });

  const app = buildHttpApp(container, config);

  try {
    await app.listen({ port: config.PORT, host: config.HOST });
    logger.info(`API listening successfully at http://${config.HOST}:${config.PORT}`);
  } catch (err) {
    logger.fatal('Failed to bind API HTTP server', err);
    await container.dispose();
    process.exit(1);
  }

  // Graceful shutdown
  let isShuttingDown = false;
  const handleShutdown = async (signal: string) => {
    if (isShuttingDown) {
      return;
    }
    isShuttingDown = true;
    logger.info(`Received ${signal}. Starting graceful shutdown...`);

    try {
      await app.close();
      logger.info('HTTP server closed.');
      await container.dispose();
      logger.info('Graceful shutdown completed successfully.');
      process.exit(0);
    } catch (err) {
      logger.error('Error during graceful shutdown', err);
      process.exit(1);
    }
  };

  process.on('SIGTERM', () => handleShutdown('SIGTERM'));
  process.on('SIGINT', () => handleShutdown('SIGINT'));

  process.on('unhandledRejection', (reason) => {
    logger.fatal('Unhandled promise rejection in API process', reason);
  });

  process.on('uncaughtException', (error) => {
    logger.fatal('Uncaught exception in API process', error);
    process.exit(1);
  });
}

bootstrap().catch((err) => {
  console.error('Fatal bootstrap failure:', err);
  process.exit(1);
});
