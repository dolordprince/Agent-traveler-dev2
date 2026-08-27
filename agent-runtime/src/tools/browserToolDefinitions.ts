export const browserToolDefinitions = [
  {
    name: "browser_start_server",
    description: "Starts background server and waits for readiness on a target port.",
    parameters: {
      type: "OBJECT",
      properties: {
        command: { type: "STRING", description: "Command to run (e.g., 'npm run dev' or 'node dist/server.js')" },
        cwd: { type: "STRING", description: "Working directory path" },
        port: { type: "NUMBER", description: "Port to monitor for readiness" }
      },
      required: ["command", "cwd", "port"]
    }
  },
  {
    name: "browser_inspect_page",
    description: "Navigates to application URL, captures mobile/desktop screenshots, and returns all runtime console/network errors.",
    parameters: {
      type: "OBJECT",
      properties: {
        url: { type: "STRING", description: "Target URL (e.g. http://localhost:3000)" },
        artifactsDir: { type: "STRING", description: "Path to save visual artifacts (e.g. .artifacts/screenshots)" }
      },
      required: ["url", "artifactsDir"]
    }
  },
  {
    name: "browser_stop_all",
    description: "Stops active dev server background process and closes the headless browser session.",
    parameters: {
      type: "OBJECT",
      properties: {},
      required: []
    }
  }
];
