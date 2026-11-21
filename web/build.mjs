import * as esbuild from 'esbuild';
import fs from 'node:fs';

const watch = process.argv.includes('--watch');
const opts = {
  entryPoints: ['src/main.jsx'],
  bundle: true,
  format: 'iife',
  target: ['chrome90'],
  jsx: 'automatic',
  loader: { '.js': 'jsx' },
  outdir: '../html/assets',
  entryNames: 'index',
  minify: !watch,
  sourcemap: watch,
  legalComments: 'none',
  define: { 'process.env.NODE_ENV': JSON.stringify(watch ? 'development' : 'production') },
  logLevel: 'info',
};

fs.mkdirSync('../html/assets', { recursive: true });
fs.copyFileSync('index.html', '../html/index.html');

if (watch) {
  const ctx = await esbuild.context(opts);
  await ctx.watch();
  console.log('watching src/ ... (Ctrl+C untuk berhenti)');
} else {
  await esbuild.build(opts);
}
