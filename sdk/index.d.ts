export interface AgentInfo { id: number; owner: string; name: string; metadataURI: string; registeredAt: number; active: boolean; score: number; feedbackCount: number; }
export interface FeedbackInfo { reviewer: string; reviewerAgentId: number; score: number; tag: string; evidenceURI: string; timestamp: number; }
export interface Policy { minFeedback?: number; requireActive?: boolean; }
export interface GateResult { allowed: boolean; reason: "ok" | "unknown-agent" | "inactive" | "insufficient-feedback" | "score-below-threshold"; agent: AgentInfo | null; }
export interface ClientOptions { rpcUrl?: string; address?: string; chainId?: number; explorer?: string; provider?: unknown; }
export declare const DEFAULTS: Required<Omit<ClientOptions, "provider">>;
export declare const ABI: string[];
export declare function createClient(opts?: ClientOptions): {
  getAgent(id: number | bigint): Promise<AgentInfo>;
  getFeedback(id: number | bigint, offset?: number, limit?: number): Promise<FeedbackInfo[]>;
  checkAgent(id: number | bigint, minScore?: number, policy?: Policy): Promise<GateResult>;
  explorerUrl(addr?: string): string;
  contract: unknown; provider: unknown; config: ClientOptions;
};
export declare function checkAgent(id: number | bigint, minScore?: number, policy?: Policy, opts?: ClientOptions): Promise<GateResult>;
