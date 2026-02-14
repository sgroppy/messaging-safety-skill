/**
 * Messaging Safety Skill - TypeScript Types
 * Hierarchical message type system with wildcard support
 */

export interface Destination {
  id: string;
  type: 'telegram' | 'discord' | 'slack' | 'webchat';
  name: string;
  description?: string;
  priority: number;
}

export interface MessageTypeRule {
  allowedIn: string[];
  blockedIn: string[];
  requiresConfirmation: string[];
  contentPatterns?: RegExp[];
  reason?: string;
}

export interface MessageTypeCategory {
  [subtype: string]: MessageTypeRule;
}

export interface DetectionRule {
  name: string;
  patterns: RegExp[];
  classifyAs: string; // e.g., "digest.reddit" or "business.*"
}

export interface DefaultBehavior {
  action: 'ask' | 'allow' | 'block';
  message?: string;
}

export interface MessagingRules {
  version: string;
  destinations: Record<string, Destination>;
  messageTypes: Record<string, MessageTypeCategory>;
  detectionRules: DetectionRule[];
  defaults: {
    unknownMessageType: DefaultBehavior;
    unknownDestination: DefaultBehavior;
  };
  overrideCode: string;
}

export interface ValidationResult {
  allowed: boolean;
  action: 'allow' | 'block' | 'ask';
  reason?: string;
  messageType?: string;
  matchedRule?: string;
  suggestedDestination?: string;
  needsConfirmation?: boolean;
}

export interface MessageContext {
  content: string;
  destination: string;
  channel: string;
  isReply?: boolean;
  threadId?: string;
  metadata?: Record<string, any>;
}
