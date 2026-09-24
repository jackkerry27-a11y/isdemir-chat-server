/**
 * AisStream.io Bridge / Legacy Compatibility Layer
 * MyShipTracking API tamamen kaldırıldı ve AisStream.io motoruna yönlendirildi.
 */

const aisEngine = require('./aisstream_engine');

module.exports = {
  runMyShipTrackingSync: (cb) => aisEngine.syncVesselsToFirestore(cb),
  runSyncFromClient: (rawText, cb) => aisEngine.syncVesselsToFirestore(cb),
  ...aisEngine
};
