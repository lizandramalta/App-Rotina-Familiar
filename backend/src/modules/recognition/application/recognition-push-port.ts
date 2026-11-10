export interface RecognitionPushPort {
  sendRecognition(deviceToken: string, environment: string, recognitionId: string): Promise<number>;
}
