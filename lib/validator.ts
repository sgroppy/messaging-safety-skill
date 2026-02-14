/**
 * Messaging Safety Validator
 * Hierarchical rule engine with wildcard support
 */

import { MessagingRules, MessageContext, ValidationResult, MessageTypeRule } from './types';

export class MessageValidator {
  private rules: MessagingRules;

  constructor(rules: MessagingRules) {
    this.rules = rules;
  }

  /**
   * Detect message type using detection rules and content analysis
   */
  detectMessageType(content: string): string {
    const lowerContent = content.toLowerCase();

    // Check detection rules first
    for (const rule of this.rules.detectionRules) {
      for (const pattern of rule.patterns) {
        if (pattern.test(content)) {
          return rule.classifyAs;
        }
      }
    }

    // Fallback to basic keyword detection
    if (lowerContent.includes('digest') || lowerContent.includes('🦾')) {
      return 'digest.*';
    }
    if (lowerContent.includes('reminder') || lowerContent.includes("don't forget")) {
      return 'reminder.*';
    }
    if (lowerContent.includes('replying to') || lowerContent.includes('in response to')) {
      return 'reply.*';
    }
    if (lowerContent.includes('revenue') || lowerContent.includes('business')) {
      return 'business.*';
    }

    return 'unknown';
  }

  /**
   * Parse message type path (e.g., "digest.reddit")
   */
  parseMessageType(typePath: string): { category: string; subtype: string } {
    const parts = typePath.split('.');
    return {
      category: parts[0],
      subtype: parts[1] || '*'
    };
  }

  /**
   * Find the most specific rule for a message type
   * Priority: specific.subtype > category.* > defaults
   */
  findRule(typePath: string): MessageTypeRule | null {
    const { category, subtype } = this.parseMessageType(typePath);
    const categoryRules = this.rules.messageTypes[category];

    if (!categoryRules) return null;

    // 1. Look for specific subtype rule
    if (subtype !== '*' && categoryRules[subtype]) {
      return categoryRules[subtype];
    }

    // 2. Look for wildcard rule in category
    if (categoryRules['*']) {
      return categoryRules['*'];
    }

    return null;
  }

  /**
   * Check if a destination matches a pattern
   * Supports exact match or wildcard '*'
   */
  matchesDestination(destId: string, pattern: string): boolean {
    if (pattern === '*') return true;
    return destId === pattern;
  }

  /**
   * Check if destination is in a list
   */
  isDestinationInList(destId: string, list: string[]): boolean {
    return list.some(pattern => this.matchesDestination(destId, pattern));
  }

  /**
   * Get destination name for display
   */
  getDestinationName(destId: string): string {
    const dest = this.rules.destinations[destId];
    return dest?.name || destId;
  }

  /**
   * Main validation logic
   */
  validate(context: MessageContext): ValidationResult {
    const { content, destination, isReply } = context;

    // Check for override code
    if (content.includes(this.rules.overrideCode)) {
      return {
        allowed: true,
        action: 'allow',
        reason: 'Override code used'
      };
    }

    // Detect message type
    const detectedType = this.detectMessageType(content);
    const { category, subtype } = this.parseMessageType(detectedType);

    // Get the rule
    const rule = this.findRule(detectedType);

    if (!rule) {
      // No rule found - use defaults
      return {
        allowed: false,
        action: this.rules.defaults.unknownMessageType.action,
        reason: `No rules for message type: ${detectedType}`,
        messageType: detectedType,
        needsConfirmation: true
      };
    }

    // Check if destination is unknown
    if (!this.rules.destinations[destination]) {
      return {
        allowed: false,
        action: this.rules.defaults.unknownDestination.action,
        reason: `Unknown destination: ${destination}`,
        messageType: detectedType,
        needsConfirmation: true
      };
    }

    // Check blocked list
    if (this.isDestinationInList(destination, rule.blockedIn)) {
      return {
        allowed: false,
        action: 'block',
        reason: rule.reason || `${detectedType} is blocked in ${this.getDestinationName(destination)}`,
        messageType: detectedType,
        matchedRule: `${category}.${subtype}`,
        suggestedDestination: rule.allowedIn[0],
        needsConfirmation: true
      };
    }

    // Check confirmation required (skip for replies)
    if (!isReply && this.isDestinationInList(destination, rule.requiresConfirmation)) {
      return {
        allowed: false,
        action: 'ask',
        reason: `${this.getDestinationName(destination)} requires confirmation for ${detectedType}`,
        messageType: detectedType,
        matchedRule: `${category}.${subtype}`,
        needsConfirmation: true
      };
    }

    // Check allowed list
    if (this.isDestinationInList(destination, rule.allowedIn)) {
      return {
        allowed: true,
        action: 'allow',
        messageType: detectedType,
        matchedRule: `${category}.${subtype}`
      };
    }

    // Not explicitly allowed or blocked - ask
    return {
      allowed: false,
      action: 'ask',
      reason: `${detectedType} not explicitly allowed in ${this.getDestinationName(destination)}`,
      messageType: detectedType,
      needsConfirmation: true
    };
  }

  /**
   * Format a confirmation message for the user
   */
  formatConfirmation(context: MessageContext, result: ValidationResult): string {
    const destName = this.getDestinationName(context.destination);
    const preview = context.content.substring(0, 100) + 
      (context.content.length > 100 ? '...' : '');

    let msg = `⚠️ **Send Confirmation Required**\n\n`;
    msg += `**To:** ${destName}\n`;
    msg += `**Type:** ${result.messageType}\n`;
    msg += `**Reason:** ${result.reason}\n\n`;
    msg += `**Message:**\n${preview}\n\n`;

    if (result.suggestedDestination) {
      const suggestedName = this.getDestinationName(result.suggestedDestination);
      msg += `**Suggested:** ${suggestedName}\n\n`;
    }

    msg += `Reply **YES** to send, **NO** to cancel.`;

    return msg;
  }
}
