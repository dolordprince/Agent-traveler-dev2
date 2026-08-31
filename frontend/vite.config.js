import { defineConfig } from 'vite';

export default defineConfig({
  base: './',
  server: {
    host: '0.0.0.0',
    strictPort: false,
  },
  preview: {
    host: '0.0.0.0',
    strictPort: false,
  },
  build: {
    target: 'es2022',
    sourcemap: true,
  },
});
