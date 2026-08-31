import {
  getWorkspaceHealth,
  getProviderStatus,
  runAgent,
  bootWebContainer,
  executeWebContainer,
  createWebContainerFiles,
} from './stackblitz.js';

export const workspaceAPI = {
  health: getWorkspaceHealth,
  providerStatus: getProviderStatus,
  agent: runAgent,
  boot: bootWebContainer,
  exec: executeWebContainer,
  files: createWebContainerFiles,
};

export default workspaceAPI;
