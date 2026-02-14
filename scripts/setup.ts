#!/usr/bin/env ts-node
/**
 * Setup script for messaging-safety skill
 * Run once after installation
 */

import * as fs from 'fs';
import * as path from 'path';

console.log('🔧 Setting up Messaging Safety skill...\n');

// Check if config exists
const configPath = path.join(__dirname, '../config/rules.yaml');
const userConfigPath = path.join(process.env.HOME || '', '.openclaw/skills/messaging-safety/config/rules.yaml');

if (!fs.existsSync(configPath)) {
  console.error('❌ Config file not found at:', configPath);
  process.exit(1);
}

// Create user config directory if needed
const userConfigDir = path.dirname(userConfigPath);
if (!fs.existsSync(userConfigDir)) {
  fs.mkdirSync(userConfigDir, { recursive: true });
  console.log('📁 Created config directory:', userConfigDir);
}

// Copy default config if user doesn't have one
if (!fs.existsSync(userConfigPath)) {
  fs.copyFileSync(configPath, userConfigPath);
  console.log('📄 Copied default config to:', userConfigPath);
  console.log('✏️  Edit this file to customize your rules\n');
} else {
  console.log('📄 User config already exists:', userConfigPath);
}

console.log('✅ Setup complete!\n');
console.log('Next steps:');
console.log('1. Edit your config:', userConfigPath);
console.log('2. Update destination IDs (your Telegram chat IDs)');
console.log('3. Customize message type rules as needed');
console.log('4. Test with: claw messaging-safety test');
