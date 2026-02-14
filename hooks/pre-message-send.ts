/**
 * Pre-Message Send Hook
 * Intercepts all outgoing messages and validates against rules
 */

import { MessageContext } from '../lib/types';
import { MessageValidator } from '../lib/validator';
import * as fs from 'fs';
import * as path from 'path';
import * as yaml from 'js-yaml';

// Load rules from config
function loadRules() {
  const configPath = path.join(__dirname, '../config/rules.yaml');
  const content = fs.readFileSync(configPath, 'utf-8');
  return yaml.load(content) as any;
}

const validator = new MessageValidator(loadRules());

/**
 * Pre-send hook handler
 * Called by OpenClaw before every message send
 */
export async function preMessageSend(context: MessageContext): Promise<{ allow: boolean; reason?: string }> {
  try {
    const result = validator.validate(context);

    if (result.action === 'allow') {
      return { allow: true };
    }

    if (result.action === 'block') {
      return { 
        allow: false, 
        reason: result.reason 
      };
    }

    if (result.action === 'ask') {
      // Format confirmation message
      const confirmMsg = validator.formatConfirmation(context, result);
      
      // Send confirmation request to Boss DM
      // (Implementation depends on OpenClaw's message API)
      await sendToBoss(confirmMsg);
      
      return {
        allow: false,
        reason: `Confirmation required: ${result.reason}`
      };
    }

    return { allow: false, reason: 'Unknown validation result' };
  } catch (error) {
    console.error('Messaging safety validation error:', error);
    // Fail safe: block on error
    return { 
      allow: false, 
      reason: 'Validation error - message blocked for safety' 
    };
  }
}

async function sendToBoss(message: string): Promise<void> {
  // Placeholder - integrate with OpenClaw's message API
  // This should send the confirmation request to Boss's DM
  console.log('[Messaging Safety] Confirmation request:', message);
}
