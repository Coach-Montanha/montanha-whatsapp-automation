import { cp, mkdir, rm } from 'node:fs/promises'
import { existsSync } from 'node:fs'

const outputDirectory = new URL('../dist/', import.meta.url)
const projectRoot = new URL('../', import.meta.url)

const publicDirectory = new URL('../public/', import.meta.url)

await rm(outputDirectory, { recursive: true, force: true })
await mkdir(outputDirectory, { recursive: true })

if (existsSync(publicDirectory)) {
  await cp(publicDirectory, outputDirectory, { recursive: true })
}

const files = ['index.html', 'capacitor.config.json', 'manifest.json', 'service-worker.js']

for (const file of files) {
  const source = new URL(file, projectRoot)
  if (existsSync(source)) {
    await cp(source, new URL(file, outputDirectory))
  }
}

// Ensure /auth route resolves on Vercel for single page HTML
const indexSource = new URL('index.html', projectRoot)
const authHtmlTarget = new URL('auth.html', outputDirectory)
const authDirTarget = new URL('auth/', outputDirectory)
await cp(indexSource, authHtmlTarget)
await mkdir(authDirTarget, { recursive: true })
await cp(indexSource, new URL('index.html', authDirTarget))

console.log('Built static application in dist/')